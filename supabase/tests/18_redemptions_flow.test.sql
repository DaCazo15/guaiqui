-- =============================================================
-- TEST SUITE: Fase 7 - Flujo Completo de Canje y QR (HMAC)
-- =============================================================
-- Prueba el encadenamiento completo:
-- redeem_product -> admin_approve_redemption -> get_redemption_qr -> verify_redemption_code -> deliver_redemption
-- =============================================================

BEGIN;
SELECT plan(6);

-- Setup: Datos de prueba autocontenidos
DO $$
DECLARE
    v_fan UUID := 'a7700000-0000-0000-0000-000000000001';
    v_staff UUID := 'b7700000-0000-0000-0000-000000000001';
    v_admin UUID := 'c7700000-0000-0000-0000-000000000001';
    v_prod UUID := 'e7700000-0000-0000-0000-000000000001';
BEGIN
    INSERT INTO auth.users (id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_confirmed_at)
    VALUES
        (v_fan, 'authenticated', 'authenticated', 'fan_flow@test.com', crypt('Test123!', gen_salt('bf')), '{"provider":"email"}'::jsonb, '{}'::jsonb, NOW(), NOW(), '', NOW()),
        (v_staff, 'authenticated', 'authenticated', 'staff_flow@test.com', crypt('Test123!', gen_salt('bf')), '{"provider":"email"}'::jsonb, '{}'::jsonb, NOW(), NOW(), '', NOW()),
        (v_admin, 'authenticated', 'authenticated', 'admin_flow@test.com', crypt('Test123!', gen_salt('bf')), '{"provider":"email"}'::jsonb, '{}'::jsonb, NOW(), NOW(), '', NOW())
    ON CONFLICT (id) DO UPDATE SET email_confirmed_at = NOW();

    INSERT INTO profiles (id, display_name, status, terms_accepted_at, privacy_accepted_at, pearls_rules_accepted_at) VALUES
        (v_fan, 'Fan Flow', 'active', NOW(), NOW(), NOW()),
        (v_staff, 'Staff Flow', 'active', NOW(), NOW(), NOW()),
        (v_admin, 'Admin Flow', 'active', NOW(), NOW(), NOW())
    ON CONFLICT (id) DO UPDATE SET display_name = EXCLUDED.display_name, terms_accepted_at = NOW(), privacy_accepted_at = NOW(), pearls_rules_accepted_at = NOW();

    INSERT INTO team_follows (fan_id, team_id) VALUES
        (v_fan, 'a0000000-0000-0000-0000-000000000001')
    ON CONFLICT DO NOTHING;

    INSERT INTO staff_members (user_id, team_id, role, active)
    VALUES 
        (v_staff, 'a0000000-0000-0000-0000-000000000001', 'staff', true),
        (v_admin, 'a0000000-0000-0000-0000-000000000001', 'admin', true)
    ON CONFLICT (user_id) DO UPDATE SET team_id = 'a0000000-0000-0000-0000-000000000001', role = EXCLUDED.role, active = true;

    INSERT INTO products (id, team_id, name, category, cost_pearls, stock, active)
    VALUES (v_prod, 'a0000000-0000-0000-0000-000000000001', 'Camiseta Autografiada Flow', 'physical', 500, 10, true)
    ON CONFLICT (id) DO UPDATE SET team_id = 'a0000000-0000-0000-0000-000000000001', cost_pearls = 500, stock = 10, active = true;

    INSERT INTO wallets (fan_id, team_id, balance_cache) VALUES
        (v_fan, 'a0000000-0000-0000-0000-000000000001', 2000)
    ON CONFLICT (fan_id, team_id) DO UPDATE SET balance_cache = EXCLUDED.balance_cache;

    INSERT INTO ledger_entries (fan_id, team_id, amount, type, status, source_type, source_id, note) VALUES
        (v_fan, 'a0000000-0000-0000-0000-000000000001', 2000, 'bonus', 'confirmed', 'test_flow', 'init_fan_flow', 'Saldo inicial')
    ON CONFLICT DO NOTHING;
END $$;


-- Step 1: redeem_product por el fanático
DO $$
DECLARE
    v_res JSONB;
BEGIN
    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "a7700000-0000-0000-0000-000000000001", "role": "authenticated"}';

    v_res := public.redeem_product('e7700000-0000-0000-0000-000000000001'::uuid, 'L', 'key-flow-test-01');

    IF v_res->>'status' = 'pending' AND (v_res->>'redemption_id') IS NOT NULL THEN
        -- OK
    ELSE
        RAISE EXCEPTION 'redeem_product failed: %', v_res;
    END IF;
END $$;

