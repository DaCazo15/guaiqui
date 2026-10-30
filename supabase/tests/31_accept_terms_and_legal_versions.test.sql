-- =============================================================
-- TEST SUITE: Legal Terms Acceptance and Version Permissions
-- =============================================================

BEGIN;
SELECT plan(4);

-- Setup: Fan user
INSERT INTO auth.users (id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_confirmed_at)
VALUES
    ('f3100000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'fan_terms_test@test.com', crypt('FanPass123!', gen_salt('bf')), '{"provider":"email"}'::jsonb, '{}'::jsonb, NOW(), NOW(), '', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO profiles (id, display_name, status, terms_version, privacy_version, pearls_rules_version)
VALUES ('f3100000-0000-0000-0000-000000000001', 'Fan Terms Test', 'active', '0.9', '0.9', '0.9')
ON CONFLICT (id) DO UPDATE SET status = 'active', display_name = EXCLUDED.display_name;

-- TEST 1: Anon can execute get_active_legal_versions
SET LOCAL ROLE anon;
SELECT ok(
    public.get_active_legal_versions() IS NOT NULL AND jsonb_typeof(public.get_active_legal_versions()) = 'object',
    'Rol anon puede consultar get_active_legal_versions().'
);
RESET ROLE;

-- TEST 2: Authenticated can execute get_active_legal_versions
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "f3100000-0000-0000-0000-000000000001", "role": "authenticated"}';

SELECT ok(
    public.get_active_legal_versions() IS NOT NULL AND jsonb_typeof(public.get_active_legal_versions()) = 'object',
    'Rol authenticated puede consultar get_active_legal_versions().'
);
RESET ROLE;

-- TEST 3: Authenticated fan can accept terms, updating updated_at and active versions
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "f3100000-0000-0000-0000-000000000001", "role": "authenticated"}';

SELECT ok(
    (public.accept_terms())->>'success' = 'true'
    AND EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = 'f3100000-0000-0000-0000-000000000001'
          AND updated_at IS NOT NULL
          AND terms_accepted_at IS NOT NULL
    ),
    'accept_terms() actualiza correctamente updated_at y registra timestamps legales.'
);
RESET ROLE;

-- TEST 4: Anon cannot call accept_terms
SET LOCAL ROLE anon;
SELECT throws_ok(
    $$SELECT public.accept_terms()$$,
    '42501',
    NULL,
    'Rol anon no puede ejecutar la función accept_terms().'
);
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
