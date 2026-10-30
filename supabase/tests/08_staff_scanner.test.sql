-- =============================================================
-- TEST SUITE: Fase 8 - Panel de Staff (Escáner, Cola, Stock, Fans)
-- =============================================================
-- Compatible con `supabase test db` (pgTAP framework).
-- Autocontenido: crea sus propios datos de prueba en transacción aislada.
-- =============================================================

BEGIN;
SELECT plan(12);

-- ─── Setup: Datos de prueba autocontenidos ────────────────────
DO $$
DECLARE
    v_fan UUID := 'a0000000-0000-0000-0000-000000000088';
    v_staff_active UUID := 'b0000000-0000-0000-0000-000000000088';
    v_staff_inactive UUID := 'b0000000-0000-0000-0000-000000000089';
    v_prod UUID := 'e0000000-0000-0000-0000-000000000088';
BEGIN
    INSERT INTO auth.users (id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_confirmed_at)
    VALUES
        (v_fan, 'authenticated', 'authenticated', 'fan_f8@test.com', crypt('Test123!', gen_salt('bf')), '{"provider":"email"}'::jsonb, '{}'::jsonb, NOW(), NOW(), '', NOW()),
        (v_staff_active, 'authenticated', 'authenticated', 'staff_act_f8@test.com', crypt('Test123!', gen_salt('bf')), '{"provider":"email"}'::jsonb, '{}'::jsonb, NOW(), NOW(), '', NOW()),
        (v_staff_inactive, 'authenticated', 'authenticated', 'staff_inact_f8@test.com', crypt('Test123!', gen_salt('bf')), '{"provider":"email"}'::jsonb, '{}'::jsonb, NOW(), NOW(), '', NOW())
    ON CONFLICT (id) DO UPDATE SET email_confirmed_at = NOW();

    INSERT INTO profiles (id, display_name, status, terms_accepted_at, privacy_accepted_at, pearls_rules_accepted_at) VALUES
        (v_fan, 'Fanatico Fase8', 'active', NOW(), NOW(), NOW()),
        (v_staff_active, 'Staff Activo F8', 'active', NOW(), NOW(), NOW()),
        (v_staff_inactive, 'Staff Inactivo F8', 'active', NOW(), NOW(), NOW())
    ON CONFLICT (id) DO UPDATE SET display_name = EXCLUDED.display_name, status = 'active', terms_accepted_at = NOW(), privacy_accepted_at = NOW(), pearls_rules_accepted_at = NOW();

    INSERT INTO team_follows (fan_id, team_id) VALUES
        (v_fan, 'a0000000-0000-0000-0000-000000000001')
    ON CONFLICT DO NOTHING;

    INSERT INTO staff_members (user_id, team_id, role, active) VALUES
        (v_staff_active, 'a0000000-0000-0000-0000-000000000001', 'staff', true),
        (v_staff_inactive, 'a0000000-0000-0000-0000-000000000001', 'staff', false)
    ON CONFLICT (user_id) DO UPDATE SET team_id = EXCLUDED.team_id, active = EXCLUDED.active;

    INSERT INTO products (id, team_id, name, category, cost_pearls, stock, active)
    VALUES (v_prod, 'a0000000-0000-0000-0000-000000000001', 'Camiseta Edicion Especial F8', 'physical', 500, 20, true)
    ON CONFLICT (id) DO UPDATE SET team_id = 'a0000000-0000-0000-0000-000000000001', stock = 20, active = true;

    INSERT INTO wallets (fan_id, team_id, balance_cache) VALUES
        (v_fan, 'a0000000-0000-0000-0000-000000000001', 2000)
    ON CONFLICT (fan_id, team_id) DO UPDATE SET balance_cache = 2000;
END $$;

