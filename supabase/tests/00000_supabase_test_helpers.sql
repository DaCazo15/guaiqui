-- ============================================================================
-- Test Suite Helper: 00000_supabase_test_helpers.sql
-- Description: Sets up the "tests" schema and test helpers for pgTAP test suites
--              in local development and CI (supabase test db).
--              NOTE: This is NOT a production migration; it only runs in test suites.
--              Does NOT issue a ROLLBACK so functions and user_map persist across tests.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgtap;

CREATE SCHEMA IF NOT EXISTS tests;

CREATE TABLE IF NOT EXISTS tests.user_map (
    identifier TEXT PRIMARY KEY,
    uid UUID NOT NULL UNIQUE
);

-- 1. Helper: tests.create_supabase_user
CREATE OR REPLACE FUNCTION tests.create_supabase_user(
    p_identifier TEXT,
    p_email TEXT DEFAULT NULL,
    p_phone TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_uid UUID;
    v_email TEXT := COALESCE(p_email, p_identifier || '@guaiqui.test');
BEGIN
    SELECT uid INTO v_uid FROM tests.user_map WHERE identifier = p_identifier;
    IF v_uid IS NOT NULL THEN
        RETURN v_uid;
    END IF;

    v_uid := gen_random_uuid();

    INSERT INTO auth.users (
        id, instance_id, aud, role, email, encrypted_password,
        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
        created_at, updated_at, confirmation_token
    ) VALUES (
        v_uid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
        v_email, crypt('TestPassword123!', gen_salt('bf')),
        NOW(), '{"provider":"email","providers":["email"]}'::jsonb, p_metadata,
        NOW(), NOW(), ''
    ) ON CONFLICT (id) DO UPDATE SET email_confirmed_at = NOW();

    INSERT INTO tests.user_map (identifier, uid)
    VALUES (p_identifier, v_uid)
    ON CONFLICT (identifier) DO UPDATE SET uid = EXCLUDED.uid;

    RETURN v_uid;
END;
$$;

-- 2. Helper: tests.get_supabase_uid
CREATE OR REPLACE FUNCTION tests.get_supabase_uid(p_identifier TEXT)
RETURNS UUID
LANGUAGE sql
STABLE
AS $$
    SELECT uid FROM tests.user_map WHERE identifier = p_identifier;
$$;

-- 3. Helper: tests.authenticate_as
CREATE OR REPLACE FUNCTION tests.authenticate_as(p_identifier TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_uid UUID;
    v_email TEXT;
    v_is_admin BOOLEAN;
    v_claims JSONB;
BEGIN
    SELECT uid INTO v_uid FROM tests.user_map WHERE identifier = p_identifier;
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Test user identifier "%" not found in tests.user_map', p_identifier;
    END IF;

    SELECT email INTO v_email FROM auth.users WHERE id = v_uid;

    SELECT EXISTS (
        SELECT 1 FROM public.staff_members
        WHERE user_id = v_uid AND role = 'admin' AND active = true
    ) INTO v_is_admin;

    v_claims := jsonb_build_object(
        'sub', v_uid::text,
        'role', 'authenticated',
        'email', COALESCE(v_email, ''),
        'aal', CASE WHEN v_is_admin THEN 'aal2' ELSE 'aal1' END
    );

    PERFORM set_config('request.jwt.claims', v_claims::text, true);
    PERFORM set_config('request.jwt.claim.sub', v_uid::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
END;
$$;

-- 4. Helper: tests.authenticate_as_service_role
CREATE OR REPLACE FUNCTION tests.authenticate_as_service_role()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    PERFORM set_config('request.jwt.claims', '{"role":"service_role"}'::text, true);
    EXECUTE 'SET LOCAL ROLE service_role';
END;
$$;

-- 5. Helper: tests.clear_authentication
CREATE OR REPLACE FUNCTION tests.clear_authentication()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    PERFORM set_config('request.jwt.claims', NULL, true);
    PERFORM set_config('request.jwt.claim.sub', NULL, true);
    EXECUTE 'RESET ROLE';
END;
$$;

-- pg_prove test completion
SELECT plan(1);
SELECT pass('helpers instalados');
SELECT * FROM finish();
