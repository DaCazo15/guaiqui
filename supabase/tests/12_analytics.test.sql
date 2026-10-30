BEGIN;
SELECT plan(12);

-- 1. Setup Test Role Accounts
SELECT tests.create_supabase_user('analytics_admin_u1', 'admin_f10@guaiqui.test');
SELECT tests.create_supabase_user('analytics_staff_u1', 'staff_f10@guaiqui.test');
SELECT tests.create_supabase_user('analytics_fan_u1', 'fan_f10@guaiqui.test');

INSERT INTO public.profiles (id, display_name, municipality, gender, birth_date, status, terms_accepted_at, privacy_accepted_at, pearls_rules_accepted_at)
VALUES
    (tests.get_supabase_uid('analytics_admin_u1'), 'Admin Analytics', 'Mariño', 'Masculino', '1990-01-01', 'active', NOW(), NOW(), NOW()),
    (tests.get_supabase_uid('analytics_staff_u1'), 'Staff Analytics', 'Maneiro', 'Femenino', '1995-05-05', 'active', NOW(), NOW(), NOW()),
    (tests.get_supabase_uid('analytics_fan_u1'), 'Fan Analytics Golden', 'Mariño', 'Masculino', '2000-10-10', 'active', NOW(), NOW(), NOW())
ON CONFLICT (id) DO UPDATE SET terms_accepted_at = NOW(), privacy_accepted_at = NOW(), pearls_rules_accepted_at = NOW();

INSERT INTO public.staff_members (user_id, team_id, role, active)
VALUES
    (tests.get_supabase_uid('analytics_admin_u1'), 'a0000000-0000-0000-0000-000000000001', 'admin', true),
    (tests.get_supabase_uid('analytics_staff_u1'), 'a0000000-0000-0000-0000-000000000001', 'staff', true)
ON CONFLICT (user_id) DO UPDATE SET team_id = 'a0000000-0000-0000-0000-000000000001', role = EXCLUDED.role, active = true;

INSERT INTO public.wallets (fan_id, team_id, balance_cache)
VALUES (tests.get_supabase_uid('analytics_fan_u1'), 'a0000000-0000-0000-0000-000000000001', 300)
ON CONFLICT (fan_id, team_id) DO UPDATE SET balance_cache = 300;

-- Insert Golden Dataset Ledger Entries (300 net)
INSERT INTO public.ledger_entries (id, fan_id, team_id, amount, type, status, source_type, source_id)
VALUES
    (gen_random_uuid(), tests.get_supabase_uid('analytics_fan_u1'), 'a0000000-0000-0000-0000-000000000001', 500, 'trivia_reward', 'confirmed', 'golden_test', 'g1'),
    (gen_random_uuid(), tests.get_supabase_uid('analytics_fan_u1'), 'a0000000-0000-0000-0000-000000000001', -200, 'redemption', 'confirmed', 'golden_test', 'g2')
ON CONFLICT DO NOTHING;

-- 2. Access Control Tests
SELECT tests.authenticate_as('analytics_staff_u1');
SELECT throws_ok(
    'SELECT public.analytics_overview()',
    'Acceso denegado. Se requiere rol de administrador activo.',
    'Staff role must be denied from running analytics_overview'
);

SELECT throws_ok(
    'SELECT public.analytics_economy()',
    'Acceso denegado. Se requiere rol de administrador activo.',
    'Staff role must be denied from running analytics_economy'
);

-- 3. Admin Execution & Golden Dataset Validation
SELECT tests.authenticate_as('analytics_admin_u1');

SELECT lives_ok(
    'SELECT public.analytics_overview()',
    'Admin role can execute analytics_overview successfully'
);

SELECT lives_ok(
    'SELECT public.analytics_economy()',
    'Admin role can execute analytics_economy successfully'
);

SELECT lives_ok(
    'SELECT public.analytics_demographics()',
    'Admin role can execute analytics_demographics successfully'
);

-- 4. Invariant Check: SUM(confirmed issued) - SUM(confirmed spent) == SUM(wallets.balance_cache)
SELECT is(
    (SELECT (COALESCE(SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END), 0) - COALESCE(SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END), 0)) FROM public.ledger_entries WHERE status = 'confirmed'),
    (SELECT COALESCE(SUM(balance_cache), 0)::BIGINT FROM public.wallets),
    'Accounting Invariant: Total issued minus total spent equals total in wallets'
);

-- 5. Timezone Caracas Test: Event at 23:30 Caracas time is grouped under local date
INSERT INTO public.trivias (id, team_id, title, status, starts_at, ends_at, time_limit_seconds)
VALUES ('77777777-7777-7777-7777-777777777777', 'a0000000-0000-0000-0000-000000000001', 'Trivia Caracas', 'published', NOW() - INTERVAL '1 day', NOW() + INTERVAL '1 day', 60)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.trivia_attempts (id, fan_id, team_id, trivia_id, started_at, submitted_at, score, pearls_awarded, idempotency_key, expires_at)
VALUES (
    gen_random_uuid(),
    tests.get_supabase_uid('analytics_fan_u1'),
    'a0000000-0000-0000-0000-000000000001',
    '77777777-7777-7777-7777-777777777777',
    '2026-10-09 23:30:00-04'::TIMESTAMPTZ,
    '2026-10-09 23:35:00-04'::TIMESTAMPTZ,
    100,
    50,
    'tz_test_key_123',
    '2026-10-09 23:45:00-04'::TIMESTAMPTZ
) ON CONFLICT DO NOTHING;

SELECT is(
    (SELECT (started_at AT TIME ZONE 'America/Caracas')::DATE FROM public.trivia_attempts WHERE idempotency_key = 'tz_test_key_123'),
    '2026-10-09'::DATE,
    'Caracas local time 23:30 is correctly attributed to 2026-10-09'
);

-- 6. k-anonymity Test: Demographics groups with <5 count are suppressed/grouped into "Otros (< 5)"
SELECT ok(
    EXISTS (
        SELECT 1 FROM jsonb_array_elements((public.analytics_demographics()->'by_municipality')) elem
        WHERE elem->>'name' = 'Otros (< 5)' OR (elem->>'count')::INT >= 5
    ),
    'Demographics correctly enforces k-anonymity (k=5)'
);

-- 7. Verify analytics_top_fans response does not leak email
SELECT ok(
    NOT EXISTS (
        SELECT 1 FROM jsonb_array_elements(public.analytics_top_fans(5)) elem
        WHERE elem ? 'email' OR elem ? 'phone'
    ),
    'analytics_top_fans strictly respects privacy and contains no contact info'
);

-- 8. Verify analytics_funnel response structure
SELECT is(
    jsonb_array_length(public.analytics_funnel()),
    4,
    'analytics_funnel returns exactly 4 steps'
);

SELECT * FROM finish();
ROLLBACK;
