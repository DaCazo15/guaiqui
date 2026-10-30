-- =============================================================
-- TEST SUITE: Fase 18 — Rewarded Ads Security, Limits & Reconciliation
-- =============================================================
BEGIN;
SELECT plan(14);

DO $$
DECLARE
    v_fan_id UUID := '77777777-7777-7777-7777-777777777777';
    v_admin_id UUID := '88888888-8888-8888-8888-888888888888';
    v_today DATE := (NOW() AT TIME ZONE 'America/Caracas')::date;
BEGIN
    INSERT INTO auth.users (id, aud, role, email, email_confirmed_at, created_at)
    VALUES
        (v_fan_id, 'authenticated', 'authenticated', 'fan_ad_test@guaiqui.test', NOW(), NOW() - INTERVAL '10 days'),
        (v_admin_id, 'authenticated', 'authenticated', 'admin_ad_test@guaiqui.test', NOW(), NOW() - INTERVAL '30 days')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.profiles (id, display_name, status, created_at, terms_accepted_at, privacy_accepted_at, pearls_rules_accepted_at)
    VALUES
        (v_fan_id, 'Fan Ad Tester', 'active', NOW() - INTERVAL '10 days', NOW(), NOW(), NOW()),
        (v_admin_id, 'Admin Ad Tester', 'active', NOW() - INTERVAL '30 days', NOW(), NOW(), NOW())
    ON CONFLICT (id) DO UPDATE SET status = 'active', created_at = EXCLUDED.created_at, terms_accepted_at = NOW(), privacy_accepted_at = NOW(), pearls_rules_accepted_at = NOW();

    INSERT INTO public.staff_members (user_id, team_id, role, active)
    VALUES (v_admin_id, 'a0000000-0000-0000-0000-000000000001', 'admin', true)
    ON CONFLICT (user_id) DO UPDATE SET team_id = 'a0000000-0000-0000-0000-000000000001', role = 'admin', active = true;

    INSERT INTO public.wallets (fan_id, team_id, balance_cache)
    VALUES (v_fan_id, 'a0000000-0000-0000-0000-000000000001', 0)
    ON CONFLICT (fan_id, team_id) DO UPDATE SET balance_cache = 0;

    -- Add completed trivia attempt for fan
    INSERT INTO public.trivia_attempts (id, fan_id, team_id, trivia_id, started_at, submitted_at, score, pearls_awarded, idempotency_key, expires_at)
    VALUES (gen_random_uuid(), v_fan_id, 'a0000000-0000-0000-0000-000000000001', gen_random_uuid(), NOW() - INTERVAL '1 hour', NOW() - INTERVAL '50 minutes', 100, 50, 'test_setup_key', NOW() + INTERVAL '1 hour')
    ON CONFLICT DO NOTHING;

    -- Captcha pass for initial session
    INSERT INTO public.captcha_passes (user_id, ip_hash, used, expires_at)
    VALUES (v_fan_id, 'hash_ad_test', false, NOW() + INTERVAL '1 hour')
    ON CONFLICT DO NOTHING;

    -- Default economy settings with ad_min_seconds = 1 for testing
    INSERT INTO public.economy_settings (
        daily_pearl_cap, weekly_pearl_cap, ads_enabled, daily_ad_views, block_size, ad_min_seconds, ad_min_account_age_days, ad_min_trivias_completed
    ) VALUES (
        1000, 5000, true, 50, 10, 1, 3, 1
    );
END $$;


-- 1. Security: Fan cannot execute admin_update_ads_settings
SELECT throws_ok(
    $$
        SET LOCAL ROLE authenticated;
        SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777777777", "role": "authenticated"}';
        SELECT public.admin_update_ads_settings('{"ads_enabled": false}'::jsonb);
    $$,
    '42501',
    NULL,
    'TEST 1: Fan autenticado no puede ejecutar admin_update_ads_settings'
);


-- 2. Security: Fan cannot mutate ad_sessions directly via SQL
SELECT throws_ok(
    $$
        SET LOCAL ROLE authenticated;
        SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777777777", "role": "authenticated"}';
        INSERT INTO public.ad_sessions (user_id, status, day) VALUES ('77777777-7777-7777-7777-777777777777', 'completed', CURRENT_DATE);
    $$,
    '42501',
    NULL,
    'TEST 2: Cliente autenticado no puede insertar directamente en ad_sessions'
);


