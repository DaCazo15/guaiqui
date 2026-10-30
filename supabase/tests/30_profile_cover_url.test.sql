-- =============================================================
-- TEST SUITE: Profile Cover URL Privilege Verification
-- =============================================================

BEGIN;
SELECT plan(3);

-- Setup: Fan users
INSERT INTO auth.users (id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_confirmed_at)
VALUES
    ('f3000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'fan_cover_test@test.com', crypt('FanPass123!', gen_salt('bf')), '{"provider":"email"}'::jsonb, '{}'::jsonb, NOW(), NOW(), '', NOW()),
    ('f3000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'other_cover_test@test.com', crypt('FanPass123!', gen_salt('bf')), '{"provider":"email"}'::jsonb, '{}'::jsonb, NOW(), NOW(), '', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO profiles (id, display_name, status, terms_accepted_at, terms_version)
VALUES ('f3000000-0000-0000-0000-000000000001', 'Fan Cover Test', 'active', NOW(), 'v1.0')
ON CONFLICT (id) DO UPDATE SET display_name = EXCLUDED.display_name;

INSERT INTO profiles (id, display_name, status, cover_url, terms_accepted_at, terms_version)
VALUES ('f3000000-0000-0000-0000-000000000002', 'Other Fan', 'active', 'https://example.com/original.jpg', NOW(), 'v1.0')
ON CONFLICT (id) DO UPDATE SET cover_url = EXCLUDED.cover_url;

-- TEST 1: Authenticated user can update own cover_url
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "f3000000-0000-0000-0000-000000000001", "role": "authenticated"}';

UPDATE public.profiles
SET cover_url = 'https://images.unsplash.com/photo-1546519638-68e109498ffc?auto=format&fit=crop&w=1200&q=80'
WHERE id = 'f3000000-0000-0000-0000-000000000001';

SELECT is(
    (SELECT cover_url FROM public.profiles WHERE id = 'f3000000-0000-0000-0000-000000000001'),
    'https://images.unsplash.com/photo-1546519638-68e109498ffc?auto=format&fit=crop&w=1200&q=80',
    'Fan autenticado puede actualizar cover_url exitosamente.'
);
RESET ROLE;

-- TEST 2: Authenticated user cannot update another user's cover_url (RLS protects rows)
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "f3000000-0000-0000-0000-000000000001", "role": "authenticated"}';

UPDATE public.profiles
SET cover_url = 'https://example.com/hacked.jpg'
WHERE id = 'f3000000-0000-0000-0000-000000000002';

SELECT is(
    (SELECT cover_url FROM public.profiles WHERE id = 'f3000000-0000-0000-0000-000000000002'),
    'https://example.com/original.jpg',
    'RLS previene que un fan actualice cover_url de otro usuario.'
);
RESET ROLE;

-- TEST 3: Authenticated user cannot update protected columns (e.g. status)
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "f3000000-0000-0000-0000-000000000001", "role": "authenticated"}';

SELECT throws_ok(
    $$UPDATE public.profiles SET status = 'deleted' WHERE id = 'f3000000-0000-0000-0000-000000000001'$$,
    '42501',
    NULL,
    'El rol authenticated no puede actualizar columnas restringidas como status.'
);
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
