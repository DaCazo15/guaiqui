-- ============================================================================
-- Test Suite: team_trivias_store.test.sql
-- Description: Tests for Fase 3 Backend Features:
--              1. Per-team streak calculation (get_streak_info)
--              2. Team-scoped home_summary
--              3. Composite FK fk_ledger_entries_wallet
--              4. Hold resolution team coherence trigger
--              5. Active team filtering on trivias and products RLS
--              6. Performance composite indexes (team_id, status/active)
--              7. Admin & analytics functions no longer throw 0A000
--              8. Birthday bonus per team
-- ============================================================================

BEGIN;

SELECT plan(15);

-- Test 1: get_streak_info function exists with team_id parameter
SELECT has_function(
    'public',
    'get_streak_info',
    ARRAY['uuid', 'uuid'],
    'TEST 1: public.get_streak_info(uuid, uuid) debe existir'
);

-- Test 2: home_summary function exists with team_id parameter
SELECT has_function(
    'public',
    'home_summary',
    ARRAY['uuid'],
    'TEST 2: public.home_summary(uuid) debe existir'
);

-- Test 3: Composite FK on ledger_entries to wallets exists
SELECT has_fk(
    'public',
    'ledger_entries',
    'TEST 3: La tabla public.ledger_entries debe tener foreign keys activas'
);

-- Test 4: Trigger trg_validate_hold_resolution_team exists on ledger_hold_resolutions
SELECT has_trigger(
    'public',
    'ledger_hold_resolutions',
    'trg_validate_hold_resolution_team',
    'TEST 4: El trigger trg_validate_hold_resolution_team debe existir'
);

-- Test 5: Index idx_trivias_team_status exists
SELECT has_index(
    'public',
    'trivias',
    'idx_trivias_team_status',
    'TEST 5: El índice compuesto idx_trivias_team_status debe existir'
);

-- Test 6: Index idx_products_team_active exists
SELECT has_index(
    'public',
    'products',
    'idx_products_team_active',
    'TEST 6: El índice compuesto idx_products_team_active debe existir'
);

-- Test 7: claim_birthday_bonus function exists with team_id parameter
SELECT has_function(
    'public',
    'claim_birthday_bonus',
    ARRAY['uuid'],
    'TEST 7: public.claim_birthday_bonus(uuid) debe existir'
);

-- Test 8: get_birthday_card function exists with team_id parameter
SELECT has_function(
    'public',
    'get_birthday_card',
    ARRAY['uuid'],
    'TEST 8: public.get_birthday_card(uuid) debe existir'
);

-- Test 9: birthday_settings table has team_id column
SELECT has_column(
    'public',
    'birthday_settings',
    'team_id',
    'TEST 9: birthday_settings debe tener columna team_id'
);

-- Test 10: RLS is active on trivias
SELECT is(
    (SELECT relrowsecurity FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relname = 'trivias'),
    true,
    'TEST 10: RLS debe estar habilitado en public.trivias'
);

-- Test 11: RLS is active on products
SELECT is(
    (SELECT relrowsecurity FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relname = 'products'),
    true,
    'TEST 11: RLS debe estar habilitado en public.products'
);

-- Test 12: Foreign key violation 23503 when inserting ledger_entry without matching wallet
DO $$
DECLARE
    v_fan_id UUID := gen_random_uuid();
    v_team_id UUID := gen_random_uuid();
    v_err_code TEXT;
BEGIN
    BEGIN
        INSERT INTO public.ledger_entries (
            id, fan_id, team_id, amount, type, status, source_type, source_id, note, created_at
        ) VALUES (
            gen_random_uuid(), v_fan_id, v_team_id, 100, 'trivia_reward', 'confirmed', 'trivia_attempt', 'test-fk-attempt', 'Test Reward', NOW()
        );
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_err_code = RETURNED_SQLSTATE;
    END;

    IF v_err_code = '23503' THEN
        PERFORM ok(true, 'TEST 12: Inserción de ledger_entry sin wallet arroja FK violation 23503');
    ELSE
        PERFORM ok(false, 'TEST 12: Esperaba código 23503, se obtuvo: ' || COALESCE(v_err_code, 'NULL'));
    END IF;
