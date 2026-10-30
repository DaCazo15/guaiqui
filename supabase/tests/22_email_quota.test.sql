-- =============================================================
-- TEST SUITE: Fase 15 - Email Quota Tracker & Resend Key Rotation
-- =============================================================

BEGIN;
SELECT plan(4);

-- Setup: Limpiar o inicializar datos para el mes de test
DO $$
DECLARE
    v_period TEXT := to_char(NOW() AT TIME ZONE 'America/Caracas', 'YYYY-MM');
BEGIN
    DELETE FROM public.email_usage_tracker WHERE period_yyyy_mm = v_period;
END $$;


-- TEST 1: Initial call returns key_index = 1
DO $$
DECLARE
    v_res JSONB;
BEGIN
    v_res := public.register_email_send_attempt();

    IF (v_res->>'key_index')::int = 1 AND (v_res->>'total_sent')::int = 1 THEN
        -- OK
    ELSE
        RAISE EXCEPTION 'TEST 1 failed: %', v_res;
    END IF;
END $$;

SELECT pass('TEST 1: register_email_send_attempt inicializa el contador y utiliza la Key 1 (0 a 2999 envíos)');


-- TEST 2: Key rotation to Key 2 when total_sent reaches 3,000
DO $$
DECLARE
    v_period TEXT := to_char(NOW() AT TIME ZONE 'America/Caracas', 'YYYY-MM');
    v_res JSONB;
BEGIN
    UPDATE public.email_usage_tracker
    SET total_sent = 3000
    WHERE period_yyyy_mm = v_period;

    v_res := public.register_email_send_attempt();

    IF (v_res->>'key_index')::int = 2 AND (v_res->>'total_sent')::int = 3001 THEN
        -- OK
    ELSE
        RAISE EXCEPTION 'TEST 2 failed: %', v_res;
    END IF;
END $$;

SELECT pass('TEST 2: Al alcanzar los 3.000 envíos conmuta automáticamente a la Key 2');


-- TEST 3: At 6,000 emails, raises maintenance exception
DO $$
DECLARE
    v_period TEXT := to_char(NOW() AT TIME ZONE 'America/Caracas', 'YYYY-MM');
    v_res JSONB;
BEGIN
    UPDATE public.email_usage_tracker
    SET total_sent = 6000
    WHERE period_yyyy_mm = v_period;

    v_res := public.register_email_send_attempt();
    RAISE EXCEPTION 'Should have thrown maintenance exception';
EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE '%Servicio en mantenimiento%' THEN
        -- OK
    ELSE
        RAISE EXCEPTION 'Unexpected error message: %', SQLERRM;
    END IF;
END $$;

SELECT pass('TEST 3: Al alcanzar 6.000 envíos mensual arroja excepción de mantenimiento al usuario');


-- TEST 4: At 6,000 emails, logs alert in risk_flags for admin panel
DO $$
DECLARE
    v_flag_count INT;
BEGIN
    SELECT COUNT(*) INTO v_flag_count
    FROM public.risk_flags
    WHERE reason LIKE 'EMAIL_QUOTA_EXHAUSTED%';

    IF v_flag_count > 0 THEN
        -- OK
    ELSE
        RAISE EXCEPTION 'No risk flag created for email quota exhaustion';
    END IF;
END $$;

SELECT pass('TEST 4: Al agotar los 6.000 envíos notifica automáticamente la incidencia en la cola de riesgos del panel admin');

ROLLBACK;