SELECT pass('Paso 1: Fanático ejecuta redeem_product exitosamente (estado pending)');


-- Step 2: admin_approve_redemption por el administrador
DO $$
DECLARE
    v_red_id UUID;
    v_res JSONB;
BEGIN
    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "c7700000-0000-0000-0000-000000000001", "role": "authenticated", "aal": "aal2"}';

    SELECT id INTO v_red_id FROM redemptions WHERE fan_id = 'a7700000-0000-0000-0000-000000000001' AND idempotency_key = 'key-flow-test-01';
    
    v_res := public.admin_approve_redemption(v_red_id, 'Aprobado en test de integración');

    IF v_res->>'status' = 'approved' THEN
        -- OK
    ELSE
        RAISE EXCEPTION 'admin_approve_redemption failed: %', v_res;
    END IF;
END $$;

SELECT pass('Paso 2: Administrador aprueba el canje (estado approved)');


-- Step 3: get_redemption_qr por el fanático (Obtiene código QR opaco)
DO $$
DECLARE
    v_red_id UUID;
    v_qr_res JSONB;
    v_code TEXT;
BEGIN
    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "a7700000-0000-0000-0000-000000000001", "role": "authenticated"}';

    SELECT id INTO v_red_id FROM redemptions WHERE fan_id = 'a7700000-0000-0000-0000-000000000001' AND idempotency_key = 'key-flow-test-01';

    v_qr_res := public.get_redemption_qr(v_red_id);
    v_code := COALESCE(v_qr_res->>'code', v_qr_res->>'redemption_code');

    IF v_code IS NOT NULL AND length(v_code) = 12 THEN
        -- OK
    ELSE
        RAISE EXCEPTION 'get_redemption_qr failed: %', v_qr_res;
    END IF;
END $$;

SELECT pass('Paso 3: Fanático obtiene su código QR HMAC opaco de 12 caracteres');


-- Step 4: verify_redemption_code por el personal de staff usando el código QR
DO $$
DECLARE
    v_red_id UUID;
    v_qr_res JSONB;
    v_code TEXT;
    v_verify_res JSONB;
BEGIN
    -- Fan obtiene el código
    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "a7700000-0000-0000-0000-000000000001", "role": "authenticated"}';
    SELECT id INTO v_red_id FROM redemptions WHERE fan_id = 'a7700000-0000-0000-0000-000000000001' AND idempotency_key = 'key-flow-test-01';
    v_qr_res := public.get_redemption_qr(v_red_id);
    v_code := COALESCE(v_qr_res->>'code', v_qr_res->>'redemption_code');

    -- Staff verifica el código
    SET LOCAL "request.jwt.claims" = '{"sub": "b7700000-0000-0000-0000-000000000001", "role": "authenticated"}';
    v_verify_res := public.verify_redemption_code(v_code);

    IF (v_verify_res->>'result' = 'OK_APPROVED' OR v_verify_res->>'valid' = 'true') AND v_verify_res->>'redemption_id' = v_red_id::text THEN
        -- OK
    ELSE
        RAISE EXCEPTION 'verify_redemption_code failed: %', v_verify_res;
    END IF;
END $$;

SELECT pass('Paso 4: Staff escanea y verifica el código QR HMAC exitosamente');


-- Step 5: deliver_redemption por el staff
DO $$
DECLARE
    v_red_id UUID;
    v_qr_res JSONB;
    v_code TEXT;
    v_deliver_res JSONB;
BEGIN
    -- Fan obtiene código
    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "a7700000-0000-0000-0000-000000000001", "role": "authenticated"}';
    SELECT id INTO v_red_id FROM redemptions WHERE fan_id = 'a7700000-0000-0000-0000-000000000001' AND idempotency_key = 'key-flow-test-01';
    v_qr_res := public.get_redemption_qr(v_red_id);
    v_code := v_qr_res->>'redemption_code';

    -- Staff entrega el premio
    SET LOCAL "request.jwt.claims" = '{"sub": "b7700000-0000-0000-0000-000000000001", "role": "authenticated"}';
    v_deliver_res := public.deliver_redemption(v_code, 'Entregado en tienda física');

    IF v_deliver_res->>'status' = 'delivered' THEN
        -- OK
    ELSE
        RAISE EXCEPTION 'deliver_redemption failed: %', v_deliver_res;
    END IF;
END $$;

SELECT pass('Paso 5: Staff entrega el premio (estado delivered)');


-- Step 6: Verificar estado final en base de datos
SELECT is(
    (SELECT status FROM redemptions WHERE idempotency_key = 'key-flow-test-01'),
    'delivered',
    'Paso 6: Estado final del canje en la tabla redemptions es delivered'
);

ROLLBACK;
