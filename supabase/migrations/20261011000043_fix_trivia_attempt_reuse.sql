-- Migration: 20261011000043_fix_trivia_attempt_reuse.sql
-- Description: 1. Validate reused attempt status (TRIVIA_ALREADY_PLAYED, ATTEMPT_EXPIRED) and return questions on attempt reuse.
--              2. Apply deterministic seed hashing order on questions.
--              3. Support p_questions and target_segment_id in staff_upsert_trivia and admin_upsert_trivia.

-- 1. start_trivia_attempt with robust reuse handling and seed ordering
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

    -- Check Idempotency (Existing attempt)
    SELECT * INTO v_existing_attempt 
    FROM trivia_attempts 
    WHERE fan_id = v_fan_id AND trivia_id = p_trivia_id AND idempotency_key = p_idempotency_key;

    IF FOUND THEN
        -- Check if already submitted
        IF v_existing_attempt.submitted_at IS NOT NULL THEN
            RAISE EXCEPTION 'TRIVIA_ALREADY_PLAYED';
        END IF;

        -- Check if attempt has expired
        IF NOW() > v_existing_attempt.expires_at THEN
            RAISE EXCEPTION 'ATTEMPT_EXPIRED';
        END IF;

        -- Fetch questions securely (WITHOUT is_correct) ordered by existing attempt seed
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

    -- Fetch questions (WITHOUT is_correct) ordered by new attempt seed
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