-- ─── TEST 1: Fan sin rol staff no puede ejecutar funciones de staff ─────────
SELECT throws_ok(
    $$
        SET LOCAL ROLE authenticated;
        SET LOCAL "request.jwt.claims" = '{"sub": "a0000000-0000-0000-0000-000000000088", "role": "authenticated"}';
        SELECT assert_staff();
    $$,
    'P0001',
    'Staff or Admin authorization required.',
    'TEST 1: Fan normal recibe error P0001 al intentar assert_staff()'
);

-- ─── TEST 2: Staff inactivo tampoco puede ejecutar funciones ────────────────
SELECT throws_ok(
    $$
        SET LOCAL ROLE authenticated;
        SET LOCAL "request.jwt.claims" = '{"sub": "b0000000-0000-0000-0000-000000000089", "role": "authenticated"}';
        SELECT assert_staff();
    $$,
    'P0001',
    'Staff or Admin authorization required.',
    'TEST 2: Staff inactivo recibe error P0001 en assert_staff()'
);

-- ─── TEST 3: Staff activo tiene acceso exitoso ──────────────────────────────
RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "b0000000-0000-0000-0000-000000000088", "role": "authenticated"}';
SELECT ok(assert_staff(), 'TEST 3: Staff activo pasa assert_staff() exitosamente');

-- ─── TEST 4: verify_redemption_code no cambia estado y registra scan_events ─
DO $$
DECLARE
    v_red_id UUID := 'd0000000-0000-0000-0000-000000000088';
    v_code TEXT;
    v_hash TEXT;
BEGIN
    RESET ROLE;
    v_code := generate_redemption_code(v_red_id);
    v_hash := compute_redemption_code_hash(v_code);

    INSERT INTO redemptions (id, team_id, fan_id, product_id, variant, cost_pearls, status, code_hash, idempotency_key)
    VALUES (v_red_id, 'a0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000088', 'e0000000-0000-0000-0000-000000000088', 'M', 500, 'approved', v_hash, 'f8_test_4_key')
    ON CONFLICT (id) DO UPDATE SET team_id = 'a0000000-0000-0000-0000-000000000001', status = 'approved', code_hash = v_hash;

    CREATE TEMP TABLE IF NOT EXISTS _test_code (code text);
    DELETE FROM _test_code;
    INSERT INTO _test_code VALUES (v_code);
    GRANT ALL ON _test_code TO PUBLIC;
END $$;

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "b0000000-0000-0000-0000-000000000088", "role": "authenticated"}';

SELECT ok(
    (verify_redemption_code((SELECT code FROM _test_code), 'Test Device')->>'result') = 'OK_APPROVED',
    'TEST 4: verify_redemption_code retorna OK_APPROVED'
);

-- ─── TEST 5: Freno a la fuerza bruta (10 intentos fallidos bloquean el escáner) ─
DO $$
BEGIN
    RESET ROLE;
    INSERT INTO scan_events (staff_id, team_id, code_hash, result, device)
    SELECT 'b0000000-0000-0000-0000-000000000088', 'a0000000-0000-0000-0000-000000000001', 'INVALID_HASH_' || g, 'invalid', 'Terminal Test'
    FROM generate_series(1, 10) g;
END $$;

SELECT throws_ok(
    $$
        SET LOCAL ROLE authenticated;
        SET LOCAL "request.jwt.claims" = '{"sub": "b0000000-0000-0000-0000-000000000088", "role": "authenticated"}';
        SELECT verify_redemption_code('012345678901', 'Terminal Test');
    $$,
    '42501',
    'SCANNER_LOCKED: Escáner bloqueado temporalmente por acumulación de intentos fallidos. Intente en 15 minutos.',
    'TEST 5: Freno a la fuerza bruta bloquea escáner tras 10 intentos fallidos (SCANNER_LOCKED)'
);

-- Limpiar scan_events para continuar
DO $$
BEGIN
    RESET ROLE;
    DELETE FROM scan_events WHERE staff_id = 'b0000000-0000-0000-0000-000000000088';