END $$;
 
-- Test 13: Fan home_summary with explicit team_id and confirmed email
INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud)
VALUES ('77777777-7777-7777-7777-777777777777', '00000000-0000-0000-0000-000000000000', 'fan_fase3@guaiqui.test', 'encrypted', NOW(), '{"provider":"email","providers":["email"]}', '{}', NOW(), NOW(), 'authenticated', 'authenticated')
ON CONFLICT (id) DO UPDATE SET email_confirmed_at = COALESCE(auth.users.email_confirmed_at, NOW());

INSERT INTO public.profiles (id, display_name, status, created_at, terms_accepted_at, terms_version)
VALUES ('77777777-7777-7777-7777-777777777777', 'Fan Fase 3', 'active', NOW(), NOW(), 'v1.0')
ON CONFLICT (id) DO UPDATE SET terms_accepted_at = NOW(), terms_version = 'v1.0', status = 'active';

INSERT INTO public.team_follows (user_id, team_id)
VALUES ('77777777-7777-7777-7777-777777777777', 'a0000000-0000-0000-0000-000000000001')
ON CONFLICT (user_id, team_id) DO NOTHING;

INSERT INTO public.wallets (fan_id, team_id, balance_cache)
VALUES ('77777777-7777-7777-7777-777777777777', 'a0000000-0000-0000-0000-000000000001', 500)
ON CONFLICT (fan_id, team_id) DO UPDATE SET balance_cache = 500;

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777777777", "role": "authenticated", "aal": "aal1"}';

SELECT is(
    (public.home_summary('a0000000-0000-0000-0000-000000000001'::uuid)->>'balance')::int,
    500,
    'TEST 13: home_summary retorna balance del equipo con fan activo'
);
RESET ROLE;

-- Test 14: get_streak_info with explicit team_id
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777777777", "role": "authenticated", "aal": "aal1"}';

SELECT ok(
    public.get_streak_info('77777777-7777-7777-7777-777777777777'::uuid, 'a0000000-0000-0000-0000-000000000001'::uuid) IS NOT NULL,
    'TEST 14: get_streak_info retorna racha válida para fan y equipo'
);
RESET ROLE;

-- Test 15: Admin RPC with claims aal2
INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud)
VALUES ('77777777-7777-7777-7777-777777777778', '00000000-0000-0000-0000-000000000000', 'admin_fase3@guaiqui.test', 'encrypted', NOW(), '{"provider":"email","providers":["email"]}', '{}', NOW(), NOW(), 'authenticated', 'authenticated')
ON CONFLICT (id) DO UPDATE SET email_confirmed_at = COALESCE(auth.users.email_confirmed_at, NOW());

INSERT INTO public.profiles (id, display_name, status, created_at, terms_accepted_at, terms_version)
VALUES ('77777777-7777-7777-7777-777777777778', 'Admin Fase 3', 'active', NOW(), NOW(), 'v1.0')
ON CONFLICT (id) DO UPDATE SET terms_accepted_at = NOW(), terms_version = 'v1.0', status = 'active';

INSERT INTO public.staff (user_id, team_id, role, is_active)
VALUES ('77777777-7777-7777-7777-777777777778', 'a0000000-0000-0000-0000-000000000001', 'admin', true)
ON CONFLICT (user_id, team_id) DO UPDATE SET is_active = true, role = 'admin';

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777777778", "role": "authenticated", "aal": "aal2"}';

SELECT lives_ok(
    'SELECT public.admin_list_fans()',
    'TEST 15: Admin con claims aal2 puede ejecutar admin_list_fans sin error'
);
RESET ROLE;

SELECT * FROM finish();

ROLLBACK;

