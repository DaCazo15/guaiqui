-- =============================================================
-- TEST SUITE: Fase 10 - Analytics Repairs & Scan Events Geolocation
-- =============================================================

BEGIN;
SELECT plan(4);

-- Setup: Datos de prueba autocontenidos
DO $$
DECLARE
    v_fan UUID := 'a1000000-0000-0000-0000-000000000001';
    v_staff UUID := 'b1000000-0000-0000-0000-000000000001';
    v_admin UUID := 'c1000000-0000-0000-0000-000000000001';
BEGIN
    INSERT INTO auth.users (id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token)
    VALUES
        (v_fan, 'authenticated', 'authenticated', 'fan_analytics@test.com', crypt('Test123!', gen_salt('bf')), '{"provider":"email"}'::jsonb, '{}'::jsonb, NOW(), NOW(), ''),
        (v_staff, 'authenticated', 'authenticated', 'staff_analytics@test.com', crypt('Test123!', gen_salt('bf')), '{"provider":"email"}'::jsonb, '{}'::jsonb, NOW(), NOW(), ''),
        (v_admin, 'authenticated', 'authenticated', 'admin_analytics@test.com', crypt('Test123!', gen_salt('bf')), '{"provider":"email"}'::jsonb, '{}'::jsonb, NOW(), NOW(), '')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO profiles (id, display_name, status) VALUES
        (v_fan, 'Fan Analytics', 'active'),
        (v_staff, 'Staff Analytics', 'active'),
        (v_admin, 'Admin Analytics', 'active')
    ON CONFLICT (id) DO UPDATE SET display_name = EXCLUDED.display_name;

    INSERT INTO staff_members (user_id, role, active)
    VALUES 
        (v_staff, 'staff', true),
        (v_admin, 'admin', true)
    ON CONFLICT (user_id) DO NOTHING;
END $$;


-- TEST 1: refresh_analytics_materialized_views fails for non-admin authenticated user
DO $$
BEGIN
    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "a1000000-0000-0000-0000-000000000001", "role": "authenticated"}';

    PERFORM public.refresh_analytics_materialized_views();
    RAISE EXCEPTION 'Non-admin user should not be able to refresh materialized views';
EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE '%Acceso denegado%' OR SQLERRM LIKE '%assert_admin%' THEN
        -- OK
    ELSE
        RAISE EXCEPTION 'Unexpected error: %', SQLERRM;
    END IF;
END $$;

SELECT pass('TEST 1: refresh_analytics_materialized_views deniega ejecución a usuarios no administradores');


-- TEST 2: scan_events columns latitude and longitude exist
SELECT has_column('public', 'scan_events', 'latitude', 'TEST 2: scan_events contiene la columna latitude');
SELECT has_column('public', 'scan_events', 'longitude', 'TEST 3: scan_events contiene la columna longitude');


-- TEST 4: analytics_funnel returns valid JSON structure for admin
DO $$
DECLARE
    v_funnel JSONB;
BEGIN
    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "c1000000-0000-0000-0000-000000000001", "role": "authenticated"}';

    v_funnel := public.analytics_funnel();

    IF jsonb_array_length(v_funnel) = 4 AND (v_funnel->0->>'name') = 'Registrados' THEN
        -- OK
    ELSE
        RAISE EXCEPTION 'analytics_funnel failed: %', v_funnel;
    END IF;
END $$;

SELECT pass('TEST 4: analytics_funnel retorna la estructura de 4 pasos de cohorte unificada');

ROLLBACK;