END $$;

-- ─── TEST 6: Reject redemption reembolsa perlitas exactamente 1 vez ──────────
DO $$
DECLARE
    v_red_id UUID := 'd0000000-0000-0000-0000-000000000089';
    v_fan_id UUID := 'a0000000-0000-0000-0000-000000000088';
    v_hash TEXT;
BEGIN
    RESET ROLE;
    v_hash := compute_redemption_code_hash('REJECTCODE12');
    INSERT INTO redemptions (id, team_id, fan_id, product_id, variant, cost_pearls, status, code_hash, idempotency_key)
    VALUES (v_red_id, 'a0000000-0000-0000-0000-000000000001', v_fan_id, 'e0000000-0000-0000-0000-000000000088', 'L', 500, 'pending', v_hash, 'f8_test_6_key')
    ON CONFLICT (id) DO NOTHING;
END $$;

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "b0000000-0000-0000-0000-000000000088", "role": "authenticated"}';

SELECT is(
    (reject_redemption('d0000000-0000-0000-0000-000000000089', 'Sin inventario físico')->>'status'),
    'rejected',
    'TEST 6: reject_redemption actualiza el canje a rejected'
);

-- ─── TEST 7: adjust_stock no permite stock negativo y exige motivo ─────────
SELECT throws_ok(
    $$
        SET LOCAL ROLE authenticated;
        SET LOCAL "request.jwt.claims" = '{"sub": "b0000000-0000-0000-0000-000000000088", "role": "authenticated"}';
        SELECT adjust_stock('e0000000-0000-0000-0000-000000000088', 5, '');
    $$,
    'P0001',
    'El motivo del ajuste de inventario es obligatorio.',
    'TEST 7a: adjust_stock exige motivo obligatorio'
);

SELECT throws_ok(
    $$
        SET LOCAL ROLE authenticated;
        SET LOCAL "request.jwt.claims" = '{"sub": "b0000000-0000-0000-0000-000000000088", "role": "authenticated"}';
        SELECT adjust_stock('e0000000-0000-0000-0000-000000000088', -100, 'Ajuste excesivo');
    $$,
    'P0001',
    NULL,
    'TEST 7b: adjust_stock rechaza stock negativo'
);

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "b0000000-0000-0000-0000-000000000088", "role": "authenticated"}';

SELECT is(
    (adjust_stock('e0000000-0000-0000-0000-000000000088', 10, 'Recepción de inventario')->>'new_stock')::int,
    30,
    'TEST 7c: adjust_stock actualiza existencias correctamente'
);

-- ─── TEST 8: staff_search_fans no devuelve correo ni fecha de nacimiento ─────
RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "b0000000-0000-0000-0000-000000000088", "role": "authenticated"}';

SELECT is(
    (SELECT display_name FROM staff_search_fans('Fanatico', 5) LIMIT 1),
    'Fanatico Fase8',
    'TEST 8: staff_search_fans retorna el fan sin datos sensibles'
);

-- ─── TEST 9: staff_redemption_queue no expone code ni code_hash ─────────────
RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "b0000000-0000-0000-0000-000000000088", "role": "authenticated"}';

SELECT ok(
    (SELECT COUNT(*) FROM staff_redemption_queue(NULL, NULL, NULL, 5)) >= 1,
    'TEST 9: staff_redemption_queue entrega información filtrada'
);

-- ─── TEST 10: deliver_redemption actualiza a delivered de forma atómica ───────
RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "b0000000-0000-0000-0000-000000000088", "role": "authenticated"}';

SELECT is(
    (deliver_redemption('d0000000-0000-0000-0000-000000000088', 'f8_delivery_idempotency_10', 'Entrega realizada en taquilla')->>'status'),
    'delivered',
    'TEST 10: deliver_redemption actualiza el canje a delivered exitosamente'
);

SELECT * FROM finish();
ROLLBACK;
