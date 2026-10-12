-- =============================================================
-- TEST SUITE: Trivia Attempt Reuse, Expiration & Security
-- =============================================================

BEGIN;
SELECT plan(4);

-- Setup: Datos de prueba autocontenidos
DO $$
DECLARE
    v_fan UUID := 'f2800000-0000-0000-0000-000000000001';
    v_trivia UUID := 't2800000-0000-0000-0000-000000000001';
    v_q UUID := 'q2800000-0000-0000-0000-000000000001';
    v_opt1 UUID := 'o2800000-0000-0000-0000-000000000001';
    v_opt2 UUID := 'o2800000-0000-0000-0000-000000000002';
BEGIN
    INSERT INTO auth.users (id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token)
    VALUES
        (v_fan, 'authenticated', 'authenticated', 'fan_reuse_test@test.com', crypt('Test123!', gen_salt('bf')), '{"provider":"email"}'::jsonb, '{}'::jsonb, NOW(), NOW(), '')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO profiles (id, display_name, status) VALUES
        (v_fan, 'Fan Reuse Test', 'active')
    ON CONFLICT (id) DO UPDATE SET display_name = EXCLUDED.display_name;

    INSERT INTO trivias (id, title, description, status, starts_at, ends_at, time_limit_seconds, max_attempts)
    VALUES (v_trivia, 'Trivia Reuse Suite', 'Test trivia', 'published', NOW() - interval '1 hour', NOW() + interval '1 day', 60, 5)
    ON CONFLICT (id) DO UPDATE SET status = 'published', starts_at = NOW() - interval '1 hour', ends_at = NOW() + interval '1 day';

    INSERT INTO trivia_questions (id, trivia_id, question_text, points, order_index)
    VALUES (v_q, v_trivia, '¿Pregunta de prueba?', 50, 0)
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO trivia_options (id, question_id, option_text, is_correct)
    VALUES 
        (v_opt1, v_q, 'Respuesta Correcta Secreta', true),
        (v_opt2, v_q, 'Respuesta Incorrecta', false)
    ON CONFLICT (id) DO NOTHING;
END $$;


-- TEST 1: Reintento con intento vigente devuelve preguntas sin is_correct
DO $$
DECLARE
    v_fan UUID := 'f2800000-0000-0000-0000-000000000001';
    v_trivia UUID := 't2800000-0000-0000-0000-000000000001';
    v_res JSONB;
BEGIN
    -- Crear captcha pass vigente
    INSERT INTO captcha_passes (user_id, ip_hash, used, expires_at)
    VALUES (v_fan, 'hash_test_1', false, NOW() + interval '10 minutes');

    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "f2800000-0000-0000-0000-000000000001", "role": "authenticated"}';

    -- Primer intento
    PERFORM public.start_trivia_attempt(v_trivia, 'idemp-reuse-test-01');

    -- Reintento con misma clave de idempotencia
    INSERT INTO captcha_passes (user_id, ip_hash, used, expires_at)
    VALUES (v_fan, 'hash_test_2', false, NOW() + interval '10 minutes');

    v_res := public.start_trivia_attempt(v_trivia, 'idemp-reuse-test-01');

    IF (v_res->>'reused')::boolean = true AND jsonb_array_length(v_res->'questions') > 0 THEN
        -- OK
    ELSE
        RAISE EXCEPTION 'start_trivia_attempt falló en reutilizar intento vigente: %', v_res;
    END IF;
END $$;

SELECT pass('TEST 1: Reintento con intento vigente devuelve preguntas con reused=true');


-- TEST 2: Reintento con intento vencido lanza ATTEMPT_EXPIRED
DO $$
DECLARE
    v_fan UUID := 'f2800000-0000-0000-0000-000000000001';
    v_trivia UUID := 't2800000-0000-0000-0000-000000000001';
    v_err TEXT;
BEGIN
    -- Forzar expiración del intento creado
    UPDATE trivia_attempts 
    SET expires_at = NOW() - interval '10 seconds'
    WHERE fan_id = v_fan AND trivia_id = v_trivia AND idempotency_key = 'idemp-reuse-test-01';

    INSERT INTO captcha_passes (user_id, ip_hash, used, expires_at)
    VALUES (v_fan, 'hash_test_3', false, NOW() + interval '10 minutes');

    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "f2800000-0000-0000-0000-000000000001", "role": "authenticated"}';

    BEGIN
        PERFORM public.start_trivia_attempt(v_trivia, 'idemp-reuse-test-01');
        RAISE EXCEPTION 'Debió fallar con ATTEMPT_EXPIRED';
    EXCEPTION WHEN OTHERS THEN
        v_err := SQLERRM;
        IF v_err NOT LIKE '%ATTEMPT_EXPIRED%' THEN
            RAISE EXCEPTION 'Mensaje inesperado: %', v_err;
        END IF;
    END;
END $$;

SELECT pass('TEST 2: Reintento con intento vencido lanza ATTEMPT_EXPIRED');


-- TEST 3: Reintento con intento ya enviado lanza TRIVIA_ALREADY_PLAYED
DO $$
DECLARE
    v_fan UUID := 'f2800000-0000-0000-0000-000000000001';
    v_trivia UUID := 't2800000-0000-0000-0000-000000000001';
    v_err TEXT;
BEGIN
    -- Marcar intento como enviado
    UPDATE trivia_attempts 
    SET submitted_at = NOW(), expires_at = NOW() + interval '1 hour'
    WHERE fan_id = v_fan AND trivia_id = v_trivia AND idempotency_key = 'idemp-reuse-test-01';

    INSERT INTO captcha_passes (user_id, ip_hash, used, expires_at)
    VALUES (v_fan, 'hash_test_4', false, NOW() + interval '10 minutes');

    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "f2800000-0000-0000-0000-000000000001", "role": "authenticated"}';

    BEGIN
        PERFORM public.start_trivia_attempt(v_trivia, 'idemp-reuse-test-01');
        RAISE EXCEPTION 'Debió fallar con TRIVIA_ALREADY_PLAYED';
    EXCEPTION WHEN OTHERS THEN
        v_err := SQLERRM;
        IF v_err NOT LIKE '%TRIVIA_ALREADY_PLAYED%' THEN
            RAISE EXCEPTION 'Mensaje inesperado: %', v_err;
        END IF;
    END;
END $$;

SELECT pass('TEST 3: Reintento con intento enviado lanza TRIVIA_ALREADY_PLAYED');


-- TEST 4: Las preguntas devueltas en el intento NO contienen is_correct
DO $$
DECLARE
    v_fan UUID := 'f2800000-0000-0000-0000-000000000001';
    v_trivia UUID := 't2800000-0000-0000-0000-000000000001';
    v_res JSONB;
BEGIN
    INSERT INTO captcha_passes (user_id, ip_hash, used, expires_at)
    VALUES (v_fan, 'hash_test_5', false, NOW() + interval '10 minutes');

    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "f2800000-0000-0000-0000-000000000001", "role": "authenticated"}';

    v_res := public.start_trivia_attempt(v_trivia, 'idemp-reuse-test-02');

    IF v_res::text LIKE '%is_correct%' THEN
        RAISE EXCEPTION 'start_trivia_attempt expone el campo is_correct: %', v_res;
    END IF;
END $$;

SELECT pass('TEST 4: Las preguntas devueltas no contienen el campo is_correct');

ROLLBACK;
