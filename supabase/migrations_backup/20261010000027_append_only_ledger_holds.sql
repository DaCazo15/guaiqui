-- Migration: 20261010000027_append_only_ledger_holds.sql
-- Description: Implements append-only resolution table public.ledger_hold_resolutions, updates admin_release_held_pearls and admin_revoke_held_pearls, drops duplicate release_held_pearls, and updates views/functions for pending held entries.

-- 1. Create ledger_hold_resolutions table
CREATE TABLE IF NOT EXISTS public.ledger_hold_resolutions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ledger_id UUID UNIQUE NOT NULL REFERENCES public.ledger_entries(id) ON DELETE RESTRICT,
    action TEXT NOT NULL CHECK (action IN ('release', 'revoke')),
    note TEXT NOT NULL,
    resolved_by UUID NOT NULL REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.ledger_hold_resolutions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ledger_hold_resolutions FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.ledger_hold_resolutions TO service_role, postgres;


-- 2. Drop duplicate release_held_pearls function
DROP FUNCTION IF EXISTS public.release_held_pearls(UUID);


-- 3. Append-Only RPC: admin_release_held_pearls
CREATE OR REPLACE FUNCTION public.admin_release_held_pearls(
    p_ledger_id UUID,
    p_note TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_entry public.ledger_entries%ROWTYPE;
    v_release_entry_id UUID := gen_random_uuid();
BEGIN
    PERFORM public.assert_admin();

    IF p_note IS NULL OR trim(p_note) = '' THEN
        RAISE EXCEPTION 'La justificación es obligatoria para liberar perlitas retenidas.';
    END IF;

    SELECT * INTO v_entry FROM public.ledger_entries WHERE id = p_ledger_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Registro de libro no encontrado.';
    END IF;

    IF v_entry.status != 'held' THEN
        RAISE EXCEPTION 'El registro no se encuentra en estado retenido (held).';
    END IF;

    IF EXISTS (SELECT 1 FROM public.ledger_hold_resolutions WHERE ledger_id = p_ledger_id) THEN
        RAISE EXCEPTION 'El registro retenido ya ha sido resuelto previamente (liberado o revocado).';
    END IF;

    -- A) Insert Resolution Record
    INSERT INTO public.ledger_hold_resolutions (
        ledger_id, action, note, resolved_by
    ) VALUES (
        p_ledger_id, 'release', p_note, v_admin_id
    );

    -- B) Append-Only: Insert NEW Confirmed Entry in Ledger
    INSERT INTO public.ledger_entries (
        id, fan_id, amount, type, status, source_type, source_id, note
    ) VALUES (
        v_release_entry_id, v_entry.fan_id, v_entry.amount, v_entry.type, 'confirmed', 'hold_release', p_ledger_id::text,
        'Liberado por admin: ' || p_note
    );

    -- C) Update Wallet Balance Cache
    INSERT INTO public.wallets (fan_id, balance_cache)
    VALUES (v_entry.fan_id, v_entry.amount)
    ON CONFLICT (fan_id)
    DO UPDATE SET balance_cache = wallets.balance_cache + v_entry.amount, updated_at = NOW();

    -- D) Audit Log
    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'release_held_pearls', 'ledger_entries', p_ledger_id::text,
        jsonb_build_object('fan_id', v_entry.fan_id, 'amount', v_entry.amount, 'note', p_note, 'release_entry_id', v_release_entry_id)
    );

    RETURN jsonb_build_object(
        'status', 'released',
        'ledger_id', p_ledger_id,
        'release_entry_id', v_release_entry_id,
        'amount', v_entry.amount
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.admin_release_held_pearls(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_release_held_pearls(UUID, TEXT) TO authenticated, service_role;


-- 4. Append-Only RPC: admin_revoke_held_pearls
CREATE OR REPLACE FUNCTION public.admin_revoke_held_pearls(
    p_ledger_id UUID,
    p_note TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_entry public.ledger_entries%ROWTYPE;
BEGIN
    PERFORM public.assert_admin();

    IF p_note IS NULL OR trim(p_note) = '' THEN
        RAISE EXCEPTION 'La justificación es obligatoria para revocar perlitas retenidas.';
    END IF;

    SELECT * INTO v_entry FROM public.ledger_entries WHERE id = p_ledger_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Registro de libro no encontrado.';
    END IF;

    IF v_entry.status != 'held' THEN
        RAISE EXCEPTION 'El registro no se encuentra en estado retenido (held).';
    END IF;

    IF EXISTS (SELECT 1 FROM public.ledger_hold_resolutions WHERE ledger_id = p_ledger_id) THEN
        RAISE EXCEPTION 'El registro retenido ya ha sido resuelto previamente (liberado o revocado).';
    END IF;

    -- A) Insert Resolution Record
    INSERT INTO public.ledger_hold_resolutions (
        ledger_id, action, note, resolved_by
    ) VALUES (
        p_ledger_id, 'revoke', p_note, v_admin_id
    );

    -- B) Audit Log (No wallet update required since held amount was never added to wallet)
    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'revoke_held_pearls', 'ledger_entries', p_ledger_id::text,
        jsonb_build_object('fan_id', v_entry.fan_id, 'amount', v_entry.amount, 'note', p_note)
    );

    RETURN jsonb_build_object(
        'status', 'revoked',
        'ledger_id', p_ledger_id,
        'amount', v_entry.amount
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.admin_revoke_held_pearls(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_revoke_held_pearls(UUID, TEXT) TO authenticated, service_role;


-- 5. Update wallet_summary (Unresolved held pearls)
CREATE OR REPLACE FUNCTION public.wallet_summary()
RETURNS JSONB AS $$
DECLARE
    v_fan_id UUID := auth.uid();
    v_balance INT := 0;
    v_earned_month INT := 0;
    v_spent_month INT := 0;
    v_held_pearls INT := 0;
    v_start_of_month TIMESTAMPTZ := date_trunc('month', NOW());
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    -- Saldo en billetera
    SELECT balance_cache INTO v_balance FROM wallets WHERE fan_id = v_fan_id;
    v_balance := COALESCE(v_balance, 0);

    -- Ganadas del mes (entradas positivas confirmadas)
    SELECT COALESCE(SUM(amount), 0) INTO v_earned_month
    FROM ledger_entries
    WHERE fan_id = v_fan_id
      AND amount > 0
      AND status = 'confirmed'
      AND created_at >= v_start_of_month;

    -- Gastadas del mes (entradas negativas confirmadas en valor absoluto)
    SELECT COALESCE(ABS(SUM(amount)), 0) INTO v_spent_month
    FROM ledger_entries
    WHERE fan_id = v_fan_id
      AND amount < 0
      AND status = 'confirmed'
      AND created_at >= v_start_of_month;

    -- Perlitas retenidas pendientes de resolución
    SELECT COALESCE(SUM(le.amount), 0) INTO v_held_pearls
    FROM ledger_entries le
    WHERE le.fan_id = v_fan_id
      AND le.status = 'held'
      AND NOT EXISTS (
          SELECT 1 FROM public.ledger_hold_resolutions r WHERE r.ledger_id = le.id
      );

    RETURN jsonb_build_object(
        'balance', v_balance,
        'earned_month', v_earned_month,
        'spent_month', v_spent_month,
        'held_pearls', v_held_pearls
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.wallet_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.wallet_summary() TO authenticated, service_role;


-- 6. Update admin_risk_queue (Unresolved held pearls)
CREATE OR REPLACE FUNCTION public.admin_risk_queue(
    p_resolved BOOLEAN DEFAULT false
)
RETURNS JSONB AS $$
DECLARE
    v_res JSONB;
BEGIN
    PERFORM public.assert_admin();

    SELECT jsonb_agg(
        jsonb_build_object(
            'flag_id', rf.id,
            'fan_id', rf.fan_id,
            'display_name', p.display_name,
            'reason', rf.reason,
            'severity', rf.severity,
            'resolved', rf.resolved,
            'created_at', rf.created_at,
            'held_pearls', (
                SELECT COALESCE(SUM(le.amount), 0)
                FROM public.ledger_entries le
                WHERE le.fan_id = rf.fan_id
                  AND le.status = 'held'
                  AND NOT EXISTS (
                      SELECT 1 FROM public.ledger_hold_resolutions r WHERE r.ledger_id = le.id
                  )
            )
        ) ORDER BY rf.created_at DESC
    ) INTO v_res
    FROM public.risk_flags rf
    JOIN public.profiles p ON p.id = rf.fan_id
    WHERE rf.resolved = p_resolved;

    RETURN COALESCE(v_res, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.admin_risk_queue(BOOLEAN) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_risk_queue(BOOLEAN) TO authenticated, service_role;


-- 7. Update analytics_economy (Unresolved held pearls)
CREATE OR REPLACE FUNCTION public.analytics_economy()
RETURNS JSONB AS $$
DECLARE
    v_total_issued BIGINT;
    v_total_spent BIGINT;
    v_total_in_circulation BIGINT;
    v_total_held BIGINT;
    v_min_product_cost INT;
    v_max_product_cost INT;
    v_avg_daily_earnings_per_fan NUMERIC;
    v_days_for_cheapest NUMERIC;
    v_days_for_most_expensive NUMERIC;
BEGIN
    PERFORM public.assert_admin();

    -- Issued, Spent & Pending Held from Ledger
    SELECT
        COALESCE(SUM(CASE WHEN amount > 0 AND status = 'confirmed' THEN amount ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN amount < 0 AND status = 'confirmed' THEN ABS(amount) ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN status = 'held' AND NOT EXISTS (SELECT 1 FROM public.ledger_hold_resolutions r WHERE r.ledger_id = le.id) THEN amount ELSE 0 END), 0)
    INTO v_total_issued, v_total_spent, v_total_held
    FROM public.ledger_entries le;

    -- In Circulation from Wallets Cache
    SELECT COALESCE(SUM(balance_cache), 0) INTO v_total_in_circulation
    FROM public.wallets;

    -- Product cost bounds
    SELECT MIN(cost_pearls), MAX(cost_pearls)
    INTO v_min_product_cost, v_max_product_cost
    FROM public.products
    WHERE active = true;

    -- Average daily earnings per active fan
    SELECT COALESCE(AVG(pearls_earned), 50.0)
    INTO v_avg_daily_earnings_per_fan
    FROM (
        SELECT fan_id, SUM(pearls_awarded) AS pearls_earned
        FROM public.trivia_attempts
        WHERE submitted_at >= NOW() - INTERVAL '30 days'
        GROUP BY fan_id
    ) sub;

    IF v_avg_daily_earnings_per_fan <= 0 THEN
        v_avg_daily_earnings_per_fan := 50.0;
    END IF;

    v_days_for_cheapest := ROUND((COALESCE(v_min_product_cost, 0)::NUMERIC / v_avg_daily_earnings_per_fan), 1);
    v_days_for_most_expensive := ROUND((COALESCE(v_max_product_cost, 0)::NUMERIC / v_avg_daily_earnings_per_fan), 1);

    RETURN jsonb_build_object(
        'total_issued', v_total_issued,
        'total_spent', v_total_spent,
        'total_in_circulation', v_total_in_circulation,
        'total_held', v_total_held,
        'min_product_cost', v_min_product_cost,
        'max_product_cost', v_max_product_cost,
        'avg_daily_earnings_per_fan', v_avg_daily_earnings_per_fan,
        'days_for_cheapest_product', v_days_for_cheapest,
        'days_for_most_expensive_product', v_days_for_most_expensive
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.analytics_economy() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.analytics_economy() TO authenticated, service_role;


-- 8. Update Materialized View mv_daily_economy_stats
DROP MATERIALIZED VIEW IF EXISTS public.mv_daily_economy_stats CASCADE;

CREATE MATERIALIZED VIEW public.mv_daily_economy_stats AS
SELECT
    (le.created_at AT TIME ZONE 'America/Caracas')::DATE AS entry_date,
    COALESCE(SUM(CASE WHEN le.status = 'confirmed' AND le.amount > 0 THEN le.amount ELSE 0 END), 0) AS pearls_issued,
    COALESCE(SUM(CASE WHEN le.status = 'confirmed' AND le.amount < 0 THEN ABS(le.amount) ELSE 0 END), 0) AS pearls_spent,
    COALESCE(SUM(CASE WHEN le.status = 'held' AND NOT EXISTS (SELECT 1 FROM public.ledger_hold_resolutions r WHERE r.ledger_id = le.id) THEN le.amount ELSE 0 END), 0) AS pearls_held
FROM public.ledger_entries le
GROUP BY 1;

CREATE UNIQUE INDEX idx_mv_daily_economy_stats_pk ON public.mv_daily_economy_stats (entry_date);
REVOKE ALL ON public.mv_daily_economy_stats FROM PUBLIC, anon, authenticated;


-- 9. Update delete_my_account (Unresolved held pearls)
CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS JSONB AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_status user_status;
    v_unresolved_flags INT;
    v_pending_redemptions INT;
    v_held_entries INT;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT status INTO v_status FROM profiles WHERE id = v_uid;

    IF v_status = 'deleted' THEN
        RETURN jsonb_build_object(
            'success', true,
            'message', 'La cuenta ya ha sido eliminada previamente.',
            'already_deleted', true
        );
    END IF;

    IF v_status = 'suspended' THEN
        RAISE EXCEPTION 'Cuentas suspendidas no pueden ser eliminadas directamente.';
    END IF;

    SELECT COUNT(*) INTO v_unresolved_flags FROM risk_flags WHERE fan_id = v_uid AND resolved = false;
    IF v_unresolved_flags > 0 THEN
        RAISE EXCEPTION 'Existen verificaciones pendientes en tu cuenta. Contáctate con soporte.';
    END IF;

    SELECT COUNT(*) INTO v_pending_redemptions
    FROM public.redemptions
    WHERE fan_id = v_uid AND status IN ('pending', 'approved', 'scheduled');

    IF v_pending_redemptions > 0 THEN
        RAISE EXCEPTION 'No puedes eliminar tu cuenta mientras tengas % canje(s) en proceso o pendiente(s) de entrega. Por favor completa o cancela tus canjes primero.', v_pending_redemptions;
    END IF;

    -- Check pending held entries (without resolution)
    SELECT COUNT(*) INTO v_held_entries
    FROM public.ledger_entries le
    WHERE le.fan_id = v_uid
      AND le.status = 'held'
      AND NOT EXISTS (
          SELECT 1 FROM public.ledger_hold_resolutions r WHERE r.ledger_id = le.id
      );

    IF v_held_entries > 0 THEN
        RAISE EXCEPTION 'No puedes eliminar tu cuenta mientras tengas perlitas retenidas bajo revisión de soporte.';
    END IF;

    UPDATE public.profiles
    SET display_name = 'Fanático Anónimo',
        avatar_url = NULL,
        municipality = NULL,
        birth_date = NULL,
        gender = NULL,
        favorite_player_id = NULL,
        shirt_size = NULL,
        referral_source = NULL,
        notification_prefs = '{}'::jsonb,
        status = 'deleted',
        deleted_at = NOW()
    WHERE id = v_uid;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        v_uid, 'delete_my_account', 'profiles', v_uid::text,
        jsonb_build_object('status', COALESCE(v_status::text, 'active')),
        jsonb_build_object('status', 'deleted', 'anonymized', true, 'deleted_at', NOW())
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Cuenta anonimizada y eliminada exitosamente.',
        'already_deleted', false
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.delete_my_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated, service_role;


-- 10. Update reconcile_wallets
CREATE OR REPLACE FUNCTION public.reconcile_wallets()
RETURNS TABLE (
    fan_id UUID,
    balance_cache INT,
    computed_balance INT,
    difference INT
) AS $$
DECLARE
    v_actor_id UUID := auth.uid();
BEGIN
    IF v_actor_id IS NOT NULL AND NOT is_admin(v_actor_id) THEN
        RAISE EXCEPTION 'Only service_role or admin can run wallet reconciliation.';
    END IF;

    RETURN QUERY
    SELECT 
        w.fan_id,
        w.balance_cache,
        COALESCE(sub.sum_amount, 0)::INT AS computed_balance,
        (w.balance_cache - COALESCE(sub.sum_amount, 0))::INT AS difference
    FROM wallets w
    LEFT JOIN (
        SELECT le.fan_id, SUM(le.amount) AS sum_amount
        FROM ledger_entries le
        WHERE le.status = 'confirmed'
        GROUP BY le.fan_id
    ) sub ON sub.fan_id = w.fan_id
    WHERE w.balance_cache != COALESCE(sub.sum_amount, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.reconcile_wallets() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reconcile_wallets() TO service_role;
