-- =============================================================
-- TEST SUITE: Legal Terms Acceptance and Version Permissions
-- =============================================================

BEGIN;
SELECT plan(4);

-- Setup: Fan user
DO $$
DECLARE
    v_fan_id UUID := 'f3100000-0000-0000-0000-000000000001';
BEGIN
    INSERT INTO auth.users (id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_confirmed_at)
    VALUES
        (v_fan_id, 'authenticated', 'authenticated', 'fan_terms_test@test.com', crypt('FanPass123!', gen_salt('bf')), '{"provider":"email"}'::jsonb, '{}'::jsonb, NOW(), NOW(), '', NOW())
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO profiles (id, display_name, status, terms_version, privacy_version, pearls_rules_version)
    VALUES (v_fan_id, 'Fan Terms Test', 'active', '0.9', '0.9', '0.9')
    ON CONFLICT (id) DO UPDATE SET status = 'active', display_name = EXCLUDED.display_name;
END $$;

-- TEST 1: Anon can execute get_active_legal_versions
DO $$
DECLARE
    v_res JSONB;
BEGIN
    SET LOCAL ROLE anon;
    v_res := public.get_active_legal_versions();

    IF v_res IS NOT NULL AND jsonb_typeof(v_res) = 'object' THEN
        PERFORM ok(true, 'Rol anon puede consultar get_active_legal_versions().');
    ELSE
        PERFORM ok(false, 'get_active_legal_versions() no retornó un objeto JSON válido para anon.');
    END IF;
END $$;

-- TEST 2: Authenticated can execute get_active_legal_versions
DO $$
DECLARE
    v_res JSONB;
BEGIN
    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "f3100000-0000-0000-0000-000000000001", "role": "authenticated"}';

    v_res := public.get_active_legal_versions();

    IF v_res IS NOT NULL AND jsonb_typeof(v_res) = 'object' THEN
        PERFORM ok(true, 'Rol authenticated puede consultar get_active_legal_versions().');
    ELSE
        PERFORM ok(false, 'get_active_legal_versions() no retornó un objeto JSON válido para authenticated.');
    END IF;
END $$;

-- TEST 3: Authenticated fan can accept terms, updating updated_at and active versions
DO $$
DECLARE
    v_fan_id UUID := 'f3100000-0000-0000-0000-000000000001';
    v_res JSONB;
    v_updated_at TIMESTAMPTZ;
    v_terms_at TIMESTAMPTZ;
    v_priv_ver TEXT;
BEGIN
    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "f3100000-0000-0000-0000-000000000001", "role": "authenticated"}';

    v_res := public.accept_terms();

    SELECT updated_at, terms_accepted_at, privacy_version
    INTO v_updated_at, v_terms_at, v_priv_ver
    FROM public.profiles
    WHERE id = v_fan_id;

    IF v_res->>'success' = 'true' AND v_updated_at IS NOT NULL AND v_terms_at IS NOT NULL THEN
        PERFORM ok(true, 'accept_terms() actualiza correctamente updated_at y registra timestamps legales.');
    ELSE
        PERFORM ok(false, 'accept_terms() no actualizó correctamente el perfil.');
    END IF;
END $$;

-- TEST 4: Anon cannot call accept_terms
SELECT throws_ok(
    $$
      SET LOCAL ROLE anon;
      SELECT public.accept_terms();
    $$,
    '42501',
    NULL,
    'Rol anon no puede ejecutar la función accept_terms().'
);

SELECT * FROM finish();
ROLLBACK;
