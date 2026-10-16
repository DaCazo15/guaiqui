-- Migration: 20261009000016_fase11_anti_fraud.sql
-- Description: Anti-fraud Tables, Rate Limiting, Turnstile Captcha Passes, Risk Engine, Ban Evasion Tracking & Admin Review Functions (Fase 11)

-- ==========================================
-- 1. CAPTCHA PASSES TABLE
-- ==========================================
CREATE TABLE IF NOT EXISTS public.captcha_passes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    ip_hash TEXT NOT NULL,
    used BOOLEAN NOT NULL DEFAULT false,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_captcha_passes_user_valid ON public.captcha_passes (user_id, expires_at) WHERE used = false;
ALTER TABLE public.captcha_passes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.captcha_passes FROM PUBLIC, anon, authenticated;

-- ==========================================
-- 2. RATE LIMITS TABLE & INTERNAL CHECK FUNCTION
-- ==========================================
CREATE TABLE IF NOT EXISTS public.rate_limits (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    action TEXT NOT NULL,
    window_start TIMESTAMPTZ NOT NULL,
    request_count INT NOT NULL DEFAULT 1,
    PRIMARY KEY (user_id, action, window_start)
);

ALTER TABLE public.rate_limits ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.rate_limits FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.check_rate_limit(
    p_user_id UUID,
    p_action TEXT,
    p_max INT,
    p_window_seconds INT
)
RETURNS VOID AS $$
DECLARE
    v_now TIMESTAMPTZ := NOW();
    v_window_start TIMESTAMPTZ := to_timestamp(floor(EXTRACT(EPOCH FROM v_now) / p_window_seconds) * p_window_seconds);
    v_count INT;
BEGIN
    INSERT INTO public.rate_limits (user_id, action, window_start, request_count)
    VALUES (p_user_id, p_action, v_window_start, 1)
    ON CONFLICT (user_id, action, window_start)
    DO UPDATE SET request_count = rate_limits.request_count + 1
    RETURNING request_count INTO v_count;

    IF v_count > p_max THEN
        RAISE EXCEPTION 'RATE_LIMITED';
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- ==========================================
-- 3. RISK SETTINGS & BLOCKED IDENTITIES
-- ==========================================
CREATE TABLE IF NOT EXISTS public.risk_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key TEXT UNIQUE NOT NULL,
    value JSONB NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO public.risk_settings (key, value, description)
VALUES
  ('timing_implausible_seconds', '3.0'::jsonb, 'Umbral mínimo de tiempo de trivia (segundos)'),
  ('high_value_product_pearls', '3000'::jsonb, 'Umbral de costo para exigir fricción proporcional'),
  ('min_account_age_days', '7'::jsonb, 'Antigüedad mínima de cuenta para canjes de alto valor'),
  ('min_trivias_completed', '3'::jsonb, 'Mínimo de trivias para canjes de alto valor')
ON CONFLICT (key) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.blocked_identities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email_hmac TEXT UNIQUE NOT NULL,
    reason TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.blocked_identities ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.blocked_identities FROM PUBLIC, anon, authenticated;


