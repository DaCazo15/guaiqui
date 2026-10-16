-- Migration: 20261011000041_improve_trivia_time_window_errors.sql
-- Description: Differentiate TRIVIA_NOT_STARTED vs TRIVIA_EXPIRED in start_trivia_attempt
--              to provide accurate error messaging when a trivia is scheduled in the future.

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

    -- Differentiate before start vs after end
    IF NOW() < v_trivia.starts_at THEN
        RAISE EXCEPTION 'TRIVIA_NOT_STARTED';
    END IF;

    IF NOW() > v_trivia.ends_at THEN
        RAISE EXCEPTION 'TRIVIA_EXPIRED';
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

REVOKE ALL ON FUNCTION public.start_trivia_attempt(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_trivia_attempt(UUID, TEXT) TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';
