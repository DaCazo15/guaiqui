BEGIN;

SELECT plan(12);

-- 1. Setup Test Users
INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud)
VALUES 
    ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000', 'fan_a@guaiqui.test', 'encrypted', NOW(), '{"provider":"email","providers":["email"]}', '{}', NOW(), NOW(), 'authenticated', 'authenticated'),
    ('22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000000', 'fan_b@guaiqui.test', 'encrypted', NOW(), '{"provider":"email","providers":["email"]}', '{}', NOW(), NOW(), 'authenticated', 'authenticated'),
    ('33333333-3333-3333-3333-333333333333', '00000000-0000-0000-0000-000000000000', 'staff_a@guaiqui.test', 'encrypted', NOW(), '{"provider":"email","providers":["email"]}', '{}', NOW(), NOW(), 'authenticated', 'authenticated')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, display_name, status, created_at, terms_accepted_at, terms_version)
VALUES 
    ('11111111-1111-1111-1111-111111111111', 'Fan Alpha', 'active', NOW() - INTERVAL '60 days', NOW(), 'v1.0'),
    ('22222222-2222-2222-2222-222222222222', 'Fan Beta', 'active', NOW() - INTERVAL '60 days', NOW(), 'v1.0'),
    ('33333333-3333-3333-3333-333333333333', 'Staff Solo', 'active', NOW() - INTERVAL '60 days', NOW(), 'v1.0')
ON CONFLICT (id) DO UPDATE SET terms_accepted_at = NOW(), terms_version = 'v1.0';

INSERT INTO public.staff_members (team_id, user_id, role, active)
VALUES ('a0000000-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 'staff', true)
ON CONFLICT (team_id, user_id) DO UPDATE SET role = 'staff', active = true;

INSERT INTO public.wallets (team_id, fan_id, balance_cache)
VALUES 
    ('a0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 500),
    ('a0000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 1000)
ON CONFLICT (fan_id, team_id) DO UPDATE SET balance_cache = EXCLUDED.balance_cache;

INSERT INTO public.notifications (id, user_id, type, title, body)
VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222', 'security', 'Mensaje Privado Fan B', 'Contenido confidencial')
ON CONFLICT (id) DO NOTHING;

-- Authenticate as Fan Alpha
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';

-- Test 1: Fan Alpha CANNOT insert into wallets directly
SELECT throws_ok(
    'INSERT INTO public.wallets (team_id, fan_id, balance_cache) VALUES (''a0000000-0000-0000-0000-000000000001'', ''11111111-1111-1111-1111-111111111111'', 9999)',
    'new row violates row-level security policy for table "wallets"',
    'Direct INSERT on wallets must be rejected by RLS'
);

-- Test 2: Fan Alpha CANNOT update wallets directly
SELECT throws_ok(
    'UPDATE public.wallets SET balance_cache = 9999 WHERE fan_id = ''11111111-1111-1111-1111-111111111111''',
    NULL,
    'Direct UPDATE on wallets must be rejected by RLS (0 rows updated or policy violation)'
);

-- Test 3: Fan Alpha CANNOT insert into ledger_entries directly
SELECT throws_ok(
    'INSERT INTO public.ledger_entries (team_id, fan_id, amount, type, status, source_type, source_id, note) VALUES (''a0000000-0000-0000-0000-000000000001'', ''11111111-1111-1111-1111-111111111111'', 500, ''admin_adjustment'', ''confirmed'', ''hack'', ''1'', ''auto'')',
    'new row violates row-level security policy for table "ledger_entries"',
    'Direct INSERT on ledger_entries must be rejected by RLS'
);

-- Test 4: Fan Alpha can only see their own wallet (cannot see Fan Beta wallet)
SELECT is(
    (SELECT COUNT(*) FROM public.wallets WHERE fan_id = '22222222-2222-2222-2222-222222222222'),
    0::bigint,
    'Fan Alpha cannot view Fan Beta wallet'
);

-- Test 5: Fan Alpha cannot view Fan Beta notifications
SELECT is(
    (SELECT COUNT(*) FROM public.notifications WHERE user_id = '22222222-2222-2222-2222-222222222222'),
    0::bigint,
    'Fan Alpha cannot view Fan Beta notifications'
);

-- Test 6: Append-only ledger trigger blocks any UPDATE attempt
SELECT throws_ok(
    'UPDATE public.ledger_entries SET amount = 100 WHERE fan_id = ''11111111-1111-1111-1111-111111111111''',
    NULL,
    'Ledger mutation attempt is blocked'
);

-- Test 7: Append-only audit_log trigger blocks any DELETE attempt
SELECT throws_ok(
    'DELETE FROM public.audit_log',
    NULL,
    'Audit log deletion is blocked'
);

-- Authenticate as Staff Member (Non-Admin)
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';

-- Test 8: Staff member CANNOT run admin-only RPC admin_risk_queue
SELECT throws_ok(
    'SELECT public.admin_risk_queue()',
    'Acceso denegado. Se requiere rol de administrador activo.',
    'Staff member is forbidden from calling admin_risk_queue'
);

-- Test 9: Staff member CANNOT run admin-only RPC admin_upsert_game
SELECT throws_ok(
    'SELECT public.admin_upsert_game(''{"opponent":"Cocodrilos"}''::jsonb)',
    'Acceso denegado. Se requiere rol de administrador activo.',
    'Staff member is forbidden from calling admin_upsert_game'
);

-- Test 10: Rate limiting on claim_birthday_bonus
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';

-- Calling check_rate_limit for birthday bonus up to max limit succeeds, 4th fails
SELECT lives_ok(
    'SELECT public.check_rate_limit(''11111111-1111-1111-1111-111111111111''::uuid, ''claim_birthday_bonus'', 3, 60)',
    'check_rate_limit passes call 1 for birthday bonus'
);
SELECT lives_ok(
    'SELECT public.check_rate_limit(''11111111-1111-1111-1111-111111111111''::uuid, ''claim_birthday_bonus'', 3, 60)',
    'check_rate_limit passes call 2 for birthday bonus'
);
SELECT throws_ok(
    'SELECT public.check_rate_limit(''11111111-1111-1111-1111-111111111111''::uuid, ''claim_birthday_bonus'', 2, 60)',
    'RATE_LIMITED',
    'check_rate_limit rejects when exceeding action rate limit'
);

SELECT finish();

ROLLBACK;
