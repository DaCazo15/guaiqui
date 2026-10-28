BEGIN;
SELECT plan(12);

-- 1. Setup Test Role Accounts
SELECT tests.create_supabase_user('antifraud_admin_u1', 'admin_f11@guaiqui.test');
SELECT tests.create_supabase_user('antifraud_staff_u1', 'staff_f11@guaiqui.test');
SELECT tests.create_supabase_user('antifraud_fan_u1', 'fan_f11@guaiqui.test');

INSERT INTO public.profiles (id, display_name, status)
VALUES
    (tests.get_supabase_uid('antifraud_admin_u1'), 'Admin Antifraud', 'active'),
    (tests.get_supabase_uid('antifraud_staff_u1'), 'Staff Antifraud', 'active'),
    (tests.get_supabase_uid('antifraud_fan_u1'), 'Fan Antifraud', 'active')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.staff_members (user_id, role, active)
VALUES
    (tests.get_supabase_uid('antifraud_admin_u1'), 'admin', true),
    (tests.get_supabase_uid('antifraud_staff_u1'), 'staff', true)
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO public.wallets (fan_id, balance_cache)
VALUES (tests.get_supabase_uid('antifraud_fan_u1'), 0)
ON CONFLICT (fan_id) DO NOTHING;

-- Create Sample Trivia
INSERT INTO public.trivias (id, title, status, starts_at, ends_at, time_limit_seconds)
VALUES ('00000000-0000-0000-0000-000000000011'::uuid, 'Trivia Antifraud Test', 'published', NOW() - INTERVAL '1 hour', NOW() + INTERVAL '1 hour', 60)
ON CONFLICT (id) DO NOTHING;

-- 2. Test Captcha Pass Requirement for start_trivia_attempt
SELECT tests.authenticate_as('antifraud_fan_u1');

SELECT throws_ok(
    $$SELECT public.start_trivia_attempt('00000000-0000-0000-0000-000000000011'::uuid, 'idem_no_pass')$$,
    'CAPTCHA_REQUIRED',
    'start_trivia_attempt without valid captcha pass must fail with CAPTCHA_REQUIRED'
);

-- Insert Valid Captcha Pass
INSERT INTO public.captcha_passes (user_id, ip_hash, used, expires_at)
VALUES (tests.get_supabase_uid('antifraud_fan_u1'), 'hash123', false, NOW() + INTERVAL '10 minutes');

SELECT lives_ok(
    $$SELECT public.start_trivia_attempt('00000000-0000-0000-0000-000000000011'::uuid, 'idem_pass_valid')$$,
    'start_trivia_attempt succeeds when valid captcha pass exists'
);

-- Verify Pass is Single-Use (consumed)
SELECT throws_ok(
    $$SELECT public.start_trivia_attempt('00000000-0000-0000-0000-000000000011'::uuid, 'idem_pass_reuse')$$,
    'CAPTCHA_REQUIRED',
    'Reusing consumed captcha pass must fail with CAPTCHA_REQUIRED'
);

-- 3. Rate Limit Test
SELECT lives_ok(
    $$SELECT public.check_rate_limit(tests.get_supabase_uid('antifraud_fan_u1'), 'test_action', 2, 60)$$,
    'check_rate_limit allows first request under limit'
);

SELECT lives_ok(
    $$SELECT public.check_rate_limit(tests.get_supabase_uid('antifraud_fan_u1'), 'test_action', 2, 60)$$,
    'check_rate_limit allows second request at limit'
);

SELECT throws_ok(
    $$SELECT public.check_rate_limit(tests.get_supabase_uid('antifraud_fan_u1'), 'test_action', 2, 60)$$,
    'RATE_LIMITED',
    'check_rate_limit raises RATE_LIMITED when exceeding max requests'
);

-- 4. Access Control on Admin Risk Functions
SELECT tests.authenticate_as('antifraud_staff_u1');

SELECT throws_ok(
    'SELECT public.admin_risk_queue()',
    'Acceso denegado. Se requiere rol de administrador activo.',
    'Staff role must be denied from running admin_risk_queue'
);

SELECT throws_ok(
    $$SELECT public.admin_release_held_pearls('00000000-0000-0000-0000-000000000001'::uuid, 'Nota')$$,
    'Acceso denegado. Se requiere rol de administrador activo.',
    'Staff role must be denied from running admin_release_held_pearls'
);

-- 5. Admin Functionality & Held Pearls Release
SELECT tests.authenticate_as('antifraud_admin_u1');

SELECT lives_ok(
    'SELECT public.admin_risk_queue()',
    'Admin can run admin_risk_queue'
);

-- Create Held Ledger Entry
INSERT INTO public.ledger_entries (id, fan_id, amount, type, status, source_type, source_id, note)
VALUES ('00000000-0000-0000-0000-000000000099'::uuid, tests.get_supabase_uid('antifraud_fan_u1'), 150, 'trivia_reward', 'held', 'trivia_attempt', 'att_123', 'Retenido por prueba')
ON CONFLICT (id) DO NOTHING;

-- Verify Held Pearls do NOT reflect in Wallet balance cache
SELECT is(
    (SELECT balance_cache FROM public.wallets WHERE fan_id = tests.get_supabase_uid('antifraud_fan_u1')),
    0,
    'Held pearls do not reflect in active wallet balance'
);

-- Release Held Pearls via Admin Function
SELECT lives_ok(
    $$SELECT public.admin_release_held_pearls('00000000-0000-0000-0000-000000000099'::uuid, 'Verificado por staff en taquilla')$$,
    'Admin can release held pearls with mandatory justification note'
);

-- Verify Wallet Balance updated after release
SELECT is(
    (SELECT balance_cache FROM public.wallets WHERE fan_id = tests.get_supabase_uid('antifraud_fan_u1')),
    150,
    'Wallet balance updated to 150 after admin released held pearls'
);

-- 6. Telemetry Purge Function
SELECT lives_ok(
    'SELECT public.purge_fraud_telemetry()',
    'purge_fraud_telemetry runs cleanly'
);

SELECT * FROM finish();
ROLLBACK;
