-- =============================================================
-- TEST SUITE: Fase 11 - Append-Only Hold Resolutions & Ledger Invariance
-- =============================================================
-- Pruebas de la arquitectura append-only de resoluciones de perlitas retenidas:
-- 1. Direct UPDATE and DELETE operations on ledger_entries fail (immutable trigger)
-- 2. admin_release_held_pearls creates resolution + new confirmed ledger entry, and maintains balance_cache = SUM(confirmed)
-- 3. Cannot release or revoke a held entry twice (uniqueness constraint)
-- 4. admin_revoke_held_pearls creates resolution without modifying wallet
-- =============================================================

BEGIN;
SELECT plan(6);

-- Setup: Datos de prueba autocontenidos
DO $$
DECLARE
    v_fan UUID := 'a9900000-0000-0000-0000-000000000001';
    v_admin UUID := 'c9900000-0000-0000-0000-000000000001';
    v_held1 UUID := 'd9900000-0000-0000-0000-000000000001';
    v_held2 UUID := 'd9900000-0000-0000-0000-000000000002';
BEGIN
    INSERT INTO auth.users (id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token)
    VALUES
        (v_fan, 'authenticated', 'authenticated', 'fan_hold@test.com', crypt('Test123!', gen_salt('bf')), '{"provider":"email"}'::jsonb, '{}'::jsonb, NOW(), NOW(), ''),
        (v_admin, 'authenticated', 'authenticated', 'admin_hold@test.com', crypt('Test123!', gen_salt('bf')), '{"provider":"email"}'::jsonb, '{}'::jsonb, NOW(), NOW(), '')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO profiles (id, display_name, status) VALUES
        (v_fan, 'Fan Hold', 'active'),
        (v_admin, 'Admin Hold', 'active')
    ON CONFLICT (id) DO UPDATE SET display_name = EXCLUDED.display_name;

    INSERT INTO staff_members (user_id, role, active)
    VALUES (v_admin, 'admin', true)
    ON CONFLICT (user_id) DO NOTHING;

    INSERT INTO wallets (fan_id, balance_cache) VALUES
        (v_fan, 0)
    ON CONFLICT (fan_id) DO UPDATE SET balance_cache = EXCLUDED.balance_cache;

    INSERT INTO ledger_entries (id, fan_id, amount, type, status, source_type, source_id, note) VALUES
        (v_held1, v_fan, 300, 'trivia_reward', 'held', 'trivia_attempt', 'att-1', 'Premio retenido por velocidad implausible 1'),
        (v_held2, v_fan, 500, 'trivia_reward', 'held', 'trivia_attempt', 'att-2', 'Premio retenido por velocidad implausible 2')
    ON CONFLICT (id) DO NOTHING;
END $$;


-- TEST 1: Direct UPDATE on ledger_entries MUST FAIL
DO $$
BEGIN
    UPDATE public.ledger_entries SET note = 'Modificacion directa' WHERE id = 'd9900000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'UPDATE operation should have been blocked by trigger';
EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE '%Financial Ledger entries are immutable%' THEN
        -- OK
    ELSE
        RAISE EXCEPTION 'Unexpected error message: %', SQLERRM;
    END IF;
END $$;

SELECT pass('TEST 1: UPDATE directo sobre ledger_entries falla por el trigger de inmutabilidad');


-- TEST 2: Direct DELETE on ledger_entries MUST FAIL
DO $$
BEGIN
    DELETE FROM public.ledger_entries WHERE id = 'd9900000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'DELETE operation should have been blocked by trigger';
EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE '%Financial Ledger entries are immutable%' THEN
        -- OK
    ELSE
        RAISE EXCEPTION 'Unexpected error message: %', SQLERRM;
    END IF;
END $$;

SELECT pass('TEST 2: DELETE directo sobre ledger_entries falla por el trigger de inmutabilidad');


-- TEST 3: admin_release_held_pearls appends resolution + confirmed entry, maintaining balance_cache = SUM(confirmed)
DO $$
DECLARE
    v_res JSONB;
    v_bal INT;
    v_reconcile_count INT;
BEGIN
    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "c9900000-0000-0000-0000-000000000001", "role": "authenticated"}';

    v_res := public.admin_release_held_pearls('d9900000-0000-0000-0000-000000000001'::uuid, 'Verificado por auditoría de video');

    SELECT balance_cache INTO v_bal FROM wallets WHERE fan_id = 'a9900000-0000-0000-0000-000000000001';
    SELECT COUNT(*) INTO v_reconcile_count FROM public.reconcile_wallets() WHERE fan_id = 'a9900000-0000-0000-0000-000000000001';

    IF v_res->>'status' = 'released' AND v_bal = 300 AND v_reconcile_count = 0 THEN
        -- OK
    ELSE
        RAISE EXCEPTION 'admin_release_held_pearls failed: res=%, balance=%, reconcile_mismatches=%', v_res, v_bal, v_reconcile_count;
    END IF;
END $$;

SELECT pass('TEST 3: admin_release_held_pearls libera perlitas mediante append-only y mantiene la billetera reconciliada');


-- TEST 4: Cannot release or revoke the same held entry twice
DO $$
DECLARE
    v_res JSONB;
BEGIN
    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "c9900000-0000-0000-0000-000000000001", "role": "authenticated"}';

    v_res := public.admin_release_held_pearls('d9900000-0000-0000-0000-000000000001'::uuid, 'Intento redundante');
    RAISE EXCEPTION 'Second release should have failed';
EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE '%ya ha sido resuelto previamente%' THEN
        -- OK
    ELSE
        RAISE EXCEPTION 'Unexpected error on double release: %', SQLERRM;
    END IF;
END $$;

SELECT pass('TEST 4: No se puede liberar ni revocar un registro retenido más de una vez (unicidad en ledger_hold_resolutions)');


-- TEST 5: admin_revoke_held_pearls inserts resolution without modifying wallet balance
DO $$
DECLARE
    v_res JSONB;
    v_bal INT;
BEGIN
    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "c9900000-0000-0000-0000-000000000001", "role": "authenticated"}';

    v_res := public.admin_revoke_held_pearls('d9900000-0000-0000-0000-000000000002'::uuid, 'Fraude confirmado en auditoría');

    SELECT balance_cache INTO v_bal FROM wallets WHERE fan_id = 'a9900000-0000-0000-0000-000000000001';

    IF v_res->>'status' = 'revoked' AND v_bal = 300 THEN
        -- OK balance remained 300 from previous release
    ELSE
        RAISE EXCEPTION 'admin_revoke_held_pearls failed: res=%, balance=%', v_res, v_bal;
    END IF;
END $$;

SELECT pass('TEST 5: admin_revoke_held_pearls revoca la entrada retenida sin alterar el saldo de la billetera');


-- TEST 6: Verify pending held pearls calculation in wallet_summary
DO $$
DECLARE
    v_summary JSONB;
BEGIN
    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "a9900000-0000-0000-0000-000000000001", "role": "authenticated"}';

    v_summary := public.wallet_summary();

    -- Both held1 (released) and held2 (revoked) are resolved, so pending held_pearls must be 0
    IF (v_summary->>'held_pearls')::int = 0 AND (v_summary->>'balance')::int = 300 THEN
        -- OK
    ELSE
        RAISE EXCEPTION 'wallet_summary calculation error: %', v_summary;
    END IF;
END $$;

SELECT pass('TEST 6: wallet_summary calcula 0 perlitas retenidas pendientes tras resolver ambas entradas');

ROLLBACK;
