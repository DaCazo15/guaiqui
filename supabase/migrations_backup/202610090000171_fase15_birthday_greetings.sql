-- Migration: 20261009000017_fase15_birthday_greetings.sql
-- Description: Fase 15 - Saludo de cumpleaños (notificación, configuración, RPCs, pg_cron y libro contable)

-- 1. Añadir 'birthday_bonus' al tipo de libro contable ledger_type
ALTER TYPE ledger_type ADD VALUE IF NOT EXISTS 'birthday_bonus';

-- 2. Tabla de Configuración de Cumpleaños (Singleton, fila única)
CREATE TABLE IF NOT EXISTS public.birthday_settings (
    id INT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    enabled BOOLEAN NOT NULL DEFAULT true,
    title TEXT NOT NULL DEFAULT '¡Feliz Cumpleaños, Guaiquerí!',
    message TEXT NOT NULL DEFAULT '¡En nombre de todos los que formamos parte de los **Guaiqueríes de Margarita**, te deseamos un feliz cumpleaños, {nombre}! 🏀\n\nGracias por tu pasión y por ser parte fundamental de nuestra tribu.',
    image_url TEXT,
    send_hour INT NOT NULL DEFAULT 9 CHECK (send_hour >= 0 AND send_hour <= 23),
    grace_days INT NOT NULL DEFAULT 3 CHECK (grace_days >= 0),
    bonus_pearls INT NOT NULL DEFAULT 0 CHECK (bonus_pearls >= 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Insertar configuración inicial por defecto
INSERT INTO public.birthday_settings (id, enabled, title, message, send_hour, grace_days, bonus_pearls)
VALUES (
    1,
    true,
    '¡Feliz Cumpleaños, Guaiquerí!',
    '¡En nombre de todos los que formamos parte de los **Guaiqueríes de Margarita**, te deseamos un feliz cumpleaños, {nombre}! 🏀\n\nGracias por tu pasión y por ser parte fundamental de nuestra tribu.',
    9,
    3,
    0
)
ON CONFLICT (id) DO NOTHING;

-- RLS para birthday_settings
ALTER TABLE public.birthday_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "BirthdaySettings Public Read" ON public.birthday_settings;
CREATE POLICY "BirthdaySettings Public Read" ON public.birthday_settings
    FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS "BirthdaySettings Admin Write" ON public.birthday_settings;
CREATE POLICY "BirthdaySettings Admin Write" ON public.birthday_settings
    FOR ALL TO authenticated USING (public.is_admin_check());

-- 3. Actualizar create_notification para soportar tipo 'birthday'
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
        v_prefs := '{"redemptions": true, "trivias_matches": true, "news": true, "birthday": true, "push": true, "email": true}'::jsonb;
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
        ELSIF p_type = 'birthday' THEN
            IF COALESCE((v_prefs->>'birthday')::boolean, true) IS FALSE THEN
                RETURN NULL;
            END IF;
        END IF;

        -- Notificaciones de cumpleaños omiten el límite diario de 1 y el horario de silencio habitual (usan su propio send_hour)
        IF p_type != 'birthday' THEN
            -- Tope de 1 notificación no transaccional al día (huso America/Caracas)
            SELECT COUNT(*) INTO v_daily_non_trans_count
            FROM public.notifications
            WHERE user_id = p_user_id
              AND type NOT IN ('redemption_approved', 'redemption_delivered', 'redemption_rejected', 'redemption_cancelled', 'redemption_issue', 'redemption_expiring', 'pearls_released', 'birthday')
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

-- 4. Función Interna enqueue_birthday_notifications
CREATE OR REPLACE FUNCTION public.enqueue_birthday_notifications(
    p_now TIMESTAMPTZ DEFAULT NOW()
)
RETURNS INT AS $$
DECLARE
    v_settings public.birthday_settings%ROWTYPE;
    v_today_caracas DATE;
    v_year INT;
    v_month INT;
    v_day INT;
    v_is_leap_year BOOLEAN;
    v_count INT := 0;
    r RECORD;
BEGIN
    SELECT * INTO v_settings FROM public.birthday_settings WHERE id = 1;
    IF NOT FOUND OR NOT v_settings.enabled THEN
        RETURN 0;
    END IF;

    v_today_caracas := (p_now AT TIME ZONE 'America/Caracas')::date;
    v_year := EXTRACT(YEAR FROM v_today_caracas)::int;
    v_month := EXTRACT(MONTH FROM v_today_caracas)::int;
    v_day := EXTRACT(DAY FROM v_today_caracas)::int;

    v_is_leap_year := (v_year % 4 = 0 AND (v_year % 100 != 0 OR v_year % 400 = 0));

    FOR r IN
        SELECT p.id, p.display_name
        FROM public.profiles p
        JOIN auth.users u ON u.id = p.id
        WHERE p.status = 'active'
          AND p.deleted_at IS NULL
          AND p.birth_date IS NOT NULL
          AND u.email_confirmed_at IS NOT NULL
          AND (
              -- Coincidencia directa de mes y día
              (EXTRACT(MONTH FROM p.birth_date) = v_month AND EXTRACT(DAY FROM p.birth_date) = v_day)
              OR
              -- Si hoy es 28 de febrero en año NO bisiesto, incluir a los nacidos un 29 de febrero
              (v_month = 2 AND v_day = 28 AND NOT v_is_leap_year AND EXTRACT(MONTH FROM p.birth_date) = 2 AND EXTRACT(DAY FROM p.birth_date) = 29)
          )
    LOOP
        PERFORM public.create_notification(
            r.id,
            'birthday',
            v_settings.title,
            '¡De parte de tus Guaiqueríes de Margarita, te deseamos un feliz cumpleaños, ' || r.display_name || '!',
            jsonb_build_object('url', '/app/cumpleanos'),
            'birthday:' || r.id::text || ':' || v_year::text
        );
        v_count := v_count + 1;
    END LOOP;

    RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.enqueue_birthday_notifications(TIMESTAMPTZ) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.enqueue_birthday_notifications(TIMESTAMPTZ) TO service_role, postgres;

-- 5. RPC Public get_birthday_card()
CREATE OR REPLACE FUNCTION public.get_birthday_card()
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_profile public.profiles%ROWTYPE;
    v_settings public.birthday_settings%ROWTYPE;
    v_today_caracas DATE;
    v_year INT;
    v_is_leap_year BOOLEAN;
    v_bdate_month INT;
    v_bdate_day INT;
    v_birthday_this_year DATE;
    v_end_grace_date DATE;
    v_is_eligible BOOLEAN := false;
    v_has_claimed BOOLEAN := false;
    v_formatted_msg TEXT;
BEGIN
    PERFORM public.assert_active_verified_fan();

    SELECT * INTO v_profile FROM public.profiles WHERE id = v_user_id;
    IF NOT FOUND OR v_profile.birth_date IS NULL OR v_profile.deleted_at IS NOT NULL OR v_profile.status != 'active' THEN
        RETURN jsonb_build_object('eligible', false);
    END IF;

    SELECT * INTO v_settings FROM public.birthday_settings WHERE id = 1;
    IF NOT FOUND OR NOT v_settings.enabled THEN
        RETURN jsonb_build_object('eligible', false);
    END IF;

    v_today_caracas := (NOW() AT TIME ZONE 'America/Caracas')::date;
    v_year := EXTRACT(YEAR FROM v_today_caracas)::int;
    v_is_leap_year := (v_year % 4 = 0 AND (v_year % 100 != 0 OR v_year % 400 = 0));

    v_bdate_month := EXTRACT(MONTH FROM v_profile.birth_date)::int;
    v_bdate_day := EXTRACT(DAY FROM v_profile.birth_date)::int;

    IF v_bdate_month = 2 AND v_bdate_day = 29 AND NOT v_is_leap_year THEN
        v_birthday_this_year := (v_year::text || '-02-28')::date;
    ELSE
        v_birthday_this_year := (v_year::text || '-' || to_char(v_profile.birth_date, 'MM-DD'))::date;
    END IF;

    v_end_grace_date := v_birthday_this_year + (v_settings.grace_days || ' days')::interval;

    IF v_today_caracas >= v_birthday_this_year AND v_today_caracas <= v_end_grace_date THEN
        v_is_eligible := true;
    END IF;

    IF NOT v_is_eligible THEN
        RETURN jsonb_build_object('eligible', false);
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.ledger_entries
        WHERE fan_id = v_user_id
          AND type = 'birthday_bonus'
          AND EXTRACT(YEAR FROM (created_at AT TIME ZONE 'America/Caracas')) = v_year
    ) INTO v_has_claimed;

    v_formatted_msg := REPLACE(v_settings.message, '{nombre}', v_profile.display_name);

    RETURN jsonb_build_object(
        'eligible', true,
        'display_name', v_profile.display_name,
        'title', v_settings.title,
        'message', v_formatted_msg,
        'image_url', v_settings.image_url,
        'bonus_pearls', v_settings.bonus_pearls,
        'has_claimed_bonus', v_has_claimed
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.get_birthday_card() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_birthday_card() TO authenticated, service_role;

-- 6. RPC claim_birthday_bonus()
CREATE OR REPLACE FUNCTION public.claim_birthday_bonus()
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_card JSONB;
    v_bonus_amount INT;
    v_created_at TIMESTAMPTZ;
    v_year INT;
    v_status ledger_status := 'confirmed';
    v_entry_id UUID;
BEGIN
    PERFORM public.assert_active_verified_fan();

    v_card := public.get_birthday_card();

    IF NOT (v_card->>'eligible')::boolean THEN
        RAISE EXCEPTION 'No eres elegible para reclamar el bono de cumpleaños en este momento.';
    END IF;

    v_bonus_amount := (v_card->>'bonus_pearls')::int;
    IF v_bonus_amount <= 0 THEN
        RAISE EXCEPTION 'No hay bono de perlitas configurado para el cumpleaños.';
    END IF;

    IF (v_card->>'has_claimed_bonus')::boolean THEN
        RAISE EXCEPTION 'Ya has reclamado tu bono de cumpleaños de este año.';
    END IF;

    SELECT created_at INTO v_created_at FROM public.profiles WHERE id = v_user_id;
    IF v_created_at > (NOW() - INTERVAL '30 days') THEN
        RAISE EXCEPTION 'Tu cuenta debe tener al menos 30 días de antigüedad para reclamar el bono de cumpleaños.';
    END IF;

    v_year := EXTRACT(YEAR FROM (NOW() AT TIME ZONE 'America/Caracas'))::int;

    -- Verificar retención por nivel de riesgo si corresponde
    IF EXISTS (
        SELECT 1 FROM public.risk_assessments
        WHERE fan_id = v_user_id AND severity IN ('medium', 'high') AND resolved_at IS NULL
    ) THEN
        v_status := 'held';
    END IF;

    INSERT INTO public.ledger_entries (
        fan_id, amount, type, status, source_type, source_id, note, created_by
    ) VALUES (
        v_user_id, v_bonus_amount, 'birthday_bonus', v_status,
        'birthday_bonus', 'birthday_bonus_' || v_user_id::text || '_' || v_year::text,
        'Bono de regalo por cumpleaños', v_user_id
    ) RETURNING id INTO v_entry_id;

    IF v_status = 'confirmed' THEN
        UPDATE public.wallets
        SET balance_cache = balance_cache + v_bonus_amount,
            updated_at = NOW()
        WHERE fan_id = v_user_id;
    END IF;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_user_id, 'claim_birthday_bonus', 'ledger_entries', v_entry_id::text,
        jsonb_build_object('amount', v_bonus_amount, 'status', v_status, 'year', v_year)
    );

    RETURN jsonb_build_object(
        'success', true,
        'claimed_pearls', v_bonus_amount,
        'status', v_status
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.claim_birthday_bonus() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_birthday_bonus() TO authenticated, service_role;

-- 7. RPC send_test_birthday_notification() (solo Admin)
CREATE OR REPLACE FUNCTION public.send_test_birthday_notification()
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_settings public.birthday_settings%ROWTYPE;
    v_notif_id UUID;
BEGIN
    PERFORM public.assert_admin();

    SELECT * INTO v_settings FROM public.birthday_settings WHERE id = 1;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Configuración de cumpleaños no encontrada.';
    END IF;

    v_notif_id := public.create_notification(
        v_admin_id,
        'birthday',
        '[PRUEBA] ' || v_settings.title,
        '¡Esta es una notificación de prueba del saludo de cumpleaños para tu usuario admin!',
        jsonb_build_object('url', '/app/cumpleanos'),
        'test_birthday_' || v_admin_id::text || '_' || EXTRACT(EPOCH FROM NOW())::text
    );

    RETURN jsonb_build_object(
        'success', true,
        'notification_id', v_notif_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.send_test_birthday_notification() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.send_test_birthday_notification() TO authenticated, service_role;

-- 8. RPC update_birthday_settings() (solo Admin)
CREATE OR REPLACE FUNCTION public.update_birthday_settings(
    p_enabled BOOLEAN,
    p_title TEXT,
    p_message TEXT,
    p_image_url TEXT,
    p_send_hour INT,
    p_grace_days INT,
    p_bonus_pearls INT
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID := auth.uid();
BEGIN
    PERFORM public.assert_admin();

    IF p_title IS NULL OR trim(p_title) = '' THEN
        RAISE EXCEPTION 'El título es obligatorio.';
    END IF;

    IF p_message IS NULL OR trim(p_message) = '' THEN
        RAISE EXCEPTION 'El mensaje es obligatorio.';
    END IF;

    IF p_send_hour < 0 OR p_send_hour > 23 THEN
        RAISE EXCEPTION 'La hora de envío debe estar entre 0 y 23.';
    END IF;

    IF p_grace_days < 0 THEN
        RAISE EXCEPTION 'Los días de gracia deben ser mayores o iguales a 0.';
    END IF;

    IF p_bonus_pearls < 0 THEN
        RAISE EXCEPTION 'El bono de perlitas debe ser mayor o igual a 0.';
    END IF;

    UPDATE public.birthday_settings
    SET enabled = COALESCE(p_enabled, true),
        title = p_title,
        message = p_message,
        image_url = p_image_url,
        send_hour = p_send_hour,
        grace_days = p_grace_days,
        bonus_pearls = p_bonus_pearls,
        updated_at = NOW()
    WHERE id = 1;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'update_birthday_settings', 'birthday_settings', '1',
        jsonb_build_object(
            'enabled', p_enabled, 'title', p_title, 'send_hour', p_send_hour,
            'grace_days', p_grace_days, 'bonus_pearls', p_bonus_pearls
        )
    );

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.update_birthday_settings(BOOLEAN, TEXT, TEXT, TEXT, INT, INT, INT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_birthday_settings(BOOLEAN, TEXT, TEXT, TEXT, INT, INT, INT) TO authenticated, service_role;