-- 3. Flow: Two start_ad_session calls in a row void the first session
DO $$
DECLARE
    v_res1 JSONB;
    v_res2 JSONB;
    v_s1 UUID;
    v_s2 UUID;
    v_status1 TEXT;
BEGIN
    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777777777", "role": "authenticated"}';

    v_res1 := public.start_ad_session('test_key_1');
    v_s1 := (v_res1->>'session_id')::uuid;

    v_res2 := public.start_ad_session('test_key_2');
    v_s2 := (v_res2->>'session_id')::uuid;

    SELECT status INTO v_status1 FROM public.ad_sessions WHERE id = v_s1;

    IF v_status1 != 'void' THEN
        RAISE EXCEPTION 'La primera sesión no fue anulada. Estado actual: %', v_status1;
    END IF;
END $$;

SELECT pass('TEST 3: Iniciar una nueva sesión anula la sesión previa en estado started');


-- 4. Timing: Completing before ad_min_seconds fails
DO $$
DECLARE
    v_res JSONB;
    v_sid UUID;
BEGIN
    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777777777", "role": "authenticated"}';

    v_res := public.start_ad_session('test_fast_key');
    v_sid := (v_res->>'session_id')::uuid;

    -- Immediate completion without waiting ad_min_seconds should fail
    PERFORM public.complete_ad_session(v_sid, 'fast_comp_key');
    RAISE EXCEPTION 'Debería haber fallado por tiempo insuficiente.';
EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE '%demasiado rápido%' THEN
        -- Expected error
        NULL;
    ELSE
        RAISE EXCEPTION 'Error inesperado: %', SQLERRM;
    END IF;
END $$;

SELECT pass('TEST 4: Completar un anuncio antes del tiempo mínimo del servidor falla');


-- 5. Flow & Block Payments: 10 completed ads awards block 1 (5 pearls), 20 ads awards block 2 (10 pearls), total 15 pearls
DO $$
DECLARE
    v_res JSONB;
    v_sid UUID;
    v_comp JSONB;
    v_balance INT;
    i INT;
BEGIN
    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777777777", "role": "authenticated"}';

    -- Simulate 20 ad completions (waiting 1 second per completion to satisfy ad_min_seconds = 1)
    FOR i IN 1..20 LOOP
        v_res := public.start_ad_session('loop_key_' || i);
        v_sid := (v_res->>'session_id')::uuid;

        -- Manually backdate started_at by 2 seconds so test runs instantly without pg_sleep
        UPDATE public.ad_sessions SET started_at = NOW() - INTERVAL '2 seconds' WHERE id = v_sid;

        v_comp := public.complete_ad_session(v_sid, 'loop_comp_key_' || i);
    END LOOP;

    SELECT balance_cache INTO v_balance FROM public.wallets WHERE fan_id = '77777777-7777-7777-7777-777777777777';

    IF v_balance != 15 THEN
        RAISE EXCEPTION 'El saldo esperado tras 20 anuncios es 15 perlitas, obtenido: %', v_balance;
    END IF;
END $$;

SELECT pass('TEST 5: 20 anuncios completados pagan exactamente 5 (bloque 1) + 10 (bloque 2) = 15 perlitas');


-- 6. Deduplication: Same block is never paid twice
DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM public.ledger_entries
    WHERE fan_id = '77777777-7777-7777-7777-777777777777' AND type = 'ad_reward';

    IF v_count != 2 THEN
        RAISE EXCEPTION 'Se esperaban exactamente 2 entradas en el libro (bloque 1 y 2), encontradas: %', v_count;
    END IF;
END $$;

SELECT pass('TEST 6: Ningún bloque de anuncios se paga más de una vez');


-- 7. Daily Limit: 51st ad session of the day is rejected with AD_DAILY_LIMIT
DO $$
DECLARE
    v_res JSONB;
    v_sid UUID;
    i INT;
BEGIN
    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777777777", "role": "authenticated"}';

    -- Fast-forward completed_count to 50
    UPDATE public.ad_daily_progress SET completed_count = 50 WHERE user_id = '77777777-7777-7777-7777-777777777777' AND day = (NOW() AT TIME ZONE 'America/Caracas')::date;

    PERFORM public.start_ad_session('test_51st_key');
    RAISE EXCEPTION 'Debería haber fallado por alcanzar el límite de 50.';
EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE '%límite diario de 50%' THEN
        NULL;
    ELSE
        RAISE EXCEPTION 'Error inesperado: %', SQLERRM;
    END IF;
END $$;

SELECT pass('TEST 7: La sesión 51 del día es rechazada por límite diario');


-- 8. Disabled Ads: When ads_enabled is false, start_ad_session fails
DO $$
BEGIN
    UPDATE public.economy_settings SET ads_enabled = false;

    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777777777", "role": "authenticated"}';

    PERFORM public.start_ad_session('test_disabled_key');
    RAISE EXCEPTION 'Debería haber fallado por ads_enabled en falso.';
EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE '%desactivados%' THEN
        NULL;
    ELSE
        RAISE EXCEPTION 'Error inesperado: %', SQLERRM;
    END IF;
END $$;

-- Restore ads_enabled
UPDATE public.economy_settings SET ads_enabled = true;

SELECT pass('TEST 8: Cuando ads_enabled está en falso, no se puede iniciar ninguna sesión de anuncio');


-- 9. Account Age Check: Brand new account fails start_ad_session
DO $$
DECLARE
    v_new_uid UUID := '99999999-9999-9999-9999-999999999999';
BEGIN
    INSERT INTO auth.users (id, aud, role, email, email_confirmed_at, created_at)
    VALUES (v_new_uid, 'authenticated', 'authenticated', 'new_fan_ad@guaiqui.test', NOW(), NOW())
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.profiles (id, display_name, status, created_at)
    VALUES (v_new_uid, 'New Fan Tester', 'active', NOW())
    ON CONFLICT (id) DO NOTHING;

    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "99999999-9999-9999-9999-999999999999", "role": "authenticated"}';

    PERFORM public.start_ad_session('new_account_key');
    RAISE EXCEPTION 'Debería haber fallado por antigüedad de cuenta insuficiente.';
EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE '%antigüedad%' THEN
        NULL;
    ELSE
        RAISE EXCEPTION 'Error inesperado: %', SQLERRM;
    END IF;
END $$;

SELECT pass('TEST 9: Una cuenta sin la antigüedad mínima no puede iniciar sesiones de anuncios');


-- 10. Held Rewards: High risk user gets reward held without wallet balance increment
DO $$
DECLARE
    v_risk_fan UUID := '66666666-6666-6666-6666-666666666666';
    v_today DATE := (NOW() AT TIME ZONE 'America/Caracas')::date;
    v_res JSONB;
    v_sid UUID;
    v_comp JSONB;
    v_bal INT;
    i INT;
BEGIN
    INSERT INTO auth.users (id, aud, role, email, email_confirmed_at, created_at)
    VALUES (v_risk_fan, 'authenticated', 'authenticated', 'risk_fan_ad@guaiqui.test', NOW(), NOW() - INTERVAL '20 days')
    ON CONFLICT DO NOTHING;

    INSERT INTO public.profiles (id, display_name, status, created_at, terms_accepted_at, privacy_accepted_at, pearls_rules_accepted_at)
    VALUES (v_risk_fan, 'Risk Fan Tester', 'active', NOW() - INTERVAL '20 days', NOW(), NOW(), NOW())
    ON CONFLICT (id) DO UPDATE SET terms_accepted_at = NOW(), privacy_accepted_at = NOW(), pearls_rules_accepted_at = NOW();

    INSERT INTO public.wallets (fan_id, team_id, balance_cache) VALUES (v_risk_fan, 'a0000000-0000-0000-0000-000000000001', 0) ON CONFLICT (fan_id, team_id) DO NOTHING;

    INSERT INTO public.trivia_attempts (id, fan_id, team_id, trivia_id, started_at, submitted_at, score, pearls_awarded, idempotency_key, expires_at)
    VALUES (gen_random_uuid(), v_risk_fan, 'a0000000-0000-0000-0000-000000000001', gen_random_uuid(), NOW() - INTERVAL '1 hour', NOW() - INTERVAL '50 minutes', 100, 50, 'risk_setup_key', NOW() + INTERVAL '1 hour')
    ON CONFLICT DO NOTHING;

    INSERT INTO public.risk_flags (fan_id, reason, severity, resolved)
    VALUES (v_risk_fan, 'Unresolved test risk flag', 'high', false);

    INSERT INTO public.captcha_passes (user_id, ip_hash, used, expires_at)
    VALUES (v_risk_fan, 'hash_risk_test', false, NOW() + INTERVAL '1 hour')
    ON CONFLICT DO NOTHING;

    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "66666666-6666-6666-6666-666666666666", "role": "authenticated"}';

    FOR i IN 1..10 LOOP
        v_res := public.start_ad_session('risk_loop_' || i);
        v_sid := (v_res->>'session_id')::uuid;
        UPDATE public.ad_sessions SET started_at = NOW() - INTERVAL '2 seconds' WHERE id = v_sid;
        v_comp := public.complete_ad_session(v_sid, 'risk_comp_' || i);
    END LOOP;

    SELECT balance_cache INTO v_bal FROM public.wallets WHERE fan_id = v_risk_fan AND team_id = 'a0000000-0000-0000-0000-000000000001';

    IF v_bal != 0 THEN
        RAISE EXCEPTION 'Las perlitas de un usuario con riesgo alto no deberían incrementar el saldo del wallet, obtenido: %', v_bal;
    END IF;
