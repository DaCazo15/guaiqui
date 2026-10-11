-- Migration: 20261010000036_fase18_rewarded_ads.sql
-- Description: Rewarded Ads with Google Ad Manager & GPT (Fase 18) - Schema, RLS, economy settings, sessions, daily progress, reconciliation, anti-fraud risk rules, and admin analytics.

-- 1. Ledger Entry Type extension
ALTER TYPE ledger_type ADD VALUE IF NOT EXISTS 'ad_reward';

-- 2. Economy Settings extension
ALTER TABLE public.economy_settings
  ADD COLUMN IF NOT EXISTS ads_enabled BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS daily_ad_views INT NOT NULL DEFAULT 50,
  ADD COLUMN IF NOT EXISTS block_size INT NOT NULL DEFAULT 10,
  ADD COLUMN IF NOT EXISTS ad_min_seconds INT NOT NULL DEFAULT 6,
  ADD COLUMN IF NOT EXISTS ad_min_account_age_days INT NOT NULL DEFAULT 3,
  ADD COLUMN IF NOT EXISTS ad_min_trivias_completed INT NOT NULL DEFAULT 1;

-- 3. Ad Reward Tiers table
CREATE TABLE IF NOT EXISTS public.ad_reward_tiers (
    block_number INT PRIMARY KEY CHECK (block_number > 0),
    pearls INT NOT NULL CHECK (pearls > 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO public.ad_reward_tiers (block_number, pearls) VALUES
    (1, 5),
    (2, 10),
    (3, 15),
    (4, 20),
    (5, 25)
ON CONFLICT (block_number) DO UPDATE SET pearls = EXCLUDED.pearls;

ALTER TABLE public.ad_reward_tiers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "AdRewardTiers Public Read" ON public.ad_reward_tiers;
CREATE POLICY "AdRewardTiers Public Read" ON public.ad_reward_tiers FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS "AdRewardTiers Admin Write" ON public.ad_reward_tiers;
CREATE POLICY "AdRewardTiers Admin Write" ON public.ad_reward_tiers FOR ALL TO authenticated USING (public.is_admin_check());

-- 4. Ad Sessions Table
CREATE TABLE IF NOT EXISTS public.ad_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    status TEXT NOT NULL CHECK (status IN ('started', 'completed', 'void', 'expired', 'no_fill', 'declined', 'closed_early', 'error')),
    reason TEXT,
    day DATE NOT NULL,
    block_index INT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ad_sessions_user_day ON public.ad_sessions (user_id, day);
CREATE INDEX IF NOT EXISTS idx_ad_sessions_status ON public.ad_sessions (status);

ALTER TABLE public.ad_sessions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ad_sessions FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.ad_sessions TO service_role, postgres;

-- 5. Ad Daily Progress Table
CREATE TABLE IF NOT EXISTS public.ad_daily_progress (
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    day DATE NOT NULL,
    completed_count INT NOT NULL DEFAULT 0 CHECK (completed_count >= 0 AND completed_count <= 50),
    blocks_paid INT NOT NULL DEFAULT 0 CHECK (blocks_paid >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, day)
);

ALTER TABLE public.ad_daily_progress ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ad_daily_progress FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.ad_daily_progress TO service_role, postgres;

-- 6. Ad Reconciliation Table
CREATE TABLE IF NOT EXISTS public.ad_reconciliation (
    day DATE PRIMARY KEY,
    google_rewarded_impressions INT NOT NULL DEFAULT 0 CHECK (google_rewarded_impressions >= 0),
    imported_by UUID REFERENCES auth.users(id),
    imported_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    notes TEXT
);

ALTER TABLE public.ad_reconciliation ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ad_reconciliation FROM PUBLIC, anon, authenticated;
DROP POLICY IF EXISTS "AdReconciliation Admin Read" ON public.ad_reconciliation;
CREATE POLICY "AdReconciliation Admin Read" ON public.ad_reconciliation FOR SELECT TO authenticated USING (public.is_admin_check());
GRANT SELECT ON public.ad_reconciliation TO authenticated, service_role;

-- 7. Unique Partial Index on ledger_entries to prevent double payment for ad blocks
CREATE UNIQUE INDEX IF NOT EXISTS idx_ledger_ad_block ON public.ledger_entries (source_type, source_id) WHERE source_type = 'ad_block';

-- 8. RPC: get_ads_progress()
CREATE OR REPLACE FUNCTION public.get_ads_progress()
RETURNS JSONB AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_today DATE := (NOW() AT TIME ZONE 'America/Caracas')::date;
    v_eco RECORD;
    v_completed INT := 0;
    v_earned_today INT := 0;
    v_account_age_days INT;
    v_trivias_count INT;
    v_can_watch BOOLEAN := true;
    v_cant_reason TEXT := NULL;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT ads_enabled, daily_ad_views, block_size, ad_min_seconds, ad_min_account_age_days, ad_min_trivias_completed
    INTO v_eco
    FROM public.economy_settings
    ORDER BY created_at DESC LIMIT 1;

    -- Check daily completed count
    SELECT COALESCE(completed_count, 0) INTO v_completed
    FROM public.ad_daily_progress
    WHERE user_id = v_uid AND day = v_today;

    -- Calculate total pearls earned from ads today
    SELECT COALESCE(SUM(amount), 0) INTO v_earned_today
    FROM public.ledger_entries
    WHERE fan_id = v_uid
      AND type = 'ad_reward'
      AND (created_at AT TIME ZONE 'America/Caracas')::date = v_today;

    -- Check conditions if fan can watch ads
    IF v_eco.ads_enabled IS NOT TRUE THEN
        v_can_watch := false;
        v_cant_reason := 'ADS_DISABLED';
    ELSIF v_completed >= v_eco.daily_ad_views THEN
        v_can_watch := false;
        v_cant_reason := 'AD_DAILY_LIMIT';
    ELSE
        SELECT EXTRACT(DAY FROM (NOW() - created_at))::int INTO v_account_age_days
        FROM public.profiles WHERE id = v_uid;

        IF COALESCE(v_account_age_days, 0) < v_eco.ad_min_account_age_days THEN
            v_can_watch := false;
            v_cant_reason := 'ACCOUNT_TOO_NEW';
        ELSE
            SELECT COUNT(*) INTO v_trivias_count
            FROM public.trivia_attempts
            WHERE fan_id = v_uid AND submitted_at IS NOT NULL;

            IF v_trivias_count < v_eco.ad_min_trivias_completed THEN
                v_can_watch := false;
                v_cant_reason := 'TRIVIAS_REQUIRED';
            END IF;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'completed_today', v_completed,
        'daily_limit', v_eco.daily_ad_views,
        'block_size', v_eco.block_size,
        'block_progress', v_completed % v_eco.block_size,
        'next_block_number', (v_completed / v_eco.block_size) + 1,
        'pearls_earned_today', v_earned_today,
        'can_watch', v_can_watch,
        'cant_reason', v_cant_reason,
        'ad_min_seconds', v_eco.ad_min_seconds
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.get_ads_progress() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_ads_progress() TO authenticated, service_role;


-- 9. RPC: start_ad_session(p_idempotency_key TEXT)
CREATE OR REPLACE FUNCTION public.start_ad_session(p_idempotency_key TEXT DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
    v_uid UUID;
    v_today DATE := (NOW() AT TIME ZONE 'America/Caracas')::date;
    v_eco RECORD;
    v_completed INT := 0;
    v_account_age_days INT;
    v_trivias_count INT;
    v_pass_id UUID;
    v_session_id UUID;
BEGIN
    v_uid := public.assert_active_verified_fan();

    SELECT ads_enabled, daily_ad_views, block_size, ad_min_seconds, ad_min_account_age_days, ad_min_trivias_completed
    INTO v_eco
    FROM public.economy_settings
    ORDER BY created_at DESC LIMIT 1;

    IF v_eco.ads_enabled IS NOT TRUE THEN
        RAISE EXCEPTION 'Los anuncios están temporalmente desactivados.' USING ERRCODE = 'P0001';
    END IF;

    SELECT EXTRACT(DAY FROM (NOW() - created_at))::int INTO v_account_age_days
    FROM public.profiles WHERE id = v_uid;

    IF COALESCE(v_account_age_days, 0) < v_eco.ad_min_account_age_days THEN
        RAISE EXCEPTION 'Tu cuenta requiere al menos % días de antigüedad para ver anuncios.', v_eco.ad_min_account_age_days USING ERRCODE = 'P0001';
    END IF;

    SELECT COUNT(*) INTO v_trivias_count
    FROM public.trivia_attempts
    WHERE fan_id = v_uid AND submitted_at IS NOT NULL;

    IF v_trivias_count < v_eco.ad_min_trivias_completed THEN
        RAISE EXCEPTION 'Debes completar al menos % trivia para poder ver anuncios.', v_eco.ad_min_trivias_completed USING ERRCODE = 'P0001';
    END IF;

    -- Rate limiting check (max 10 session starts per minute)
    PERFORM public.check_rate_limit(v_uid, 'start_ad_session', 10, 60);

    -- Lock or check daily progress
    INSERT INTO public.ad_daily_progress (user_id, day, completed_count)
    VALUES (v_uid, v_today, 0)
    ON CONFLICT (user_id, day) DO UPDATE SET updated_at = NOW()
    RETURNING completed_count INTO v_completed;

    IF v_completed >= v_eco.daily_ad_views THEN
        RAISE EXCEPTION 'Has alcanzado el límite diario de 50 anuncios por hoy.' USING ERRCODE = 'P0001';
    END IF;

    -- Captcha pass required for the FIRST session of the day
    IF v_completed = 0 AND NOT EXISTS (SELECT 1 FROM public.ad_sessions WHERE user_id = v_uid AND day = v_today AND status = 'completed') THEN
        SELECT id INTO v_pass_id
        FROM public.captcha_passes
        WHERE user_id = v_uid AND used = false AND expires_at > NOW()
        ORDER BY created_at DESC
        LIMIT 1
        FOR UPDATE;

        IF v_pass_id IS NULL THEN
            RAISE EXCEPTION 'CAPTCHA_REQUIRED' USING ERRCODE = 'P0001';
        END IF;

        UPDATE public.captcha_passes SET used = true WHERE id = v_pass_id;
    END IF;

    -- Void any existing started session for this user
    UPDATE public.ad_sessions
    SET status = 'void', reason = 'superseded_by_new_session'
    WHERE user_id = v_uid AND status = 'started';

    -- Create new session
    INSERT INTO public.ad_sessions (user_id, started_at, status, day)
    VALUES (v_uid, NOW(), 'started', v_today)
    RETURNING id INTO v_session_id;

    RETURN jsonb_build_object(
        'session_id', v_session_id,
        'ad_min_seconds', v_eco.ad_min_seconds
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.start_ad_session(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_ad_session(TEXT) TO authenticated, service_role;


-- 10. RPC: cancel_ad_session(p_session_id UUID, p_reason TEXT)
CREATE OR REPLACE FUNCTION public.cancel_ad_session(p_session_id UUID, p_reason TEXT)
RETURNS JSONB AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_valid_reasons TEXT[] := ARRAY['declined', 'no_fill', 'closed_early', 'error'];
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    IF NOT (p_reason = ANY(v_valid_reasons)) THEN
        RAISE EXCEPTION 'Motivo de cancelación no válido.';
    END IF;

    UPDATE public.ad_sessions
    SET status = p_reason, reason = p_reason
    WHERE id = p_session_id AND user_id = v_uid AND status = 'started';

    RETURN jsonb_build_object('success', true, 'session_id', p_session_id, 'status', p_reason);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.cancel_ad_session(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_ad_session(UUID, TEXT) TO authenticated, service_role;


-- 11. RPC: complete_ad_session(p_session_id UUID, p_idempotency_key TEXT)
CREATE OR REPLACE FUNCTION public.complete_ad_session(p_session_id UUID, p_idempotency_key TEXT)
RETURNS JSONB AS $$
DECLARE
    v_uid UUID;
    v_today DATE := (NOW() AT TIME ZONE 'America/Caracas')::date;
    v_session public.ad_sessions%ROWTYPE;
    v_eco RECORD;
    v_elapsed NUMERIC;
    v_new_count INT;
    v_block_index INT;
    v_pearls_tier INT := 0;
    v_source_id TEXT;
    v_is_held BOOLEAN := false;
    v_risk_level TEXT := 'low';
    v_ledger_status ledger_status := 'confirmed';
    v_ledger_id UUID := gen_random_uuid();
    v_paid BOOLEAN := false;
BEGIN
    v_uid := public.assert_active_verified_fan();

    SELECT * INTO v_session FROM public.ad_sessions WHERE id = p_session_id FOR UPDATE;
    IF NOT FOUND OR v_session.user_id != v_uid THEN
        RAISE EXCEPTION 'Sesión de anuncio no encontrada o no pertenece al usuario.';
    END IF;

    -- Idempotency check if already completed
    IF v_session.status = 'completed' THEN
        SELECT completed_count INTO v_new_count FROM public.ad_daily_progress WHERE user_id = v_uid AND day = v_today;
        RETURN jsonb_build_object(
            'status', 'already_completed',
            'session_id', p_session_id,
            'completed_today', COALESCE(v_new_count, 0)
        );
    END IF;

    IF v_session.status != 'started' THEN
        RAISE EXCEPTION 'La sesión ya no está en estado activo (%)..', v_session.status;
    END IF;

    SELECT daily_ad_views, block_size, ad_min_seconds INTO v_eco
    FROM public.economy_settings
    ORDER BY created_at DESC LIMIT 1;

    -- Time validation against SERVER clock
    v_elapsed := EXTRACT(EPOCH FROM (NOW() - v_session.started_at));

    IF v_elapsed < v_eco.ad_min_seconds THEN
        UPDATE public.ad_sessions SET status = 'error', reason = 'timing_too_fast' WHERE id = p_session_id;
        RAISE EXCEPTION 'El anuncio fue completado demasiado rápido (% s vs min % s).', round(v_elapsed, 1), v_eco.ad_min_seconds;
    END IF;

    IF v_elapsed > 600 THEN
        UPDATE public.ad_sessions SET status = 'expired', reason = 'exceeded_10_minutes' WHERE id = p_session_id;
        RAISE EXCEPTION 'La sesión de anuncio ha expirado por inactividad.';
    END IF;

    -- Mark session as completed
    UPDATE public.ad_sessions
    SET status = 'completed', completed_at = NOW()
    WHERE id = p_session_id AND status = 'started';

    -- Lock daily progress and increment count
    INSERT INTO public.ad_daily_progress (user_id, day, completed_count)
    VALUES (v_uid, v_today, 1)
    ON CONFLICT (user_id, day) DO UPDATE
    SET completed_count = LEAST(ad_daily_progress.completed_count + 1, 50),
        updated_at = NOW()
    RETURNING completed_count INTO v_new_count;

    -- Check if block reward is triggered
    IF v_new_count % v_eco.block_size = 0 THEN
        v_block_index := v_new_count / v_eco.block_size;
        
        -- Update block index in session
        UPDATE public.ad_sessions SET block_index = v_block_index WHERE id = p_session_id;

        -- Fetch block reward amount
        SELECT pearls INTO v_pearls_tier FROM public.ad_reward_tiers WHERE block_number = v_block_index;
        IF v_pearls_tier IS NULL THEN
            v_pearls_tier := 5 * v_block_index; -- fallback calculation
        END IF;

        v_source_id := 'ad_block:' || v_uid::text || ':' || v_today::text || ':' || v_block_index::text;

        -- Check risk
        PERFORM public.compute_risk(v_uid);
        
        IF EXISTS (
            SELECT 1 FROM public.risk_flags
            WHERE fan_id = v_uid AND resolved = false AND severity IN ('medium', 'high')
        ) THEN
            v_is_held := true;
            v_ledger_status := 'held';
        END IF;

        -- Insert ledger entry with UNIQUE source_id protection
        BEGIN
            INSERT INTO public.ledger_entries (
                id, fan_id, amount, type, status, source_type, source_id, note
            ) VALUES (
                v_ledger_id, v_uid, v_pearls_tier, 'ad_reward', v_ledger_status, 'ad_block', v_source_id,
                'Recompensa por bloque ' || v_block_index || ' (' || v_new_count || ' anuncios vistos)'
            );

            v_paid := true;

            IF v_ledger_status = 'confirmed' THEN
                UPDATE public.wallets
                SET balance_cache = balance_cache + v_pearls_tier,
                    updated_at = NOW()
                WHERE fan_id = v_uid;
            END IF;

            UPDATE public.ad_daily_progress
            SET blocks_paid = blocks_paid + 1
            WHERE user_id = v_uid AND day = v_today;

        EXCEPTION WHEN unique_violation THEN
            -- Block was already paid by concurrent transaction
            v_paid := false;
            v_pearls_tier := 0;
        END;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'completed_today', v_new_count,
        'daily_limit', v_eco.daily_ad_views,
        'block_size', v_eco.block_size,
        'block_progress', v_new_count % v_eco.block_size,
        'block_completed', (v_new_count % v_eco.block_size = 0),
        'pearls_awarded', v_pearls_tier,
        'held', v_is_held,
        'paid', v_paid
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.complete_ad_session(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_ad_session(UUID, TEXT) TO authenticated, service_role;


-- 12. Anti-fraud update to compute_risk(p_fan_id UUID)
CREATE OR REPLACE FUNCTION public.compute_risk(p_fan_id UUID)
RETURNS VOID AS $$
DECLARE
    v_device_count INT;
    v_ip_count INT;
    v_exact_min_sec_count INT;
    v_consecutive_caps INT;
    v_shared_cap_device INT;
    v_eco_min_sec INT;
BEGIN
    SELECT ad_min_seconds INTO v_eco_min_sec FROM public.economy_settings ORDER BY created_at DESC LIMIT 1;
    v_eco_min_sec := COALESCE(v_eco_min_sec, 6);

    -- 1. Check multiple accounts sharing same device_id
    SELECT COUNT(DISTINCT fan_id) INTO v_device_count
    FROM public.fraud_telemetry
    WHERE device_id IN (
        SELECT device_id FROM public.fraud_telemetry WHERE fan_id = p_fan_id AND device_id IS NOT NULL LIMIT 1
    );

    IF v_device_count >= 3 THEN
        INSERT INTO public.risk_flags (fan_id, reason, severity)
        VALUES (p_fan_id, 'Shared device across multiple accounts (' || v_device_count || ' fans)', 'medium')
        ON CONFLICT DO NOTHING;
    END IF;

    -- 2. Check multiple new accounts from same ip_hash in short window (24h)
    SELECT COUNT(DISTINCT fan_id) INTO v_ip_count
    FROM public.fraud_telemetry
    WHERE ip_hash IN (
        SELECT ip_hash FROM public.fraud_telemetry WHERE fan_id = p_fan_id AND ip_hash IS NOT NULL LIMIT 1
    ) AND created_at >= NOW() - INTERVAL '24 hours';

    IF v_ip_count >= 5 THEN
        INSERT INTO public.risk_flags (fan_id, reason, severity)
        VALUES (p_fan_id, 'High velocity account registrations from same IP hash (' || v_ip_count || ' fans)', 'medium')
        ON CONFLICT DO NOTHING;
    END IF;

    -- 3. Ad Risk: Sessions completed right at ad_min_seconds window consistently (5+ sessions within +/- 0.5s of min seconds)
    SELECT COUNT(*) INTO v_exact_min_sec_count
    FROM public.ad_sessions
    WHERE user_id = p_fan_id
      AND status = 'completed'
      AND completed_at IS NOT NULL
      AND ABS(EXTRACT(EPOCH FROM (completed_at - started_at)) - v_eco_min_sec) <= 0.5;

    IF v_exact_min_sec_count >= 5 THEN
        INSERT INTO public.risk_flags (fan_id, reason, severity)
        VALUES (p_fan_id, 'Sustained ad completions at exact minimum time threshold (' || v_exact_min_sec_count || ' sessions)', 'medium')
        ON CONFLICT DO NOTHING;
    END IF;

    -- 4. Ad Risk: Daily cap of 50 reached for 3+ consecutive days
    SELECT COUNT(*) INTO v_consecutive_caps
    FROM public.ad_daily_progress
    WHERE user_id = p_fan_id
      AND completed_count >= 50
      AND day >= (NOW() AT TIME ZONE 'America/Caracas')::date - INTERVAL '7 days';

    IF v_consecutive_caps >= 3 THEN
        INSERT INTO public.risk_flags (fan_id, reason, severity)
        VALUES (p_fan_id, 'Daily ad limit of 50 reached on ' || v_consecutive_caps || ' days in past week', 'medium')
        ON CONFLICT DO NOTHING;
    END IF;

    -- 5. Ad Risk: Multiple accounts with same device reaching ad cap
    SELECT COUNT(DISTINCT user_id) INTO v_shared_cap_device
    FROM public.ad_daily_progress dp
    WHERE dp.completed_count >= 50
      AND dp.user_id IN (
          SELECT DISTINCT fan_id FROM public.fraud_telemetry
          WHERE device_id IN (SELECT device_id FROM public.fraud_telemetry WHERE fan_id = p_fan_id AND device_id IS NOT NULL)
      );

    IF v_shared_cap_device >= 2 THEN
        INSERT INTO public.risk_flags (fan_id, reason, severity)
        VALUES (p_fan_id, 'Multiple accounts on same device hitting daily ad cap (' || v_shared_cap_device || ' accounts)', 'high')
        ON CONFLICT DO NOTHING;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;


-- 13. RPC: import_ad_report(p_day DATE, p_impressions INT, p_notes TEXT DEFAULT NULL) (Admin only)
CREATE OR REPLACE FUNCTION public.import_ad_report(
    p_day DATE,
    p_impressions INT,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_completed_count INT := 0;
    v_ratio NUMERIC := 0;
    v_alert_created BOOLEAN := false;
BEGIN
    PERFORM public.assert_admin();

    IF p_impressions < 0 THEN
        RAISE EXCEPTION 'El número de impresiones no puede ser negativo.';
    END IF;

    INSERT INTO public.ad_reconciliation (day, google_rewarded_impressions, imported_by, imported_at, notes)
    VALUES (p_day, p_impressions, v_admin_id, NOW(), p_notes)
    ON CONFLICT (day) DO UPDATE
    SET google_rewarded_impressions = EXCLUDED.google_rewarded_impressions,
        imported_by = EXCLUDED.imported_by,
        imported_at = NOW(),
        notes = EXCLUDED.notes;

    -- Count total completed ad sessions in DB for this day
    SELECT COUNT(*) INTO v_completed_count
    FROM public.ad_sessions
    WHERE day = p_day AND status = 'completed';

    -- Ratio calculation (our DB completions / Google reported impressions)
    IF p_impressions > 0 THEN
        v_ratio := round((v_completed_count::numeric / p_impressions::numeric), 2);
    ELSIF v_completed_count > 0 THEN
        v_ratio := 99.9; -- Infinity alert threshold
    END IF;

    -- If ratio exceeds 1.2 threshold, flag system alert
    IF v_ratio > 1.2 THEN
        INSERT INTO public.system_alerts (
            type, title, message, severity, entity_id
        ) VALUES (
            'ad_discrepancy',
            'Discrepancia detectada en anuncios recompensados (' || p_day::text || ')',
            'Las sesiones completadas en DB (' || v_completed_count || ') superan las impresiones de Google GAM (' || p_impressions || ') por una proporción de ' || v_ratio || ' (límite: 1.2). Posible intento de manipulación del cliente.',
            'high',
            p_day::text
        );
        v_alert_created := true;
    END IF;

    -- Audit log entry
    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        v_admin_id, 'import_ad_report', 'ad_reconciliation', p_day::text,
        NULL, jsonb_build_object('impressions', p_impressions, 'completed_db', v_completed_count, 'ratio', v_ratio, 'alert_created', v_alert_created)
    );

    RETURN jsonb_build_object(
        'success', true,
        'day', p_day,
        'google_impressions', p_impressions,
        'db_completed_sessions', v_completed_count,
        'discrepancy_ratio', v_ratio,
        'alert_flagged', v_alert_created
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.import_ad_report(DATE, INT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.import_ad_report(DATE, INT, TEXT) TO authenticated, service_role;


-- 14. RPC: admin_update_ads_settings(p_settings JSONB) (Admin only)
CREATE OR REPLACE FUNCTION public.admin_update_ads_settings(p_settings JSONB)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_enabled BOOLEAN;
    v_daily_views INT;
    v_block_size INT;
    v_min_sec INT;
    v_min_age INT;
    v_min_trivias INT;
    v_tiers JSONB;
    v_tier RECORD;
    v_old_settings JSONB;
BEGIN
    PERFORM public.assert_admin();

    v_enabled := COALESCE((p_settings->>'ads_enabled')::boolean, true);
    v_daily_views := COALESCE((p_settings->>'daily_ad_views')::int, 50);
    v_block_size := COALESCE((p_settings->>'block_size')::int, 10);
    v_min_sec := COALESCE((p_settings->>'ad_min_seconds')::int, 6);
    v_min_age := COALESCE((p_settings->>'ad_min_account_age_days')::int, 3);
    v_min_trivias := COALESCE((p_settings->>'ad_min_trivias_completed')::int, 1);
    v_tiers := p_settings->'reward_tiers';

    IF v_daily_views <= 0 OR v_block_size <= 0 OR v_min_sec <= 0 THEN
        RAISE EXCEPTION 'Los parámetros numéricos deben ser mayores a 0.';
    END IF;

    IF v_daily_views % v_block_size != 0 THEN
        RAISE EXCEPTION 'El límite diario (%) debe ser múltiplo del tamaño de bloque (%).', v_daily_views, v_block_size;
    END IF;

    SELECT jsonb_build_object(
        'ads_enabled', ads_enabled,
        'daily_ad_views', daily_ad_views,
        'block_size', block_size,
        'ad_min_seconds', ad_min_seconds,
        'ad_min_account_age_days', ad_min_account_age_days,
        'ad_min_trivias_completed', ad_min_trivias_completed
    ) INTO v_old_settings
    FROM public.economy_settings
    ORDER BY created_at DESC LIMIT 1;

    -- Update economy settings
    UPDATE public.economy_settings
    SET ads_enabled = v_enabled,
        daily_ad_views = v_daily_views,
        block_size = v_block_size,
        ad_min_seconds = v_min_sec,
        ad_min_account_age_days = v_min_age,
        ad_min_trivias_completed = v_min_trivias;

    -- Update reward tiers if provided
    IF v_tiers IS NOT NULL AND jsonb_array_length(v_tiers) > 0 THEN
        FOR v_tier IN SELECT * FROM jsonb_to_recordset(v_tiers) AS x(block_number int, pearls int) LOOP
            IF v_tier.block_number IS NOT NULL AND v_tier.pearls IS NOT NULL AND v_tier.pearls > 0 THEN
                INSERT INTO public.ad_reward_tiers (block_number, pearls)
                VALUES (v_tier.block_number, v_tier.pearls)
                ON CONFLICT (block_number) DO UPDATE SET pearls = EXCLUDED.pearls, updated_at = NOW();
            END IF;
        END LOOP;
    END IF;

    -- Audit log entry
    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        v_admin_id, 'update_ads_settings', 'economy_settings', '1',
        v_old_settings, p_settings
    );

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.admin_update_ads_settings(JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_ads_settings(JSONB) TO authenticated, service_role;


-- 15. RPC: analytics_ads(p_from TIMESTAMPTZ, p_to TIMESTAMPTZ) (Admin only)
CREATE OR REPLACE FUNCTION public.analytics_ads(
    p_from TIMESTAMPTZ DEFAULT NOW() - INTERVAL '30 days',
    p_to TIMESTAMPTZ DEFAULT NOW()
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_total_started INT := 0;
    v_total_completed INT := 0;
    v_unique_users INT := 0;
    v_total_pearls_paid INT := 0;
    v_by_reason JSONB;
    v_cap_reached_users INT := 0;
    v_cap_percentage NUMERIC := 0;
    v_reconciliation JSONB;
BEGIN
    PERFORM public.assert_admin();

    SELECT COUNT(*) INTO v_total_started
    FROM public.ad_sessions WHERE started_at >= p_from AND started_at <= p_to;

    SELECT COUNT(*) INTO v_total_completed
    FROM public.ad_sessions WHERE status = 'completed' AND completed_at >= p_from AND completed_at <= p_to;

    SELECT COUNT(DISTINCT user_id) INTO v_unique_users
    FROM public.ad_sessions WHERE started_at >= p_from AND started_at <= p_to;

    SELECT COALESCE(SUM(amount), 0) INTO v_total_pearls_paid
    FROM public.ledger_entries
    WHERE type = 'ad_reward' AND created_at >= p_from AND created_at <= p_to AND status = 'confirmed';

    -- Cancellation by reason
    SELECT COALESCE(jsonb_object_agg(reason, count), '{}'::jsonb) INTO v_by_reason
    FROM (
        SELECT COALESCE(reason, status) AS reason, COUNT(*) AS count
        FROM public.ad_sessions
        WHERE status != 'completed' AND status != 'started' AND started_at >= p_from AND started_at <= p_to
        GROUP BY COALESCE(reason, status)
    ) x;

    -- Percentage of users hitting cap (50 views) at least once
    SELECT COUNT(DISTINCT user_id) INTO v_cap_reached_users
    FROM public.ad_daily_progress
    WHERE completed_count >= 50 AND created_at >= p_from AND created_at <= p_to;

    IF v_unique_users > 0 THEN
        v_cap_percentage := round((v_cap_reached_users::numeric / v_unique_users::numeric) * 100, 1);
    END IF;

    -- Reconciliation summary by day
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'day', r.day,
            'google_impressions', r.google_rewarded_impressions,
            'db_completed', (SELECT COUNT(*) FROM public.ad_sessions s WHERE s.day = r.day AND s.status = 'completed'),
            'imported_at', r.imported_at,
            'notes', r.notes
        ) ORDER BY r.day DESC
    ), '[]'::jsonb) INTO v_reconciliation
    FROM public.ad_reconciliation r
    WHERE r.day >= p_from::date AND r.day <= p_to::date;

    RETURN jsonb_build_object(
        'period_from', p_from,
        'period_to', p_to,
        'sessions_started', v_total_started,
        'sessions_completed', v_total_completed,
        'unique_fans', v_unique_users,
        'pearls_paid', v_total_pearls_paid,
        'cancellations_by_reason', v_by_reason,
        'fans_hitting_cap', v_cap_reached_users,
        'cap_percentage', v_cap_percentage,
        'reconciliation_history', v_reconciliation
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.analytics_ads(TIMESTAMPTZ, TIMESTAMPTZ) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.analytics_ads(TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated, service_role;


-- 16. Update policy_documents to reference 3rd party ads & ad session data
UPDATE public.policy_documents
SET is_active = false, updated_at = NOW()
WHERE slug = 'privacidad' AND is_active = true;

INSERT INTO public.policy_documents (slug, version, content_markdown, is_active)
VALUES (
    'privacidad',
    '18.0',
    '# Política de Privacidad (v18.0)

Actualización Fase 18: Recopilación y procesamiento de datos para anuncios de terceros con Google Ad Manager y Google Publisher Tag (GPT), cookies publicitarias no personalizadas y registro auditado de sesiones de recompensa.',
    true
);