-- ==========================================
-- 4. FRAUD TELEMETRY & PURGE (30 DAYS AGING)
-- ==========================================
CREATE TABLE IF NOT EXISTS public.fraud_telemetry (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fan_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    device_id TEXT,
    ip_hash TEXT,
    action TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fraud_telemetry_fan ON public.fraud_telemetry (fan_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fraud_telemetry_device ON public.fraud_telemetry (device_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fraud_telemetry_ip ON public.fraud_telemetry (ip_hash, created_at DESC);

ALTER TABLE public.fraud_telemetry ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.fraud_telemetry FROM PUBLIC, anon, authenticated;

-- Purge function for 30-day telemetry retention
CREATE OR REPLACE FUNCTION public.purge_fraud_telemetry()
RETURNS VOID AS $$
BEGIN
    DELETE FROM public.fraud_telemetry WHERE created_at < NOW() - INTERVAL '30 days';
    DELETE FROM public.captcha_passes WHERE expires_at < NOW() - INTERVAL '1 day';
    DELETE FROM public.rate_limits WHERE window_start < NOW() - INTERVAL '1 day';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;


-- ==========================================
-- 5. COMPUTE RISK ENGINE
-- ==========================================
CREATE OR REPLACE FUNCTION public.compute_risk(p_fan_id UUID)
RETURNS VOID AS $$
DECLARE
    v_device_count INT;
    v_ip_count INT;
    v_daily_cap_hits INT;
BEGIN
    -- Check multiple accounts sharing same device_id
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

    -- Check multiple new accounts from same ip_hash in short window (24h)
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
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;


-- ==========================================
-- 6. RPC OVERRIDES WITH ANTI-FRAUD INTEGRATION
-- ==========================================

-- A. start_trivia_attempt Override (Requires rate limit & valid Turnstile captcha pass)
CREATE OR REPLACE FUNCTION public.start_trivia_attempt(
    p_trivia_id UUID,
    p_idempotency_key TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_fan_id UUID := auth.uid();
    v_trivia trivias%ROWTYPE;
    v_attempt_count INT;
    v_existing_attempt trivia_attempts%ROWTYPE;
    v_attempt_id UUID;
    v_expires_at TIMESTAMPTZ;
    v_seed INT;
    v_questions JSONB;
    v_pass_id UUID;
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    -- Rate limiting (Max 5 starts per 60s)
    PERFORM public.check_rate_limit(v_fan_id, 'start_trivia_attempt', 5, 60);

    -- Check and consume Turnstile Captcha Pass
    SELECT id INTO v_pass_id
    FROM public.captcha_passes
    WHERE user_id = v_fan_id AND used = false AND expires_at > NOW()
    ORDER BY created_at DESC
    LIMIT 1
    FOR UPDATE;

    IF v_pass_id IS NULL THEN
        RAISE EXCEPTION 'CAPTCHA_REQUIRED';
    END IF;

    -- Mark pass as used (Single Use)
    UPDATE public.captcha_passes SET used = true WHERE id = v_pass_id;

    -- Fetch trivia
    SELECT * INTO v_trivia FROM trivias WHERE id = p_trivia_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Trivia not found.';
    END IF;

    IF v_trivia.status != 'published' THEN
        RAISE EXCEPTION 'Trivia is not active for participation.';
    END IF;

    IF NOW() < v_trivia.starts_at OR NOW() > v_trivia.ends_at THEN
        RAISE EXCEPTION 'Trivia time window is closed.';
    END IF;

    -- Check Idempotency
    SELECT * INTO v_existing_attempt 
    FROM trivia_attempts 
    WHERE fan_id = v_fan_id AND trivia_id = p_trivia_id AND idempotency_key = p_idempotency_key;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'attempt_id', v_existing_attempt.id,
            'started_at', v_existing_attempt.started_at,
            'expires_at', v_existing_attempt.expires_at,
            'seed', v_existing_attempt.seed,
            'reused', true
        );
    END IF;

    -- Check Max Attempts
    SELECT COUNT(*) INTO v_attempt_count 
    FROM trivia_attempts 
    WHERE fan_id = v_fan_id AND trivia_id = p_trivia_id;

    IF v_attempt_count >= v_trivia.max_attempts THEN
        RAISE EXCEPTION 'Maximum participation attempts reached for this trivia.';
    END IF;

    -- Create Attempt
    v_expires_at := NOW() + (v_trivia.time_limit_seconds || ' seconds')::interval;
    v_seed := floor(random() * 1000000)::int;

    INSERT INTO trivia_attempts (
        fan_id, trivia_id, started_at, expires_at, seed, idempotency_key
    ) VALUES (
        v_fan_id, p_trivia_id, NOW(), v_expires_at, v_seed, p_idempotency_key
    )
    RETURNING id INTO v_attempt_id;

    -- Fetch questions (WITHOUT is_correct)
    SELECT jsonb_agg(
        jsonb_build_object(
            'question_id', q.id,
            'question_text', q.question_text,
            'points', q.points,
            'options', (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'option_id', o.id,
                        'option_text', o.option_text
                    )
                ) FROM trivia_options o WHERE o.question_id = q.id
            )
        )
    ) INTO v_questions
    FROM trivia_questions q
    WHERE q.trivia_id = p_trivia_id;

    RETURN jsonb_build_object(
        'attempt_id', v_attempt_id,
        'expires_at', v_expires_at,
        'seed', v_seed,
        'questions', COALESCE(v_questions, '[]'::jsonb),
        'reused', false
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- B. submit_trivia_attempt Override (Rate limited + Risk retention)
CREATE OR REPLACE FUNCTION public.submit_trivia_attempt(
    p_attempt_id UUID,
    p_answers JSONB,
    p_idempotency_key TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_fan_id UUID := auth.uid();
    v_attempt trivia_attempts%ROWTYPE;
    v_trivia trivias%ROWTYPE;
    v_time_spent_seconds NUMERIC;
    v_is_suspicious BOOLEAN := false;
    v_score INT := 0;
    v_total_pearls INT := 0;
    v_per_correct_pearls INT;
    v_q RECORD;
    v_chosen_option_id UUID;
    v_is_correct BOOLEAN;
    v_entry_status ledger_status := 'confirmed';
    v_unresolved_flags INT;
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    -- Rate limiting (Max 3 submits per 60s)
    PERFORM public.check_rate_limit(v_fan_id, 'submit_trivia_attempt', 3, 60);

    -- Lock attempt
    SELECT * INTO v_attempt FROM trivia_attempts WHERE id = p_attempt_id AND fan_id = v_fan_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Trivia attempt not found.';
    END IF;

    IF v_attempt.submitted_at IS NOT NULL THEN
        RETURN jsonb_build_object(
            'attempt_id', v_attempt.id,
            'score', v_attempt.score,
            'pearls_awarded', v_attempt.pearls_awarded,
            'suspicious', v_attempt.suspicious,
            'already_submitted', true
        );
    END IF;

    SELECT * INTO v_trivia FROM trivias WHERE id = v_attempt.trivia_id;

    -- Timing check
    v_time_spent_seconds := EXTRACT(EPOCH FROM (NOW() - v_attempt.started_at));

    -- Check if fan has unresolved risk flags or ban evasion
    SELECT COUNT(*) INTO v_unresolved_flags
    FROM public.risk_flags
    WHERE fan_id = v_fan_id AND resolved = false;

    IF v_time_spent_seconds < 3.0 OR v_unresolved_flags > 0 THEN
        v_is_suspicious := true;
        v_entry_status := 'held';

        IF v_time_spent_seconds < 3.0 THEN
            INSERT INTO public.risk_flags (fan_id, reason, severity)
            VALUES (v_fan_id, 'Implausible trivia completion speed (' || round(v_time_spent_seconds, 2) || 's)', 'high');
        END IF;
    END IF;

    v_per_correct_pearls := COALESCE((v_trivia.reward_rules->>'per_correct_pearls')::int, 50);

    -- Server-side grading
    FOR v_q IN SELECT q.id, q.points FROM trivia_questions q WHERE q.trivia_id = v_trivia.id LOOP
        v_chosen_option_id := (p_answers->>(v_q.id::text))::uuid;
        IF v_chosen_option_id IS NOT NULL THEN
            SELECT is_correct INTO v_is_correct 
            FROM trivia_options 
            WHERE id = v_chosen_option_id AND question_id = v_q.id;

            IF v_is_correct IS TRUE THEN
                v_score := v_score + v_q.points;
                v_total_pearls := v_total_pearls + v_per_correct_pearls;
            END IF;
        END IF;
    END LOOP;

    -- Atomic Ledger + Wallet update
    IF v_total_pearls > 0 THEN
        INSERT INTO ledger_entries (
            fan_id, amount, type, status, source_type, source_id, note
        ) VALUES (
            v_fan_id, v_total_pearls, 'trivia_reward', v_entry_status, 'trivia_attempt', v_attempt.id::text,
            'Premio por trivia: ' || v_trivia.title
        );

        IF v_entry_status = 'confirmed' THEN
            INSERT INTO wallets (fan_id, balance_cache)
            VALUES (v_fan_id, v_total_pearls)
            ON CONFLICT (fan_id) 
            DO UPDATE SET balance_cache = wallets.balance_cache + v_total_pearls, updated_at = NOW();
        END IF;
    END IF;

    UPDATE trivia_attempts
    SET submitted_at = NOW(),
        answers = p_answers,
        score = v_score,
        pearls_awarded = v_total_pearls,
        suspicious = v_is_suspicious
    WHERE id = v_attempt.id;

    RETURN jsonb_build_object(
        'attempt_id', v_attempt.id,
        'score', v_score,
        'pearls_awarded', v_total_pearls,
        'suspicious', v_is_suspicious,
        'status', v_entry_status,
        'already_submitted', false
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- C. redeem_product Override (Rate limited + Proportional Friction for high-value items)
CREATE OR REPLACE FUNCTION public.redeem_product(
    p_product_id UUID,
    p_variant TEXT,
    p_idempotency_key TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_fan_id UUID := auth.uid();
    v_product products%ROWTYPE;
    v_wallet wallets%ROWTYPE;
    v_profile profiles%ROWTYPE;
    v_existing_redemption redemptions%ROWTYPE;
    v_redemption_id UUID;
    v_code_hash TEXT;
    v_account_age_days INT;
    v_trivias_completed INT;
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    -- Rate limiting (Max 3 redemptions per 60s)
    PERFORM public.check_rate_limit(v_fan_id, 'redeem_product', 3, 60);

    -- Check Idempotency
    SELECT * INTO v_existing_redemption 
    FROM redemptions 
    WHERE fan_id = v_fan_id AND idempotency_key = p_idempotency_key;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'redemption_id', v_existing_redemption.id,
            'code_hash', v_existing_redemption.code_hash,
            'status', v_existing_redemption.status,
            'cost_pearls', v_existing_redemption.cost_pearls,
            'reused', true
        );
    END IF;

    -- Lock product FOR UPDATE
    SELECT * INTO v_product FROM products WHERE id = p_product_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product not found.';
    END IF;

    IF NOT v_product.active THEN
        RAISE EXCEPTION 'Product is not currently available.';
    END IF;

    IF v_product.stock <= 0 THEN
        RAISE EXCEPTION 'Product is out of stock.';
    END IF;

    -- Proportional Friction Check for High Value Products (>= 3000 pearls)
    IF v_product.cost_pearls >= 3000 THEN
        SELECT * INTO v_profile FROM profiles WHERE id = v_fan_id;
        v_account_age_days := EXTRACT(DAY FROM (NOW() - v_profile.created_at));

        SELECT COUNT(DISTINCT trivia_id) INTO v_trivias_completed
        FROM trivia_attempts
        WHERE fan_id = v_fan_id AND submitted_at IS NOT NULL;

        IF v_account_age_days < 7 OR v_trivias_completed < 3 THEN
            RAISE EXCEPTION 'ACCOUNT_TOO_NEW';
        END IF;
    END IF;

    -- Lock wallet FOR UPDATE
    SELECT * INTO v_wallet FROM wallets WHERE fan_id = v_fan_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Wallet not initialized or insufficient balance.';
    END IF;

    IF v_wallet.balance_cache < v_product.cost_pearls THEN
        RAISE EXCEPTION 'Insufficient perlitas balance. Required: %, Available: %', v_product.cost_pearls, v_wallet.balance_cache;
    END IF;

    v_code_hash := encode(extensions.gen_random_bytes(16), 'hex');

    -- Deduct Stock
    UPDATE products SET stock = stock - 1 WHERE id = p_product_id;

    -- Insert Negative Ledger Entry
    INSERT INTO ledger_entries (
        fan_id, amount, type, status, source_type, source_id, note
    ) VALUES (
        v_fan_id, -v_product.cost_pearls, 'redemption', 'confirmed', 'product', p_product_id::text,
        'Canje de premio: ' || v_product.name
    );

    -- Update Wallet Balance Cache
    UPDATE wallets 
    SET balance_cache = balance_cache - v_product.cost_pearls, updated_at = NOW() 
    WHERE fan_id = v_fan_id;

    -- Create Redemption Record
    INSERT INTO redemptions (
        fan_id, product_id, variant, cost_pearls, status, code_hash, idempotency_key, expires_at
    ) VALUES (
        v_fan_id, p_product_id, p_variant, v_product.cost_pearls, 'pending', v_code_hash, p_idempotency_key, NOW() + INTERVAL '30 days'
    )
    RETURNING id INTO v_redemption_id;

    -- History
    INSERT INTO redemption_history (redemption_id, previous_status, new_status, changed_by, note)
    VALUES (v_redemption_id, NULL, 'pending', v_fan_id, 'Canje iniciado por el fanático');

    RETURN jsonb_build_object(
        'redemption_id', v_redemption_id,
        'code_hash', v_code_hash,
        'status', 'pending',
        'cost_pearls', v_product.cost_pearls,
        'reused', false
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- D. delete_my_account Override (Blocked if suspended or unresolved risk flags)
CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS JSONB AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_status user_status;
    v_unresolved_flags INT;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT status INTO v_status FROM profiles WHERE id = v_uid;
    IF v_status = 'suspended' THEN
        RAISE EXCEPTION 'Cuentas suspendidas no pueden ser eliminadas directamente.';
    END IF;

    SELECT COUNT(*) INTO v_unresolved_flags FROM risk_flags WHERE fan_id = v_uid AND resolved = false;
    IF v_unresolved_flags > 0 THEN
        RAISE EXCEPTION 'Existen verificaciones pendientes en tu cuenta. Contáctate con soporte.';
    END IF;

    -- Soft delete / purge profile
    UPDATE profiles SET status = 'suspended', display_name = 'Fanático Eliminado', avatar_url = NULL WHERE id = v_uid;
    DELETE FROM wallets WHERE fan_id = v_uid;

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;


-- ==========================================
-- 7. ADMIN RISK MANAGEMENT FUNCTIONS
-- ==========================================

-- A. admin_risk_queue
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
                SELECT COALESCE(SUM(amount), 0) FROM ledger_entries WHERE fan_id = rf.fan_id AND status = 'held'
            )
        ) ORDER BY rf.created_at DESC
    ) INTO v_res
    FROM public.risk_flags rf
    JOIN public.profiles p ON p.id = rf.fan_id
    WHERE rf.resolved = p_resolved;

    RETURN COALESCE(v_res, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- B. admin_release_held_pearls (Converts held -> confirmed, updates wallet, requires note)
CREATE OR REPLACE FUNCTION public.admin_release_held_pearls(
    p_ledger_id UUID,
    p_note TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_entry ledger_entries%ROWTYPE;
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

    -- Update ledger status held -> confirmed
    UPDATE public.ledger_entries
    SET status = 'confirmed',
        note = COALESCE(note, '') || ' | Liberado por admin: ' || p_note
    WHERE id = p_ledger_id;

    -- Update Wallet
    INSERT INTO public.wallets (fan_id, balance_cache)
    VALUES (v_entry.fan_id, v_entry.amount)
    ON CONFLICT (fan_id)
    DO UPDATE SET balance_cache = wallets.balance_cache + v_entry.amount, updated_at = NOW();

    -- Audit Log
    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'release_held_pearls', 'ledger_entries', p_ledger_id::text,
        jsonb_build_object('fan_id', v_entry.fan_id, 'amount', v_entry.amount, 'note', p_note)
    );

    RETURN jsonb_build_object('status', 'released', 'ledger_id', p_ledger_id, 'amount', v_entry.amount);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- C. admin_revoke_held_pearls (Converts held -> revoked, requires note)
CREATE OR REPLACE FUNCTION public.admin_revoke_held_pearls(
    p_ledger_id UUID,
    p_note TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_entry ledger_entries%ROWTYPE;
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

    -- Update ledger status held -> revoked
    UPDATE public.ledger_entries
    SET status = 'revoked',
        note = COALESCE(note, '') || ' | Revocado por admin: ' || p_note
    WHERE id = p_ledger_id;

    -- Audit Log
    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'revoke_held_pearls', 'ledger_entries', p_ledger_id::text,
        jsonb_build_object('fan_id', v_entry.fan_id, 'amount', v_entry.amount, 'note', p_note)
    );

    RETURN jsonb_build_object('status', 'revoked', 'ledger_id', p_ledger_id, 'amount', v_entry.amount);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- D. admin_resolve_risk_flag
CREATE OR REPLACE FUNCTION public.admin_resolve_risk_flag(
    p_flag_id UUID,
    p_note TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID := auth.uid();
BEGIN
    PERFORM public.assert_admin();

    IF p_note IS NULL OR trim(p_note) = '' THEN
        RAISE EXCEPTION 'La justificación es obligatoria para resolver una alerta de riesgo.';
    END IF;

    UPDATE public.risk_flags
    SET resolved = true
    WHERE id = p_flag_id;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'resolve_risk_flag', 'risk_flags', p_flag_id::text,
        jsonb_build_object('note', p_note)
    );

    RETURN jsonb_build_object('status', 'resolved', 'flag_id', p_flag_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;


-- ==========================================
-- 8. PERMISSIONS & GRANTS
-- ==========================================
REVOKE ALL ON FUNCTION public.start_trivia_attempt(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_trivia_attempt(UUID, TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.submit_trivia_attempt(UUID, JSONB, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_trivia_attempt(UUID, JSONB, TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.redeem_product(UUID, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.redeem_product(UUID, TEXT, TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_risk_queue(BOOLEAN) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_risk_queue(BOOLEAN) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_release_held_pearls(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_release_held_pearls(UUID, TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_revoke_held_pearls(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_revoke_held_pearls(UUID, TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_resolve_risk_flag(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_resolve_risk_flag(UUID, TEXT) TO authenticated, service_role;
