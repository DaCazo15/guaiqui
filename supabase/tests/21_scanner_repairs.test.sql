-- =============================================================
-- TEST SUITE: Fase 8 - Staff RPCs & Scheduled Redemption Delivery
-- =============================================================

BEGIN;
SELECT plan(3);

-- Setup: Datos de prueba autocontenidos
DO $$
DECLARE
    v_fan UUID := 'a2100000-0000-0000-0000-000000000001';
    v_staff UUID := 'b2100000-0000-0000-0000-000000000001';
    v_prod UUID := 'e2100000-0000-0000-0000-000000000001';
    v_red_sched UUID := 'd2100000-0000-0000-0000-000000000001';
BEGIN
    INSERT INTO auth.users (id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token)
    VALUES
        (v_fan, 'authenticated', 'authenticated', 'fan_staff_rep@test.com', crypt('Test123!', gen_salt('bf')), '{"provider":"email"}'::jsonb, '{}'::jsonb, NOW(), NOW(), ''),
        (v_staff, 'authenticated', 'authenticated', 'staff_staff_rep@test.com', crypt('Test123!', gen_salt('bf')), '{"provider":"email"}'::jsonb, '{}'::jsonb, NOW(), NOW(), '')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO profiles (id, display_name, status) VALUES
        (v_fan, 'Fan Staff Rep', 'active'),
        (v_staff, 'Staff Staff Rep', 'active')
    ON CONFLICT (id) DO UPDATE SET display_name = EXCLUDED.display_name;

    INSERT INTO staff_members (user_id, role, active)
    VALUES (v_staff, 'staff', true)
    ON CONFLICT (user_id) DO NOTHING;

    INSERT INTO products (id, name, category, cost_pearls, stock, active)
    VALUES (v_prod, 'Experiencia Encuentro con Jugadores', 'experience', 1500, 5, true)
    ON CONFLICT (id) DO UPDATE SET cost_pearls = 1500, stock = 5, active = true;

    INSERT INTO redemptions (id, fan_id, product_id, variant, cost_pearls, status, code_hash, idempotency_key)
    VALUES (v_red_sched, v_fan, v_prod, 'VIP', 1500, 'scheduled', compute_redemption_code_hash('SCHED123TEST'), 'idemp-sched-01')
    ON CONFLICT (id) DO NOTHING;
END $$;


-- TEST 1: deliver_redemption succeeds for scheduled status
DO $$
DECLARE
    v_res JSONB;
BEGIN
    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "b2100000-0000-0000-0000-000000000001", "role": "authenticated"}';

    v_res := public.deliver_redemption('d2100000-0000-0000-0000-000000000001'::uuid, 'idemp-deliv-sched-01', 'Entrega de experiencia agendada');

    IF v_res->>'status' = 'delivered' AND v_res->>'result' = 'DELIVERED' THEN
        -- OK
    ELSE
        RAISE EXCEPTION 'deliver_redemption failed for scheduled status: %', v_res;
    END IF;
END $$;

SELECT pass('TEST 1: deliver_redemption permite la entrega de canjes en estado scheduled');


-- TEST 2: staff_upsert_product executes cleanly for staff role
DO $$
DECLARE
    v_res JSONB;
BEGIN
    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "b2100000-0000-0000-0000-000000000001", "role": "authenticated"}';

    v_res := public.staff_upsert_product(jsonb_build_object(
        'name', 'Balón Oficial Autografiado Staff',
        'category', 'physical',
        'cost_pearls', 2000,
        'stock', 3,
        'active', true
    ));

    IF (v_res->>'success')::boolean IS TRUE THEN
        -- OK
    ELSE
        RAISE EXCEPTION 'staff_upsert_product failed: %', v_res;
    END IF;
END $$;

SELECT pass('TEST 2: staff_upsert_product ejecuta correctamente con rol de personal de staff');


-- TEST 3: staff_upsert_trivia executes cleanly for staff role
DO $$
DECLARE
    v_res JSONB;
BEGIN
    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "b2100000-0000-0000-0000-000000000001", "role": "authenticated"}';

    v_res := public.staff_upsert_trivia(jsonb_build_object(
        'title', 'Trivia de Prueba Staff',
        'description', 'Prueba de creación por staff',
        'starts_at', NOW()::text,
        'ends_at', (NOW() + INTERVAL '7 days')::text,
        'status', 'draft'
    ));

    IF (v_res->>'success')::boolean IS TRUE THEN
        -- OK
    ELSE
        RAISE EXCEPTION 'staff_upsert_trivia failed: %', v_res;
    END IF;
END $$;

SELECT pass('TEST 3: staff_upsert_trivia ejecuta correctamente con rol de personal de staff');

ROLLBACK;
