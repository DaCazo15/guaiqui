-- Migration: 20261012000046_unlimited_attempts_until_won.sql
-- Description: Allow unlimited retries until the fan wins (100% correct answers).

-- 1. Update start_trivia_attempt: eliminate max_attempts check; only block if already won (pearls_awarded > 0)
CREATE OR REPLACE FUNCTION public.start_trivia_attempt(
    p_trivia_id UUID,
    p_idempotency_key TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_fan_id UUID := auth.uid();
    v_trivia trivias%ROWTYPE;
    v_existing_attempt trivia_attempts%ROWTYPE;
    v_attempt_id UUID;
    v_expires_at TIMESTAMPTZ;
    v_seed INT;
    v_questions JSONB;
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    PERFORM public.assert_active_verified_fan(v_fan_id);

    -- Rate limiting (Max 5 attempts created per 60s)
    PERFORM public.check_rate_limit(v_fan_id, 'start_trivia_attempt', 5, 60);

    -- Fetch trivia
    SELECT * INTO v_trivia FROM trivias WHERE id = p_trivia_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Trivia not found.';
    END IF;

    IF v_trivia.status != 'published' THEN
        RAISE EXCEPTION 'Trivia is not active for participation.';
    END IF;

    -- Time Window Check
    IF NOW() < v_trivia.starts_at THEN
        RAISE EXCEPTION 'TRIVIA_NOT_STARTED';
    END IF;

    IF NOW() > v_trivia.ends_at THEN
        RAISE EXCEPTION 'TRIVIA_EXPIRED';
    END IF;

    -- Verify if the fan has already won this trivia (pearls_awarded > 0)
    IF EXISTS (
        SELECT 1 FROM trivia_attempts
        WHERE fan_id = v_fan_id
          AND trivia_id = p_trivia_id
          AND submitted_at IS NOT NULL
          AND pearls_awarded > 0
    ) THEN
        RAISE EXCEPTION 'TRIVIA_ALREADY_WON';
    END IF;

    -- Check Idempotency (Existing active attempt with same idempotency_key)
    SELECT * INTO v_existing_attempt 
    FROM trivia_attempts 
    WHERE fan_id = v_fan_id AND trivia_id = p_trivia_id AND idempotency_key = p_idempotency_key;

    IF FOUND THEN
        IF v_existing_attempt.submitted_at IS NOT NULL THEN
            RAISE EXCEPTION 'TRIVIA_ALREADY_PLAYED';
        END IF;

        IF NOW() > v_existing_attempt.expires_at THEN
            RAISE EXCEPTION 'ATTEMPT_EXPIRED';
        END IF;

        -- Return questions for existing attempt
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
            ) ORDER BY hashtext(q.id::text || v_existing_attempt.seed::text)
        ) INTO v_questions
        FROM trivia_questions q
        WHERE q.trivia_id = p_trivia_id;

        RETURN jsonb_build_object(
            'attempt_id', v_existing_attempt.id,
            'expires_at', v_existing_attempt.expires_at,
            'seed', v_existing_attempt.seed,
            'questions', COALESCE(v_questions, '[]'::jsonb),
            'reused', true
        );
    END IF;

    -- Create Attempt (expires at trivia ends_at, no artificial attempt countdown)
    v_expires_at := v_trivia.ends_at;
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
        ) ORDER BY hashtext(q.id::text || v_seed::text)
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


