-- Migration: 20261012000044_fix_trivias_segments_and_streak_caracas.sql
-- Description: Fix target_segment_id in admin/staff upsert and duplicate trivias,
--              align calculate_and_apply_streak_bonus with America/Caracas timezone,
--              and protect start_trivia_attempt with won trivia check and hung attempt recovery.

-- 1. admin_upsert_trivia with robust target_segment_id handling
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
    v_q_elem JSONB;
    v_opt_elem JSONB;
    v_q_id UUID;
BEGIN
    PERFORM public.assert_admin();

    v_trivia_id := (p_trivia->>'id')::UUID;

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
            NULLIF(p_trivia->>'target_segment_id', '')::UUID
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
            target_segment_id = CASE
                WHEN p_trivia ? 'target_segment_id' THEN NULLIF(p_trivia->>'target_segment_id', '')::UUID
                ELSE target_segment_id
            END
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


-- 2. staff_upsert_trivia with robust target_segment_id handling
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
    v_q_elem JSONB;
    v_opt_elem JSONB;
    v_q_id UUID;
BEGIN
    PERFORM public.assert_staff();

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

    IF v_is_new THEN
        INSERT INTO public.trivias (
            id, title, description, status, starts_at, ends_at, time_limit_seconds, reward_rules, max_attempts, target_segment_id
        ) VALUES (
            v_trivia_id,
            p_trivia->>'title',
            p_trivia->>'description',
            COALESCE((p_trivia->>'status')::trivia_status, 'draft'::trivia_status),
            (p_trivia->>'starts_at')::TIMESTAMPTZ,
            (p_trivia->>'ends_at')::TIMESTAMPTZ,
            COALESCE((p_trivia->>'time_limit_seconds')::INT, 60),
            COALESCE(p_trivia->'reward_rules', '{"per_correct_pearls": 50, "perfect_score_bonus": 100}'::jsonb),
            COALESCE((p_trivia->>'max_attempts')::INT, 1),
            NULLIF(p_trivia->>'target_segment_id', '')::UUID
        );
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
            target_segment_id = CASE
                WHEN p_trivia ? 'target_segment_id' THEN NULLIF(p_trivia->>'target_segment_id', '')::UUID
                ELSE target_segment_id
            END
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
        v_staff_id, 'staff_upsert_trivia', 'trivias', v_trivia_id::text,
        p_trivia
    );

    RETURN jsonb_build_object('success', true, 'id', v_trivia_id, 'is_new', v_is_new);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.staff_upsert_trivia(JSONB, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.staff_upsert_trivia(JSONB, JSONB) TO authenticated, service_role;


-- 3. admin_duplicate_trivia preserving target_segment_id
CREATE OR REPLACE FUNCTION public.admin_duplicate_trivia(
    p_trivia_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_orig public.trivias%ROWTYPE;
    v_new_id UUID;
    v_q RECORD;
    v_new_q_id UUID;
BEGIN
    PERFORM public.assert_admin();

    SELECT * INTO v_orig FROM public.trivias WHERE id = p_trivia_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Trivia original no encontrada.';
    END IF;

    INSERT INTO public.trivias (
        title, description, status, starts_at, ends_at, time_limit_seconds, reward_rules, max_attempts, target_segment_id
    ) VALUES (
        v_orig.title || ' (Copia)',
        v_orig.description,
        'draft',
        v_orig.starts_at,
        v_orig.ends_at,
        v_orig.time_limit_seconds,
        v_orig.reward_rules,
        v_orig.max_attempts,
        v_orig.target_segment_id
    ) RETURNING id INTO v_new_id;

    FOR v_q IN SELECT * FROM public.trivia_questions WHERE trivia_id = p_trivia_id
    LOOP
        INSERT INTO public.trivia_questions (
            trivia_id, question_text, points, order_index
        ) VALUES (
            v_new_id, v_q.question_text, v_q.points, v_q.order_index
        ) RETURNING id INTO v_new_q_id;

        INSERT INTO public.trivia_options (question_id, option_text, is_correct)
        SELECT v_new_q_id, option_text, is_correct
        FROM public.trivia_options
        WHERE question_id = v_q.id;
    END LOOP;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        v_admin_id, 'duplicate_trivia', 'trivias', v_new_id::text,
        jsonb_build_object('source_id', p_trivia_id),
        jsonb_build_object('new_id', v_new_id)
    );

    RETURN jsonb_build_object('id', v_new_id, 'status', 'draft');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.admin_duplicate_trivia(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_duplicate_trivia(UUID) TO authenticated, service_role;


-- 4. calculate_and_apply_streak_bonus (Timezone Caracas: America/Caracas)
CREATE OR REPLACE FUNCTION public.calculate_and_apply_streak_bonus(p_fan_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_today DATE := (NOW() AT TIME ZONE 'America/Caracas')::date;
    v_already_awarded BOOLEAN;
    v_streak_days INT := 0;
    v_day_check DATE;
    v_bonus_amount INT := 0;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM ledger_entries
        WHERE fan_id = p_fan_id
          AND type = 'streak_bonus'
          AND (created_at AT TIME ZONE 'America/Caracas')::date = v_today
    ) INTO v_already_awarded;

    -- Calculate consecutive days up to today in Caracas timezone
    v_day_check := v_today;
    LOOP
        IF EXISTS (
            SELECT 1 FROM trivia_attempts
            WHERE fan_id = p_fan_id
              AND submitted_at IS NOT NULL
              AND (submitted_at AT TIME ZONE 'America/Caracas')::date = v_day_check
        ) THEN
            v_streak_days := v_streak_days + 1;
            v_day_check := v_day_check - INTERVAL '1 day';
        ELSE
            EXIT;
        END IF;
    END LOOP;

    IF v_already_awarded THEN
        RETURN jsonb_build_object('streak_days', v_streak_days, 'bonus_awarded', 0, 'already_awarded_today', true);
    END IF;

    -- Award milestone bonus
    IF v_streak_days >= 7 THEN
        v_bonus_amount := 300;
    ELSIF v_streak_days >= 3 THEN
        v_bonus_amount := 100;
    ELSIF v_streak_days >= 1 THEN
        v_bonus_amount := 20;
    END IF;

    IF v_bonus_amount > 0 THEN
        INSERT INTO ledger_entries (
            fan_id, amount, type, status, source_type, source_id, note
        ) VALUES (
            p_fan_id, v_bonus_amount, 'streak_bonus', 'confirmed', 'streak', v_today::text || '-' || v_streak_days,
            'Bono de racha diaria (' || v_streak_days || ' días consecutivos)'
        ) ON CONFLICT DO NOTHING;

        INSERT INTO wallets (fan_id, balance_cache)
        VALUES (p_fan_id, v_bonus_amount)
        ON CONFLICT (fan_id)
        DO UPDATE SET balance_cache = wallets.balance_cache + v_bonus_amount, updated_at = NOW();
    END IF;

    RETURN jsonb_build_object(
        'streak_days', v_streak_days,
        'bonus_awarded', v_bonus_amount,
        'already_awarded_today', false
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.calculate_and_apply_streak_bonus(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.calculate_and_apply_streak_bonus(UUID) TO authenticated, service_role;


-- 5. start_trivia_attempt with won trivia check and hung attempt handling
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

    -- Verify if the fan has already won this trivia (score > 0 or pearls_awarded > 0)
    IF EXISTS (
        SELECT 1 FROM trivia_attempts
        WHERE fan_id = v_fan_id
          AND trivia_id = p_trivia_id
          AND submitted_at IS NOT NULL
          AND (score > 0 OR pearls_awarded > 0)
    ) THEN
        RAISE EXCEPTION 'TRIVIA_ALREADY_WON';
    END IF;

    -- Check Idempotency (Existing attempt by same idempotency_key)
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

    -- Check Max Attempts (only count submitted attempts or active non-expired attempts;
    -- ignore hung attempts that expired without submission)
    SELECT COUNT(*) INTO v_attempt_count 
    FROM trivia_attempts 
    WHERE fan_id = v_fan_id 
      AND trivia_id = p_trivia_id
      AND (submitted_at IS NOT NULL OR NOW() <= expires_at);

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

NOTIFY pgrst, 'reload schema';
