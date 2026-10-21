-- =============================================================
-- TEST SUITE: Profile Cover URL Privilege Verification
-- =============================================================

BEGIN;
SELECT plan(3);

-- Setup: Fan user
DO $$
DECLARE
    v_fan_id UUID := 'f3000000-0000-0000-0000-000000000001';
BEGIN
    INSERT INTO auth.users (id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token)
    VALUES
        (v_fan_id, 'authenticated', 'authenticated', 'fan_cover_test@test.com', crypt('FanPass123!', gen_salt('bf')), '{"provider":"email"}'::jsonb, '{}'::jsonb, NOW(), NOW(), '')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO profiles (id, display_name, status)
    VALUES (v_fan_id, 'Fan Cover Test', 'active')
    ON CONFLICT (id) DO UPDATE SET display_name = EXCLUDED.display_name;
END $$;

-- TEST 1: Authenticated user can update own cover_url
DO $$
DECLARE
    v_fan_id UUID := 'f3000000-0000-0000-0000-000000000001';
    v_new_cover TEXT := 'https://images.unsplash.com/photo-1546519638-68e109498ffc?auto=format&fit=crop&w=1200&q=80';
    v_updated TEXT;
BEGIN
    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "f3000000-0000-0000-0000-000000000001", "role": "authenticated"}';

    UPDATE public.profiles
    SET cover_url = v_new_cover
    WHERE id = v_fan_id;

    SELECT cover_url INTO v_updated FROM public.profiles WHERE id = v_fan_id;

    IF v_updated = v_new_cover THEN
        PERFORM ok(true, 'Fan autenticado puede actualizar cover_url exitosamente.');
    ELSE
        PERFORM ok(false, 'cover_url no coincide con el valor actualizado.');
    END IF;
END $$;

-- TEST 2: Authenticated user cannot update another user's cover_url (RLS protects rows)
DO $$
DECLARE
    v_fan_id UUID := 'f3000000-0000-0000-0000-000000000001';
    v_other_id UUID := 'f3000000-0000-0000-0000-000000000002';
    v_other_cover TEXT;
BEGIN
    -- Create other user
    INSERT INTO profiles (id, display_name, status, cover_url)
    VALUES (v_other_id, 'Other Fan', 'active', 'https://example.com/original.jpg')
    ON CONFLICT (id) DO NOTHING;

    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "f3000000-0000-0000-0000-000000000001", "role": "authenticated"}';

    UPDATE public.profiles
    SET cover_url = 'https://example.com/hacked.jpg'
    WHERE id = v_other_id;

    SELECT cover_url INTO v_other_cover FROM public.profiles WHERE id = v_other_id;

    IF v_other_cover = 'https://example.com/original.jpg' THEN
        PERFORM ok(true, 'RLS previene que un fan actualice cover_url de otro usuario.');
    ELSE
        PERFORM ok(false, 'RLS permitió modificar el perfil de otro usuario.');
    END IF;
END $$;

-- TEST 3: Authenticated user cannot update protected columns (e.g. status)
SELECT throws_ok(
    $$
      SET LOCAL ROLE authenticated;
      SET LOCAL "request.jwt.claims" = '{"sub": "f3000000-0000-0000-0000-000000000001", "role": "authenticated"}';
      UPDATE public.profiles SET status = 'deleted' WHERE id = 'f3000000-0000-0000-0000-000000000001';
    $$,
    '42501',
    NULL,
    'El rol authenticated no puede actualizar columnas restringidas como status.'
);

SELECT * FROM finish();
ROLLBACK;