-- 2. Update submit_trivia_attempt: Only award pearls when trivia is won (all questions answered correctly)
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
    v_raw_pearls INT := 0;
    v_final_pearls INT := 0;
    v_per_correct_pearls INT;
    v_perfect_bonus INT := 0;
    v_total_questions INT := 0;
    v_correct_count INT := 0;
    v_is_won BOOLEAN := false;
    v_q RECORD;
    v_chosen_option_id UUID;
    v_is_correct BOOLEAN;
    v_entry_status ledger_status := 'confirmed';
    v_unresolved_flags INT;

    -- Economy caps
    v_daily_cap INT := 1000;
    v_weekly_cap INT := 5000;
    v_today_caracas DATE := (NOW() AT TIME ZONE 'America/Caracas')::date;
    v_week_start_caracas TIMESTAMPTZ := date_trunc('week', NOW() AT TIME ZONE 'America/Caracas');
    v_today_earned INT := 0;
    v_week_earned INT := 0;
    v_rem_daily INT := 0;
    v_rem_weekly INT := 0;
    v_effective_cap INT := 0;
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    -- Rate limiting (Max 3 submits per 60s)
    PERFORM public.check_rate_limit(v_fan_id, 'submit_trivia_attempt', 3, 60);

    -- Lock attempt FOR UPDATE
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
            'is_won', (v_attempt.pearls_awarded > 0),
            'already_submitted', true
        );
    END IF;

    SELECT * INTO v_trivia FROM trivias WHERE id = v_attempt.trivia_id;

    -- Timing check
    v_time_spent_seconds := EXTRACT(EPOCH FROM (NOW() - v_attempt.started_at));

    -- Check if fan has unresolved risk flags
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
    v_perfect_bonus := COALESCE((v_trivia.reward_rules->>'perfect_score_bonus')::int, 100);

    -- Server-side grading
    FOR v_q IN SELECT q.id, q.points FROM trivia_questions q WHERE q.trivia_id = v_trivia.id LOOP
        v_total_questions := v_total_questions + 1;
        v_chosen_option_id := (p_answers->>(v_q.id::text))::uuid;
        IF v_chosen_option_id IS NOT NULL THEN
            SELECT is_correct INTO v_is_correct 
            FROM trivia_options 
            WHERE id = v_chosen_option_id AND question_id = v_q.id;

            IF v_is_correct IS TRUE THEN
                v_correct_count := v_correct_count + 1;
                v_score := v_score + v_q.points;
                v_raw_pearls := v_raw_pearls + v_per_correct_pearls;
            END IF;
        END IF;
    END LOOP;

    -- Option A: Trivia is won ONLY if all questions are answered correctly
    v_is_won := (v_total_questions > 0 AND v_correct_count = v_total_questions);

    IF v_is_won THEN
        -- Add perfect score bonus if applicable
        v_raw_pearls := v_raw_pearls + v_perfect_bonus;

        -- Read economy caps
        SELECT daily_pearl_cap, weekly_pearl_cap 
        INTO v_daily_cap, v_weekly_cap
        FROM public.economy_settings
        ORDER BY created_at DESC LIMIT 1;

        v_daily_cap := COALESCE(v_daily_cap, 1000);
        v_weekly_cap := COALESCE(v_weekly_cap, 5000);

        -- Calculate current earnings in Caracas timezone
        SELECT COALESCE(SUM(amount), 0) INTO v_today_earned
        FROM ledger_entries
        WHERE fan_id = v_fan_id
          AND amount > 0
          AND status IN ('confirmed', 'held')
          AND (created_at AT TIME ZONE 'America/Caracas')::date = v_today_caracas;

        SELECT COALESCE(SUM(amount), 0) INTO v_week_earned
        FROM ledger_entries
        WHERE fan_id = v_fan_id
          AND amount > 0
          AND status IN ('confirmed', 'held')
          AND (created_at AT TIME ZONE 'America/Caracas') >= v_week_start_caracas;

        v_rem_daily := GREATEST(0, v_daily_cap - v_today_earned);
        v_rem_weekly := GREATEST(0, v_weekly_cap - v_week_earned);
        v_effective_cap := LEAST(v_rem_daily, v_rem_weekly);

        -- Cap pearls awarded
        v_final_pearls := LEAST(v_raw_pearls, v_effective_cap);

        -- Atomic Ledger + Wallet update
        IF v_final_pearls > 0 THEN
            INSERT INTO ledger_entries (
                fan_id, amount, type, status, source_type, source_id, note
            ) VALUES (
                v_fan_id, v_final_pearls, 'trivia_reward', v_entry_status, 'trivia_attempt', v_attempt.id::text,
                'Premio por ganar trivia: ' || v_trivia.title
            );

            IF v_entry_status = 'confirmed' THEN
                INSERT INTO wallets (fan_id, balance_cache)
                VALUES (v_fan_id, v_final_pearls)
                ON CONFLICT (fan_id) 
                DO UPDATE SET balance_cache = wallets.balance_cache + v_final_pearls, updated_at = NOW();
            END IF;
        END IF;

        -- Update streak bonus if confirmed
        IF v_entry_status = 'confirmed' THEN
            PERFORM public.calculate_and_apply_streak_bonus(v_fan_id);
        END IF;
    ELSE
        -- If not won, pearls awarded is 0 so the fan can retry until won
        v_final_pearls := 0;
    END IF;

    UPDATE trivia_attempts
    SET submitted_at = NOW(),
        answers = p_answers,
        score = v_score,
        pearls_awarded = v_final_pearls,
        suspicious = v_is_suspicious
    WHERE id = v_attempt.id;

    RETURN jsonb_build_object(
        'attempt_id', v_attempt.id,
        'score', v_score,
        'pearls_awarded', v_final_pearls,
        'raw_pearls', v_raw_pearls,
        'correct_count', v_correct_count,
        'total_questions', v_total_questions,
        'is_won', v_is_won,
        'suspicious', v_is_suspicious,
        'status', v_entry_status,
        'already_submitted', false
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.submit_trivia_attempt(UUID, JSONB, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_trivia_attempt(UUID, JSONB, TEXT) TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';