-- 2. staff_upsert_trivia with questions support and target_segment_id
CREATE OR REPLACE FUNCTION public.staff_upsert_trivia(
    p_trivia JSONB,
    p_questions JSONB DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_staff_id UUID := auth.uid();
    v_trivia_id UUID;
    v_is_new BOOLEAN := false;
    v_attempt_count INT := 0;
    v_target_segment UUID;
    v_q_elem JSONB;
    v_opt_elem JSONB;
    v_q_id UUID;
BEGIN
    PERFORM public.assert_staff();

    IF p_trivia->>'target_segment_id' IS NOT NULL AND (p_trivia->>'target_segment_id') != '' THEN
        v_target_segment := (p_trivia->>'target_segment_id')::uuid;
    ELSE
        v_target_segment := NULL;
    END IF;

    IF p_trivia->>'id' IS NOT NULL AND (p_trivia->>'id') != '' THEN
        v_trivia_id := (p_trivia->>'id')::uuid;
        SELECT COUNT(*) INTO v_attempt_count FROM public.trivia_attempts WHERE trivia_id = v_trivia_id;

        IF v_attempt_count > 0 AND p_questions IS NOT NULL THEN
            RAISE EXCEPTION 'No se pueden modificar preguntas u opciones de una trivia con intentos registrados. Duplique o archive la trivia.';
        END IF;
    ELSE
        v_trivia_id := gen_random_uuid();
        v_is_new := true;
    END IF;

    INSERT INTO public.trivias (
        id, title, description, starts_at, ends_at, status, max_attempts, time_limit_seconds, reward_rules, target_segment_id
    ) VALUES (
        v_trivia_id,
        p_trivia->>'title',
        p_trivia->>'description',
        (p_trivia->>'starts_at')::timestamptz,
        (p_trivia->>'ends_at')::timestamptz,
        COALESCE((p_trivia->>'status')::trivia_status, 'draft'::trivia_status),
        COALESCE((p_trivia->>'max_attempts')::int, 1),
        COALESCE((p_trivia->>'time_limit_seconds')::int, 60),
        COALESCE(p_trivia->'reward_rules', '{"per_correct_pearls": 50, "perfect_score_bonus": 100}'::jsonb),
        v_target_segment
    )
    ON CONFLICT (id) DO UPDATE SET
        title = EXCLUDED.title,
        description = EXCLUDED.description,
        starts_at = EXCLUDED.starts_at,
        ends_at = EXCLUDED.ends_at,
        status = EXCLUDED.status,
        max_attempts = EXCLUDED.max_attempts,
        time_limit_seconds = EXCLUDED.time_limit_seconds,
        reward_rules = EXCLUDED.reward_rules,
        target_segment_id = EXCLUDED.target_segment_id;

    -- Upsert Questions & Options if allowed and provided
    IF p_questions IS NOT NULL AND v_attempt_count = 0 THEN
        DELETE FROM public.trivia_questions WHERE trivia_id = v_trivia_id;

        FOR v_q_elem IN SELECT * FROM jsonb_array_elements(p_questions)
        LOOP
            INSERT INTO public.trivia_questions (
                trivia_id, question_text, points, order_index
            ) VALUES (
                v_trivia_id,
                v_q_elem->>'question_text',
                COALESCE((v_q_elem->>'points')::int, 50),
                COALESCE((v_q_elem->>'order_index')::int, 0)
            ) RETURNING id INTO v_q_id;

            IF v_q_elem->'options' IS NOT NULL THEN
                FOR v_opt_elem IN SELECT * FROM jsonb_array_elements(v_q_elem->'options')
                LOOP
                    INSERT INTO public.trivia_options (
                        question_id, option_text, is_correct
                    ) VALUES (
                        v_q_id,
                        v_opt_elem->>'option_text',
                        COALESCE((v_opt_elem->>'is_correct')::boolean, false)
                    );
                END LOOP;
            END IF;
        END LOOP;
    END IF;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_staff_id, 'staff_upsert_trivia', 'trivias', v_trivia_id::text,
        p_trivia
    );

    RETURN jsonb_build_object('success', true, 'id', v_trivia_id, 'is_new', v_is_new);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.staff_upsert_trivia(JSONB, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.staff_upsert_trivia(JSONB, JSONB) TO authenticated, service_role;


-- 3. Update admin_upsert_trivia to persist target_segment_id
CREATE OR REPLACE FUNCTION public.admin_upsert_trivia(
    p_trivia JSONB,
    p_questions JSONB DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_trivia_id UUID;
    v_existing_status trivia_status;
    v_attempt_count INT := 0;
    v_target_segment UUID;
    v_q_elem JSONB;
    v_opt_elem JSONB;
    v_q_id UUID;
BEGIN
    PERFORM public.assert_admin();

    v_trivia_id := (p_trivia->>'id')::UUID;

    IF p_trivia->>'target_segment_id' IS NOT NULL AND (p_trivia->>'target_segment_id') != '' THEN
        v_target_segment := (p_trivia->>'target_segment_id')::uuid;
    ELSE
        v_target_segment := NULL;
    END IF;

    IF v_trivia_id IS NOT NULL THEN
        SELECT status INTO v_existing_status FROM public.trivias WHERE id = v_trivia_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Trivia no encontrada.';
        END IF;

        SELECT COUNT(*) INTO v_attempt_count FROM public.trivia_attempts WHERE trivia_id = v_trivia_id;

        IF v_attempt_count > 0 AND p_questions IS NOT NULL THEN
            RAISE EXCEPTION 'No se pueden modificar preguntas u opciones de una trivia con intentos registrados. Duplique o archive la trivia.';
        END IF;
    END IF;

    IF v_trivia_id IS NULL THEN
        INSERT INTO public.trivias (
            title, description, status, starts_at, ends_at, time_limit_seconds, reward_rules, max_attempts, target_segment_id
        ) VALUES (
            p_trivia->>'title',
            p_trivia->>'description',
            COALESCE((p_trivia->>'status')::trivia_status, 'draft'::trivia_status),
            (p_trivia->>'starts_at')::TIMESTAMPTZ,
            (p_trivia->>'ends_at')::TIMESTAMPTZ,
            COALESCE((p_trivia->>'time_limit_seconds')::INT, 60),
            COALESCE(p_trivia->'reward_rules', '{"per_correct_pearls": 50, "perfect_score_bonus": 100}'::jsonb),
            COALESCE((p_trivia->>'max_attempts')::INT, 1),
            v_target_segment
        ) RETURNING id INTO v_trivia_id;
    ELSE
        UPDATE public.trivias SET
            title = COALESCE(p_trivia->>'title', title),
            description = COALESCE(p_trivia->>'description', description),
            status = COALESCE((p_trivia->>'status')::trivia_status, status),
            starts_at = COALESCE((p_trivia->>'starts_at')::TIMESTAMPTZ, starts_at),
            ends_at = COALESCE((p_trivia->>'ends_at')::TIMESTAMPTZ, ends_at),
            time_limit_seconds = COALESCE((p_trivia->>'time_limit_seconds')::INT, time_limit_seconds),
            reward_rules = COALESCE(p_trivia->'reward_rules', reward_rules),
            max_attempts = COALESCE((p_trivia->>'max_attempts')::INT, max_attempts),
            target_segment_id = v_target_segment
        WHERE id = v_trivia_id;
    END IF;

    -- Upsert Questions & Options if allowed and provided
    IF p_questions IS NOT NULL AND v_attempt_count = 0 THEN
        DELETE FROM public.trivia_questions WHERE trivia_id = v_trivia_id;

        FOR v_q_elem IN SELECT * FROM jsonb_array_elements(p_questions)
        LOOP
            INSERT INTO public.trivia_questions (
                trivia_id, question_text, points, order_index
            ) VALUES (
                v_trivia_id,
                v_q_elem->>'question_text',
                COALESCE((v_q_elem->>'points')::INT, 50),
                COALESCE((v_q_elem->>'order_index')::INT, 0)
            ) RETURNING id INTO v_q_id;

            IF v_q_elem->'options' IS NOT NULL THEN
                FOR v_opt_elem IN SELECT * FROM jsonb_array_elements(v_q_elem->'options')
                LOOP
                    INSERT INTO public.trivia_options (
                        question_id, option_text, is_correct
                    ) VALUES (
                        v_q_id,
                        v_opt_elem->>'option_text',
                        COALESCE((v_opt_elem->>'is_correct')::BOOLEAN, false)
                    );
                END LOOP;
            END IF;
        END LOOP;
    END IF;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'admin_upsert_trivia', 'trivias', v_trivia_id::text,
        p_trivia
    );

    RETURN jsonb_build_object('success', true, 'id', v_trivia_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.admin_upsert_trivia(JSONB, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_upsert_trivia(JSONB, JSONB) TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';
