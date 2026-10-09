-- Migration: 20261009000012_fase8b_notifications.sql
-- Description: Fase 8B - Sistema de notificaciones (bandeja, push y respaldo email outbox)

-- 1. Tablas
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    data JSONB DEFAULT '{}'::jsonb,
    dedup_key TEXT NOT NULL,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_user_dedup UNIQUE (user_id, dedup_key)
);

CREATE TABLE IF NOT EXISTS public.push_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    endpoint TEXT NOT NULL UNIQUE,
    p256dh TEXT NOT NULL,
    auth TEXT NOT NULL,
    user_agent TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_success_at TIMESTAMPTZ,
    disabled_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.notification_outbox (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id UUID NOT NULL REFERENCES public.notifications(id) ON DELETE CASCADE,
    channel TEXT NOT NULL CHECK (channel IN ('push', 'email')),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed', 'skipped')),
    attempts INT NOT NULL DEFAULT 0,
    next_attempt_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    error TEXT,
    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índices de rendimiento
CREATE INDEX IF NOT EXISTS idx_notifications_user_created ON public.notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON public.notifications(user_id) WHERE read_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_outbox_pending ON public.notification_outbox(status, next_attempt_at) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_push_sub_user ON public.push_subscriptions(user_id) WHERE disabled_at IS NULL;

-- 2. RLS Policies
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_outbox ENABLE ROW LEVEL SECURITY;

-- Notifications: el usuario lee y actualiza read_at de las suyas
DROP POLICY IF EXISTS notifications_select_policy ON public.notifications;
CREATE POLICY notifications_select_policy ON public.notifications
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS notifications_update_policy ON public.notifications;
CREATE POLICY notifications_update_policy ON public.notifications
    FOR UPDATE TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 3. RPCs de suscripción Push (seguros sobre auth.uid())
CREATE OR REPLACE FUNCTION public.register_push_subscription(
    p_endpoint TEXT,
    p_p256dh TEXT,
    p_auth TEXT,
    p_user_agent TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    IF p_endpoint IS NULL OR trim(p_endpoint) = '' THEN
        RAISE EXCEPTION 'Endpoint is required.';
    END IF;

    INSERT INTO public.push_subscriptions (user_id, endpoint, p256dh, auth, user_agent, disabled_at)
    VALUES (v_user_id, p_endpoint, p_p256dh, p_auth, p_user_agent, NULL)
    ON CONFLICT (endpoint) DO UPDATE
    SET user_id = EXCLUDED.user_id,
        p256dh = EXCLUDED.p256dh,
        auth = EXCLUDED.auth,
        user_agent = EXCLUDED.user_agent,
        disabled_at = NULL;

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

CREATE OR REPLACE FUNCTION public.unregister_push_subscription(
    p_endpoint TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    UPDATE public.push_subscriptions
    SET disabled_at = NOW()
    WHERE user_id = v_user_id AND endpoint = p_endpoint;

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

-- RPCs para marcar notificaciones como leídas
CREATE OR REPLACE FUNCTION public.mark_notification_read(
    p_notification_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    UPDATE public.notifications
    SET read_at = NOW()
    WHERE id = p_notification_id AND user_id = v_user_id AND read_at IS NULL;

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

CREATE OR REPLACE FUNCTION public.mark_all_notifications_read()
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_count INT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    WITH updated AS (
        UPDATE public.notifications
        SET read_at = NOW()
        WHERE user_id = v_user_id AND read_at IS NULL
        RETURNING id
    )
    SELECT COUNT(*) INTO v_count FROM updated;

    RETURN jsonb_build_object('success', true, 'updated_count', v_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;


-- 4. Función Interna create_notification
CREATE OR REPLACE FUNCTION public.create_notification(
    p_user_id UUID,
    p_type TEXT,
    p_title TEXT,
    p_body TEXT,
    p_data JSONB DEFAULT '{}'::jsonb,
    p_dedup_key TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_dedup_key TEXT;
    v_prefs JSONB;
    v_is_transactional BOOLEAN;
    v_pref_enabled BOOLEAN := true;
    v_daily_non_trans_count INT := 0;
    v_cur_hour INT;
    v_next_attempt_at TIMESTAMPTZ := NOW();
    v_target_date DATE;
    v_notif_id UUID;
    v_has_active_push BOOLEAN := false;
BEGIN
    IF p_user_id IS NULL OR p_type IS NULL OR p_title IS NULL OR p_body IS NULL THEN
        RETURN NULL;
    END IF;

    v_dedup_key := COALESCE(p_dedup_key, gen_random_uuid()::text);

    -- Clasificación transaccional vs no transaccional
    v_is_transactional := (p_type IN (
        'redemption_approved',
        'redemption_delivered',
        'redemption_rejected',
        'redemption_cancelled',
        'redemption_issue',
        'redemption_expiring',
        'pearls_released'
    ));

    -- Obtener preferencias del usuario
    SELECT notification_prefs INTO v_prefs FROM public.profiles WHERE id = p_user_id;
    IF v_prefs IS NULL THEN
        v_prefs := '{"redemptions": true, "trivias_matches": true, "news": true, "push": true, "email": true}'::jsonb;
    END IF;

    IF NOT v_is_transactional THEN
        -- Verificar preferencia según categoría
        IF p_type IN ('new_trivia', 'match_day') THEN
            IF COALESCE((v_prefs->>'trivias_matches')::boolean, true) IS FALSE THEN
                RETURN NULL;
            END IF;
        ELSIF p_type IN ('team_news') THEN
            IF COALESCE((v_prefs->>'news')::boolean, true) IS FALSE THEN
                RETURN NULL;
            END IF;
        END IF;

        -- Tope de 1 notificación no transaccional al día (huso America/Caracas)
        SELECT COUNT(*) INTO v_daily_non_trans_count
        FROM public.notifications
        WHERE user_id = p_user_id
          AND type NOT IN ('redemption_approved', 'redemption_delivered', 'redemption_rejected', 'redemption_cancelled', 'redemption_issue', 'redemption_expiring', 'pearls_released')
          AND (created_at AT TIME ZONE 'America/Caracas')::date = (NOW() AT TIME ZONE 'America/Caracas')::date;

        IF v_daily_non_trans_count >= 1 THEN
            RETURN NULL;
        END IF;

        -- Horario de silencio 22:00 a 08:00 (America/Caracas)
        v_cur_hour := EXTRACT(HOUR FROM (NOW() AT TIME ZONE 'America/Caracas'));
        IF v_cur_hour >= 22 OR v_cur_hour < 8 THEN
            IF v_cur_hour >= 22 THEN
                v_target_date := (NOW() AT TIME ZONE 'America/Caracas')::date + INTERVAL '1 day';
            ELSE
                v_target_date := (NOW() AT TIME ZONE 'America/Caracas')::date;
            END IF;
            v_next_attempt_at := (v_target_date || ' 08:00:00')::timestamp AT TIME ZONE 'America/Caracas';
        END IF;
    END IF;

    -- Inserción idempotente en notifications
    INSERT INTO public.notifications (user_id, type, title, body, data, dedup_key)
    VALUES (p_user_id, p_type, p_title, p_body, COALESCE(p_data, '{}'::jsonb), v_dedup_key)
    ON CONFLICT (user_id, dedup_key) DO NOTHING
    RETURNING id INTO v_notif_id;

    IF v_notif_id IS NULL THEN
        RETURN NULL; -- Ya existía por dedup_key
    END IF;

    -- Encolar en notification_outbox si las preferencias del canal lo permiten
    IF COALESCE((v_prefs->>'push')::boolean, true) IS NOT FALSE THEN
        SELECT EXISTS (
            SELECT 1 FROM public.push_subscriptions
            WHERE user_id = p_user_id AND disabled_at IS NULL
        ) INTO v_has_active_push;

        IF v_has_active_push THEN
            INSERT INTO public.notification_outbox (notification_id, channel, status, next_attempt_at)
            VALUES (v_notif_id, 'push', 'pending', v_next_attempt_at);
        END IF;
    END IF;

    IF COALESCE((v_prefs->>'email')::boolean, true) IS NOT FALSE THEN
        INSERT INTO public.notification_outbox (notification_id, channel, status, next_attempt_at)
        VALUES (v_notif_id, 'email', 'pending', v_next_attempt_at);
    END IF;

    RETURN v_notif_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;


-- 5. RPC de Liberación de Perlitas Retenidas
CREATE OR REPLACE FUNCTION public.release_held_pearls(
    p_ledger_entry_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_entry public.ledger_entries%ROWTYPE;
BEGIN
    IF NOT is_admin(v_admin_id) THEN
        RAISE EXCEPTION 'Admin authorization required.';
    END IF;

    SELECT * INTO v_entry
    FROM public.ledger_entries
    WHERE id = p_ledger_entry_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Ledger entry not found.';
    END IF;

    IF v_entry.status != 'held' THEN
        RAISE EXCEPTION 'Only held ledger entries can be released. Current status: %', v_entry.status;
    END IF;

    UPDATE public.ledger_entries
    SET status = 'confirmed'
    WHERE id = v_entry.id;

    UPDATE public.wallets
    SET balance_cache = balance_cache + v_entry.amount,
        updated_at = NOW()
    WHERE fan_id = v_entry.fan_id;

    PERFORM public.create_notification(
        v_entry.fan_id,
        'pearls_released',
        '¡Perlitas liberadas!',
        'Se han liberado ' || v_entry.amount || ' perlitas en tu billetera.',
        jsonb_build_object('ledger_id', v_entry.id, 'url', '/app/billetera'),
        'pearls_released_' || v_entry.id
    );

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        v_admin_id, 'release_held_pearls', 'ledger_entries', v_entry.id::text,
        jsonb_build_object('status', 'held', 'amount', v_entry.amount),
        jsonb_build_object('status', 'confirmed', 'amount', v_entry.amount)
    );

    RETURN jsonb_build_object(
        'ledger_id', v_entry.id,
        'status', 'confirmed',
        'released_amount', v_entry.amount
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;


-- 6. Actualización de Funciones de Canje para gatillar Notificaciones

-- approve_redemption
CREATE OR REPLACE FUNCTION public.approve_redemption(
    p_redemption_id UUID,
    p_note TEXT DEFAULT 'Canje aprobado por staff'
)
RETURNS JSONB AS $$
DECLARE
    v_staff_id UUID := auth.uid();
    v_redemption redemptions%ROWTYPE;
BEGIN
    IF NOT is_staff_or_admin(v_staff_id) THEN
        RAISE EXCEPTION 'Staff or Admin authorization required.';
    END IF;

    SELECT * INTO v_redemption FROM redemptions WHERE id = p_redemption_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Redemption not found.';
    END IF;

    IF v_redemption.status != 'pending' THEN
        RAISE EXCEPTION 'Solo los canjes pendientes pueden ser aprobados. Estado actual: %', v_redemption.status;
    END IF;

    UPDATE redemptions
    SET status = 'approved',
        approved_by = v_staff_id,
        approved_at = NOW()
    WHERE id = v_redemption.id;

    INSERT INTO redemption_history (redemption_id, previous_status, new_status, changed_by, note)
    VALUES (v_redemption.id, 'pending', 'approved', v_staff_id, COALESCE(p_note, 'Aprobado por staff'));

    PERFORM public.create_notification(
        v_redemption.fan_id,
        'redemption_approved',
        '¡Tu canje fue aprobado!',
        'Tu código QR ya está disponible en tus canjes para la entrega.',
        jsonb_build_object('redemption_id', v_redemption.id, 'url', '/app/canjes/' || v_redemption.id),
        'redemption_approved_' || v_redemption.id
    );

    RETURN jsonb_build_object(
        'redemption_id', v_redemption.id,
        'status', 'approved'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

-- deliver_redemption
CREATE OR REPLACE FUNCTION public.deliver_redemption(
    p_redemption_id UUID,
    p_idempotency_key TEXT,
    p_note TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_staff_id UUID := auth.uid();
    v_redemption public.redemptions%ROWTYPE;
    v_deliv_name TEXT;
BEGIN
    PERFORM assert_staff();

    IF p_idempotency_key IS NULL OR trim(p_idempotency_key) = '' THEN
        RAISE EXCEPTION 'Idempotency key is required for delivery.';
    END IF;

    SELECT * INTO v_redemption
    FROM public.redemptions
    WHERE id = p_redemption_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Canje no encontrado.';
    END IF;

    IF v_redemption.status IN ('delivered', 'completed') OR v_redemption.delivery_idempotency_key = p_idempotency_key THEN
        SELECT display_name INTO v_deliv_name FROM public.profiles WHERE id = v_redemption.delivered_by;
        RETURN jsonb_build_object(
            'result', 'ALREADY_DELIVERED',
            'status', v_redemption.status,
            'delivered_at', v_redemption.delivered_at,
            'delivered_by_name', COALESCE(v_deliv_name, 'Personal de Staff')
        );
    END IF;

    IF v_redemption.status != 'approved' THEN
        RAISE EXCEPTION 'Solo se pueden entregar canjes en estado "approved". Estado actual: %', v_redemption.status;
    END IF;

    UPDATE public.redemptions
    SET status = 'delivered',
        delivered_by = v_staff_id,
        delivered_at = NOW(),
        delivery_idempotency_key = p_idempotency_key
    WHERE id = v_redemption.id AND status = 'approved';

    INSERT INTO public.redemption_history (redemption_id, previous_status, new_status, changed_by, note)
    VALUES (v_redemption.id, v_redemption.status, 'delivered', v_staff_id, COALESCE(p_note, 'Premio entregado al fanático'));

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        v_staff_id,
        'deliver_redemption',
        'redemptions',
        v_redemption.id::text,
        jsonb_build_object('status', v_redemption.status),
        jsonb_build_object('status', 'delivered', 'idempotency_key', p_idempotency_key, 'note', p_note)
    );

    PERFORM public.create_notification(
        v_redemption.fan_id,
        'redemption_delivered',
        '¡Premio entregado!',
        'Has recibido tu producto/premio con éxito.',
        jsonb_build_object('redemption_id', v_redemption.id, 'url', '/app/canjes/' || v_redemption.id),
        'redemption_delivered_' || v_redemption.id
    );

    SELECT display_name INTO v_deliv_name FROM public.profiles WHERE id = v_staff_id;

    RETURN jsonb_build_object(
        'result', 'SUCCESS',
        'status', 'delivered',
        'delivered_at', NOW(),
        'delivered_by_name', v_deliv_name
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

-- reject_redemption
CREATE OR REPLACE FUNCTION public.reject_redemption(
    p_redemption_id UUID,
    p_reason TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_staff_id UUID := auth.uid();
    v_redemption public.redemptions%ROWTYPE;
    v_refunded BOOLEAN;
BEGIN
    PERFORM assert_staff();

    IF p_reason IS NULL OR trim(p_reason) = '' THEN
        RAISE EXCEPTION 'Motivo de rechazo es obligatorio.';
    END IF;

    SELECT * INTO v_redemption
    FROM public.redemptions
    WHERE id = p_redemption_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Canje no encontrado.';
    END IF;

    IF v_redemption.status = 'rejected' THEN
        RAISE EXCEPTION 'El canje ya ha sido rechazado previamente.';
    END IF;

    IF v_redemption.status IN ('delivered', 'completed', 'cancelled') THEN
        RAISE EXCEPTION 'No se puede rechazar un canje en estado "%".', v_redemption.status;
    END IF;

    UPDATE public.redemptions
    SET status = 'rejected'
    WHERE id = v_redemption.id;

    SELECT EXISTS (
        SELECT 1 FROM public.ledger_entries 
        WHERE source_id = v_redemption.id::text 
          AND source_type = 'redemption_refund'
    ) INTO v_refunded;

    IF NOT v_refunded THEN
        INSERT INTO public.ledger_entries (fan_id, amount, type, status, source_type, source_id, note, created_by)
        VALUES (
            v_redemption.fan_id,
            v_redemption.cost_pearls,
            'refund',
            'confirmed',
            'redemption_refund',
            v_redemption.id::text,
            'Reembolso por rechazo de canje: ' || p_reason,
            v_staff_id
        );

        UPDATE public.wallets
        SET balance_cache = balance_cache + v_redemption.cost_pearls,
            updated_at = NOW()
        WHERE fan_id = v_redemption.fan_id;
    END IF;

    INSERT INTO public.redemption_history (redemption_id, previous_status, new_status, changed_by, note)
    VALUES (v_redemption.id, v_redemption.status, 'rejected', v_staff_id, p_reason);

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        v_staff_id, 'reject_redemption', 'redemptions', v_redemption.id::text,
        jsonb_build_object('status', v_redemption.status),
        jsonb_build_object('status', 'rejected', 'reason', p_reason, 'refunded_pearls', v_redemption.cost_pearls)
    );

    PERFORM public.create_notification(
        v_redemption.fan_id,
        'redemption_rejected',
        'Canje rechazado',
        'Tu canje ha sido rechazado: ' || p_reason || '. Las perlitas han sido reembolsadas a tu billetera.',
        jsonb_build_object('redemption_id', v_redemption.id, 'url', '/app/canjes/' || v_redemption.id),
        'redemption_rejected_' || v_redemption.id
    );

    RETURN jsonb_build_object(
        'redemption_id', v_redemption.id,
        'status', 'rejected',
        'refunded_pearls', v_redemption.cost_pearls
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

-- cancel_redemption
CREATE OR REPLACE FUNCTION public.cancel_redemption(
    p_redemption_id UUID,
    p_reason TEXT DEFAULT 'Cancelado por el usuario'
)
RETURNS JSONB AS $$
DECLARE
    v_actor_id UUID := auth.uid();
    v_redemption redemptions%ROWTYPE;
    v_is_owner BOOLEAN;
BEGIN
    IF v_actor_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT * INTO v_redemption FROM redemptions WHERE id = p_redemption_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Redemption not found.';
    END IF;

    v_is_owner := (v_redemption.fan_id = v_actor_id);

    IF v_is_owner THEN
        IF v_redemption.status != 'pending' THEN
            RAISE EXCEPTION 'Solo puedes cancelar canjes en estado pendiente. Estado actual: %', v_redemption.status;
        END IF;
    ELSE
        IF NOT is_staff_or_admin(v_actor_id) THEN
            RAISE EXCEPTION 'No tienes permisos para cancelar este canje.';
        END IF;
        IF v_redemption.status IN ('delivered', 'completed', 'cancelled', 'rejected') THEN
            RAISE EXCEPTION 'No se puede cancelar un canje en estado %', v_redemption.status;
        END IF;
    END IF;

    UPDATE redemptions SET status = 'cancelled' WHERE id = v_redemption.id;

    INSERT INTO ledger_entries (
        fan_id, amount, type, status, source_type, source_id, note, created_by
    ) VALUES (
        v_redemption.fan_id, v_redemption.cost_pearls, 'refund', 'confirmed',
        'redemption', v_redemption.id::text,
        'Reembolso por cancelación de canje: ' || COALESCE(p_reason, 'Sin motivo'),
        v_actor_id
    );

    UPDATE wallets
    SET balance_cache = balance_cache + v_redemption.cost_pearls, updated_at = NOW()
    WHERE fan_id = v_redemption.fan_id;

    UPDATE products SET stock = stock + 1 WHERE id = v_redemption.product_id;

    INSERT INTO redemption_history (redemption_id, previous_status, new_status, changed_by, note)
    VALUES (v_redemption.id, v_redemption.status, 'cancelled', v_actor_id, COALESCE(p_reason, 'Cancelado'));

    INSERT INTO audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        v_actor_id, 'cancel_redemption', 'redemptions', v_redemption.id::text,
        jsonb_build_object('status', v_redemption.status, 'cost_pearls', v_redemption.cost_pearls),
        jsonb_build_object('status', 'cancelled', 'reason', p_reason, 'refunded_pearls', v_redemption.cost_pearls)
    );

    PERFORM public.create_notification(
        v_redemption.fan_id,
        'redemption_cancelled',
        'Canje cancelado',
        'Se ha cancelado tu canje y tus perlitas han sido reembolsadas.',
        jsonb_build_object('redemption_id', v_redemption.id, 'url', '/app/canjes/' || v_redemption.id),
        'redemption_cancelled_' || v_redemption.id
    );

    RETURN jsonb_build_object(
        'redemption_id', v_redemption.id,
        'status', 'cancelled',
        'refunded_pearls', v_redemption.cost_pearls
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

-- report_redemption_issue
CREATE OR REPLACE FUNCTION public.report_redemption_issue(
    p_redemption_id UUID,
    p_reason TEXT,
    p_note TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_staff_id UUID := auth.uid();
    v_redemption public.redemptions%ROWTYPE;
BEGIN
    PERFORM assert_staff();

    IF p_reason NOT IN ('wrong_size', 'damaged', 'identity_mismatch', 'out_of_stock_physical', 'other') THEN
        RAISE EXCEPTION 'Motivo de incidencia no válido. Debe ser: wrong_size, damaged, identity_mismatch, out_of_stock_physical o other.';
    END IF;

    SELECT * INTO v_redemption
    FROM public.redemptions
    WHERE id = p_redemption_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Canje no encontrado.';
    END IF;

    UPDATE public.redemptions
    SET status = 'issue'
    WHERE id = v_redemption.id;

    INSERT INTO public.redemption_history (redemption_id, previous_status, new_status, changed_by, note)
    VALUES (v_redemption.id, v_redemption.status, 'issue', v_staff_id, COALESCE(p_note, 'Incidencia reportada: ' || p_reason));

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        v_staff_id, 'report_redemption_issue', 'redemptions', v_redemption.id::text,
        jsonb_build_object('status', v_redemption.status),
        jsonb_build_object('status', 'issue', 'reason', p_reason, 'note', p_note)
    );

    PERFORM public.create_notification(
        v_redemption.fan_id,
        'redemption_issue',
        'Incidencia en tu canje',
        'Se ha registrado un reporte sobre tu canje.',
        jsonb_build_object('redemption_id', v_redemption.id, 'url', '/app/canjes/' || v_redemption.id),
        'redemption_issue_' || v_redemption.id
    );

    RETURN jsonb_build_object(
        'redemption_id', v_redemption.id,
        'status', 'issue',
        'reason', p_reason
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;


-- 7. Cron Functions & Jobs
CREATE OR REPLACE FUNCTION public.cron_notify_expiring_redemptions()
RETURNS VOID AS $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT id, fan_id, expires_at
        FROM public.redemptions
        WHERE status IN ('pending', 'approved')
          AND expires_at IS NOT NULL
          AND expires_at > NOW()
          AND expires_at <= (NOW() + INTERVAL '24 hours')
    LOOP
        PERFORM public.create_notification(
            r.fan_id,
            'redemption_expiring',
            '¡Tu canje vence pronto!',
            'Tienes un canje pendiente por retirar que vence en menos de 24 horas.',
            jsonb_build_object('redemption_id', r.id, 'url', '/app/canjes/' || r.id),
            'redemption_expiring_' || r.id || '_' || (r.expires_at::date)::text
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

CREATE OR REPLACE FUNCTION public.cron_notify_new_trivias()
RETURNS VOID AS $$
DECLARE
    t RECORD;
    f RECORD;
BEGIN
    FOR t IN
        SELECT id, title
        FROM public.trivias
        WHERE status = 'published'
          AND created_at >= (NOW() - INTERVAL '1 hour')
    LOOP
        FOR f IN SELECT id FROM public.profiles WHERE status = 'active' LOOP
            PERFORM public.create_notification(
                f.id,
                'new_trivia',
                '¡Nueva Trivia Disponible!',
                'Demuestra cuánto sabes sobre los Guaiqueríes: ' || t.title,
                jsonb_build_object('trivia_id', t.id, 'url', '/app/trivias/' || t.id),
                'new_trivia_' || t.id || '_' || f.id
            );
        END LOOP;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

CREATE OR REPLACE FUNCTION public.cron_notify_match_day()
RETURNS VOID AS $$
DECLARE
    m RECORD;
    f RECORD;
BEGIN
    FOR m IN
        SELECT id, opponent_name, date_time
        FROM public.games
        WHERE status = 'scheduled'
          AND date_time >= (NOW() + INTERVAL '2 hours 30 minutes')
          AND date_time <= (NOW() + INTERVAL '3 hours 30 minutes')
    LOOP
        FOR f IN SELECT id FROM public.profiles WHERE status = 'active' LOOP
            PERFORM public.create_notification(
                f.id,
                'match_day',
                '¡Hoy Juegan los Guaiqueríes!',
                'El partido contra ' || m.opponent_name || ' comienza en 3 horas.',
                jsonb_build_object('game_id', m.id, 'url', '/app'),
                'match_day_' || m.id || '_' || f.id
            );
        END LOOP;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

CREATE OR REPLACE FUNCTION public.cron_cleanup_old_notifications()
RETURNS VOID AS $$
BEGIN
    DELETE FROM public.notifications
    WHERE read_at IS NOT NULL
      AND read_at < (NOW() - INTERVAL '90 days');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;


-- 8. Permisos y Revocaciones Estrictas
REVOKE ALL ON FUNCTION public.create_notification(UUID, TEXT, TEXT, TEXT, JSONB, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_notification(UUID, TEXT, TEXT, TEXT, JSONB, TEXT) TO service_role, postgres;

REVOKE ALL ON FUNCTION public.register_push_subscription(TEXT, TEXT, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.register_push_subscription(TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.unregister_push_subscription(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.unregister_push_subscription(TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.mark_notification_read(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_notification_read(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.mark_all_notifications_read() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_all_notifications_read() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.release_held_pearls(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.release_held_pearls(UUID) FROM authenticated, service_role;

REVOKE ALL ON FUNCTION public.cron_notify_expiring_redemptions() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cron_notify_expiring_redemptions() TO service_role, postgres;

REVOKE ALL ON FUNCTION public.cron_notify_new_trivias() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cron_notify_new_trivias() TO service_role, postgres;

REVOKE ALL ON FUNCTION public.cron_notify_match_day() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cron_notify_match_day() TO service_role, postgres;

REVOKE ALL ON FUNCTION public.cron_cleanup_old_notifications() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cron_cleanup_old_notifications() TO service_role, postgres;