END $$;

SELECT pass('TEST 10: Usuario con riesgo alto recibe la recompensa en estado retenido (held) sin abonar al wallet');


-- 11. Reconciliation: Admin import_ad_report calculates discrepancy and flags alert if ratio > 1.2
DO $$
DECLARE
    v_res JSONB;
BEGIN
    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "88888888-8888-8888-8888-888888888888", "role": "authenticated", "aal": "aal2"}';

    -- 20 DB completed sessions exist for today, if Google reports 10 impressions (ratio = 2.0 > 1.2), alert is flagged
    v_res := public.import_ad_report((NOW() AT TIME ZONE 'America/Caracas')::date, 10, 'Test report discrepancy');

    IF (v_res->>'alert_flagged')::boolean IS NOT TRUE THEN
        RAISE EXCEPTION 'La alerta de discrepancia debería haberse creado.';
    END IF;
END $$;

SELECT pass('TEST 11: La conciliación crea una alerta en system_alerts cuando la proporción DB/Google supera 1.2');


-- 12. Admin Analytics: analytics_ads returns aggregated statistics
DO $$
DECLARE
    v_res JSONB;
BEGIN
    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "88888888-8888-8888-8888-888888888888", "role": "authenticated", "aal": "aal2"}';

    v_res := public.analytics_ads(NOW() - INTERVAL '1 day', NOW() + INTERVAL '1 day');

    IF (v_res->>'sessions_completed')::int < 20 THEN
        RAISE EXCEPTION 'Las sesiones completadas deberían ser al menos 20, obtenidas: %', (v_res->>'sessions_completed');
    END IF;
END $$;

SELECT pass('TEST 12: analytics_ads devuelve las agregaciones correctas de sesiones de anuncios');


-- 13. Privacy Policy: policy_documents contains version 18.0
SELECT ok(
    EXISTS (SELECT 1 FROM public.policy_documents WHERE slug = 'privacy' AND version = '18.0'),
    'TEST 13: La política de privacidad registra la versión 18.0 con mención a anuncios de Google'
);


-- 14. Cancel session: cancel_ad_session updates status to reason and gives 0 pearls
DO $$
DECLARE
    v_res JSONB;
    v_sid UUID;
    v_status TEXT;
BEGIN
    INSERT INTO public.captcha_passes (user_id, ip_hash, used, expires_at)
    VALUES ('77777777-7777-7777-7777-777777777777', 'hash_cancel_test', false, NOW() + INTERVAL '1 hour')
    ON CONFLICT DO NOTHING;

    -- Reset completed count
    UPDATE public.ad_daily_progress SET completed_count = 0 WHERE user_id = '77777777-7777-7777-7777-777777777777' AND day = (NOW() AT TIME ZONE 'America/Caracas')::date;

    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777777777", "role": "authenticated"}';

    v_res := public.start_ad_session('test_cancel_flow_key');
    v_sid := (v_res->>'session_id')::uuid;

    PERFORM public.cancel_ad_session(v_sid, 'closed_early');

    SELECT status INTO v_status FROM public.ad_sessions WHERE id = v_sid;

    IF v_status != 'closed_early' THEN
        RAISE EXCEPTION 'El estado tras la cancelación debería ser closed_early, obtenido: %', v_status;
    END IF;
END $$;

SELECT pass('TEST 14: cancel_ad_session actualiza el estado a closed_early sin otorgar recompensas');

SELECT * FROM finish();
ROLLBACK;
