BEGIN;

SELECT plan(5);

-- 1. Setup Fan User
INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud)
VALUES ('77777777-7777-7777-7777-777777777777', '00000000-0000-0000-0000-000000000000', 'security_fan@guaiqui.test', 'encrypted', NOW(), '{"provider":"email","providers":["email"]}', '{}', NOW(), NOW(), 'authenticated', 'authenticated')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, display_name, status, birth_date, created_at, terms_accepted_at, terms_version)
VALUES ('77777777-7777-7777-7777-777777777777', 'Fan de Prueba', 'active', '1990-05-20', NOW(), NOW(), 'v1.0')
ON CONFLICT (id) DO UPDATE SET birth_date = '1990-05-20', status = 'active', terms_accepted_at = NOW(), terms_version = 'v1.0';

-- Test 1: Fan role attempting SELECT on trivia_options returns 0 rows (RLS restriction)
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777777777", "role": "authenticated"}';

SELECT is(
    (SELECT COUNT(*) FROM public.trivia_options),
    0::bigint,
    'Fan role SELECT on trivia_options returns 0 rows due to Admin-only RLS policy'
);

-- Test 2: Fan role attempting UPDATE on status column in profiles fails (column-level permission denied)
SELECT throws_ok(
    'UPDATE public.profiles SET status = ''active'' WHERE id = ''77777777-7777-7777-7777-777777777777''',
    '42501',
    NULL,
    'Fan cannot UPDATE status column directly in profiles table'
);

-- Test 3: Fan role attempting UPDATE on terms_accepted_at in profiles fails
SELECT throws_ok(
    'UPDATE public.profiles SET terms_accepted_at = NOW() WHERE id = ''77777777-7777-7777-7777-777777777777''',
    '42501',
    NULL,
    'Fan cannot UPDATE legal consent columns directly in profiles table'
);

-- Test 4: RPC accept_terms successfully sets consent timestamps
SELECT is(
    (public.accept_terms()->>'success')::boolean,
    true,
    'RPC accept_terms records legal timestamps server-side'
);

-- Test 5: Re-setting birth_date when already set throws immutability error
SELECT throws_ok(
    'SELECT public.set_birth_date(''1999-12-31''::date)',
    'La fecha de nacimiento no puede ser modificada una vez registrada.',
    'set_birth_date rejects updating birth_date when already set'
);

SELECT finish();

ROLLBACK;
