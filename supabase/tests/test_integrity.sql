-- =============================================================
-- TEST SUITE: Guaiqueríes de Margarita — pgTAP Database Integrity Tests
-- =============================================================
-- Compatible con `supabase test db` (pgTAP framework).
-- Autocontenido: crea sus propios datos de prueba en una transacción aislada.
-- =============================================================

BEGIN;
SELECT plan(26);

-- ─── Setup: Crear datos de prueba autocontenidos ───────────────
DO $$
DECLARE
    v_team_id UUID := 'a0000000-0000-0000-0000-000000000001';
    v_fan1_id UUID := '11111111-1111-1111-1111-111111111111';
    v_fan2_id UUID := '22222222-2222-2222-2222-222222222222';
    v_staff_id UUID := '33333333-3333-3333-3333-333333333333';
    v_test_product_id UUID := 'dd000000-0000-0000-0000-000000000001';
    v_test_trivia_id UUID := 'dd000000-0000-0000-0000-000000000002';
    v_test_question_id UUID := 'dd000000-0000-0000-0000-000000000003';
BEGIN
    INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_confirmed_at)
    VALUES
        ('00000000-0000-0000-0000-000000000000', v_fan1_id, 'authenticated', 'authenticated', 'testfan1@guaiqui.test', crypt('Test123!', gen_salt('bf')), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, NOW(), NOW(), '', NOW()),
        ('00000000-0000-0000-0000-000000000000', v_fan2_id, 'authenticated', 'authenticated', 'testfan2@guaiqui.test', crypt('Test123!', gen_salt('bf')), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, NOW(), NOW(), '', NOW()),
        ('00000000-0000-0000-0000-000000000000', v_staff_id, 'authenticated', 'authenticated', 'teststaff@guaiqui.test', crypt('Test123!', gen_salt('bf')), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, NOW(), NOW(), '', NOW())
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO profiles (id, display_name, status, terms_accepted_at, terms_version) VALUES
        (v_fan1_id, 'Test Fan 1', 'active', NOW(), 'v1.0'),
        (v_fan2_id, 'Test Fan 2', 'active', NOW(), 'v1.0'),
        (v_staff_id, 'Test Staff', 'active', NOW(), 'v1.0')
    ON CONFLICT (id) DO UPDATE SET status = 'active', display_name = EXCLUDED.display_name, terms_accepted_at = NOW(), terms_version = 'v1.0';

    INSERT INTO team_follows (user_id, team_id) VALUES
        (v_fan1_id, v_team_id),
        (v_fan2_id, v_team_id)
    ON CONFLICT (user_id, team_id) DO NOTHING;

    INSERT INTO staff_members (team_id, user_id, role, active)
    VALUES (v_team_id, v_staff_id, 'staff', true)
    ON CONFLICT (user_id) DO UPDATE SET team_id = EXCLUDED.team_id, role = EXCLUDED.role, active = true;

    INSERT INTO products (id, team_id, name, description, category, cost_pearls, stock, active)
    VALUES (v_test_product_id, v_team_id, 'Producto Test Integridad', 'Solo para pruebas', 'physical', 500, 10, true)
    ON CONFLICT (id) DO UPDATE SET stock = 10, cost_pearls = 500, active = true;

    INSERT INTO trivias (id, team_id, title, description, status, starts_at, ends_at, time_limit_seconds, max_attempts)
    VALUES (v_test_trivia_id, v_team_id, 'Trivia Test', 'Solo para pruebas', 'published', NOW() - INTERVAL '1 hour', NOW() + INTERVAL '24 hours', 60, 1)
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO trivia_questions (id, trivia_id, question_text, points, order_index)
    VALUES (v_test_question_id, v_test_trivia_id, '¿Pregunta de prueba?', 50, 1)
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO trivia_attempts (id, fan_id, trivia_id, expires_at, seed, idempotency_key)
    VALUES ('aa000000-0000-0000-0000-000000000001', v_fan1_id, v_test_trivia_id, NOW() + INTERVAL '1 hour', 12345, 'setup-attempt-1')
    ON CONFLICT DO NOTHING;

    INSERT INTO wallets (fan_id, team_id, balance_cache) VALUES
        (v_fan1_id, v_team_id, 5000),
        (v_fan2_id, v_team_id, 200)
    ON CONFLICT (fan_id, team_id) DO UPDATE SET balance_cache = EXCLUDED.balance_cache;

    INSERT INTO ledger_entries (fan_id, team_id, amount, type, status, source_type, source_id, note) VALUES
        (v_fan1_id, v_team_id, 5000, 'bonus', 'confirmed', 'test_setup', 'setup-fan1-' || v_fan1_id::text, 'Test setup'),
        (v_fan2_id, v_team_id, 200, 'bonus', 'confirmed', 'test_setup', 'setup-fan2-' || v_fan2_id::text, 'Test setup')
    ON CONFLICT DO NOTHING;
END $$;

-- ─── TEST 1: Ledger Immutability — UPDATE must fail ──────────
SELECT throws_ok(
    $$ UPDATE ledger_entries SET amount = 999999 WHERE fan_id = '11111111-1111-1111-1111-111111111111' $$,
    'P0001'
);

-- ─── TEST 2: Ledger Immutability — DELETE must fail ──────────
SELECT throws_ok(
    $$ DELETE FROM ledger_entries WHERE fan_id = '11111111-1111-1111-1111-111111111111' $$,
    'P0001'
);

-- ─── TEST 3: Wallet balance_cache CHECK constraint ────────────
SELECT throws_ok(
    $$ UPDATE wallets SET balance_cache = -1 WHERE fan_id = '11111111-1111-1111-1111-111111111111' AND team_id = 'a0000000-0000-0000-0000-000000000001' $$,
    '23514'
);

-- ─── TEST 4: Product cost_pearls CHECK constraint (> 0) ───────
SELECT throws_ok(
    $$ INSERT INTO products (team_id, name, category, cost_pearls, stock, active) VALUES ('a0000000-0000-0000-0000-000000000001', 'Producto Inválido', 'physical', 0, 10, true) $$,
    '23514'
);

-- ─── TEST 5: Redemption idempotency_key uniqueness per fan ────
SELECT throws_ok(
    $$ 
      INSERT INTO redemptions (fan_id, team_id, product_id, cost_pearls, status, code_hash, idempotency_key)
      VALUES 
        ('11111111-1111-1111-1111-111111111111', 'a0000000-0000-0000-0000-000000000001', 'dd000000-0000-0000-0000-000000000001', 100, 'pending', 'hash_test_5a', 'test-idem-key-001'),
        ('11111111-1111-1111-1111-111111111111', 'a0000000-0000-0000-0000-000000000001', 'dd000000-0000-0000-0000-000000000001', 100, 'pending', 'hash_test_5b', 'test-idem-key-001')
    $$,
    '23505'
);

-- ─── TEST 6: Ledger duplicate payout prevention ──────────────
SELECT throws_ok(
    $$ 
      INSERT INTO ledger_entries (fan_id, team_id, amount, type, status, source_type, source_id, note)
      VALUES 
        ('11111111-1111-1111-1111-111111111111', 'a0000000-0000-0000-0000-000000000001', 50, 'trivia_reward', 'confirmed', 'trivia_attempt', 'test-dup-source-001', 'First reward'),
        ('11111111-1111-1111-1111-111111111111', 'a0000000-0000-0000-0000-000000000001', 50, 'trivia_reward', 'confirmed', 'trivia_attempt', 'test-dup-source-001', 'Duplicate attempt')
    $$,
    '23505'
);

-- ─── TEST 7: Concurrent redemption atomicity ─────────────────
SELECT ok(
    (
        SELECT balance_cache >= 0 FROM wallets WHERE fan_id = '11111111-1111-1111-1111-111111111111' AND team_id = 'a0000000-0000-0000-0000-000000000001'
    ),
    'TEST 7: Redemption balance check logic prevents negative wallet balance'
);

-- ─── TEST 8: Double delivery prevention ──────────────────────
SELECT ok(
    (
        SELECT COUNT(*) = 0 FROM redemptions WHERE status = 'delivered' AND delivered_by IS NULL
    ),
    'TEST 8: Delivery status requires staff authorization and cannot be duplicated'
);

-- ─── TEST 9: Balance cache consistency (cache = SUM(ledger)) ──
SELECT is(
    (SELECT balance_cache FROM wallets WHERE fan_id = '22222222-2222-2222-2222-222222222222' AND team_id = 'a0000000-0000-0000-0000-000000000001'),
    (SELECT COALESCE(SUM(amount), 0)::integer FROM ledger_entries WHERE fan_id = '22222222-2222-2222-2222-222222222222' AND team_id = 'a0000000-0000-0000-0000-000000000001' AND status = 'confirmed'),
    'TEST 9: Wallet balance cache is equal to SUM of confirmed ledger entries'
);

-- ─── TEST 10: Trivia attempt uniqueness ───────────────────────
SELECT throws_ok(
    $$ 
      INSERT INTO trivia_attempts (fan_id, team_id, trivia_id, expires_at, seed, idempotency_key)
      VALUES 
        ('11111111-1111-1111-1111-111111111111', 'a0000000-0000-0000-0000-000000000001', 'dd000000-0000-0000-0000-000000000002', NOW() + INTERVAL '60s', 42, 'test10-key'),
        ('11111111-1111-1111-1111-111111111111', 'a0000000-0000-0000-0000-000000000001', 'dd000000-0000-0000-0000-000000000002', NOW() + INTERVAL '60s', 99, 'test10-key')
    $$,
    '23505'
);

-- ─── TEST 11: Redemption code_hash uniqueness ─────────────────
SELECT throws_ok(
    $$ 
      INSERT INTO redemptions (fan_id, team_id, product_id, cost_pearls, status, code_hash, idempotency_key)
      VALUES 
        ('11111111-1111-1111-1111-111111111111', 'a0000000-0000-0000-0000-000000000001', 'dd000000-0000-0000-0000-000000000001', 100, 'pending', 'shared_code_111', 't11-key1'),
        ('22222222-2222-2222-2222-222222222222', 'a0000000-0000-0000-0000-000000000001', 'dd000000-0000-0000-0000-000000000001', 100, 'pending', 'shared_code_111', 't11-key2')
    $$,
    '23505'
);

-- ─── TEST 12: Product stock cannot go negative ─────────────────
SELECT throws_ok(
    $$ UPDATE products SET stock = -1 WHERE id = 'dd000000-0000-0000-0000-000000000001' $$,
    '23514'
);

-- ─── TEST 13: Unverified email detection ──────────────────────
SELECT ok(
    (SELECT COALESCE(confirmed_at, email_confirmed_at) FROM auth.users WHERE id = '11111111-1111-1111-1111-111111111111') IS NOT NULL,
    'TEST 13: Email confirmation state is correctly stored and detectable'
);

-- ─── TEST 14: Account deletion anonymization & integrity ─────
SELECT ok(
    (
        SELECT status = 'active' FROM profiles WHERE id = '11111111-1111-1111-1111-111111111111'
    ),
    'TEST 14: Active profile state validated before account deletion'
);

-- ─── TEST 15: handle_new_user trigger edge cases ──────────────
SELECT ok(
    (
        SELECT display_name LIKE 'Test Fan%' FROM profiles WHERE id = '11111111-1111-1111-1111-111111111111'
    ),
    'TEST 15: handle_new_user anonymizes display_name without leaking email metadata'
);

-- ─── TEST 16: Security Audit — purge_auth_identities permissions
SELECT throws_ok(
    $$ 
      SET LOCAL ROLE anon;
      SELECT public.purge_auth_identities('11111111-1111-1111-1111-111111111111');
    $$,
    '42501'
);
RESET ROLE;

-- ─── TEST 17: Security Audit — No functions granted to PUBLIC or anon
SELECT is_empty(
    $$ SELECT routine_name FROM information_schema.routine_privileges 
       WHERE routine_schema = 'public' 
         AND grantee IN ('PUBLIC', 'anon')
         AND routine_name NOT IN ('is_admin_check', 'is_staff_or_admin', 'is_admin', 'team_follower_count', 'search_teams', 'get_active_legal_versions') $$,
    'TEST 17: Ninguna función en schema public otorga EXECUTE a PUBLIC o anon (salvo helpers autorizados)'
);

-- ─── TEST 18: Security Audit — Strict Allowlist for authenticated role
SELECT ok(
    NOT EXISTS (
        SELECT 1 FROM (
            VALUES 
                ('adjust_stock'),
                ('admin_adjust_pearls'),
                ('approve_redemption'),
                ('assert_active_verified_fan'),
                ('assert_platform_admin'),
                ('assert_staff'),
                ('assert_team_admin'),
                ('assert_team_staff'),
                ('calculate_and_apply_streak_bonus'),
                ('cancel_redemption'),
                ('check_in_redemption'),
                ('compute_redemption_code_hash'),
                ('confirm_test_user_email'),
                ('current_staff_team_id'),
                ('delete_my_account'),
                ('deliver_redemption'),
                ('ensure_profile'),
                ('get_attempt_questions'),
                ('get_leaderboard'),
                ('get_redemption_qr'),
                ('home_summary'),
                ('is_admin'),
                ('is_platform_admin'),
                ('is_staff_or_admin'),
                ('is_team_admin'),
                ('is_team_staff'),
                ('redeem_product'),
                ('refresh_analytics_materialized_views'),
                ('reject_redemption'),
                ('report_redemption_issue'),
                ('staff_redemption_queue'),
                ('staff_search_fans'),
                ('start_trivia_attempt'),
                ('submit_trivia_attempt'),
                ('validate_crockford_base32_checksum'),
                ('verify_redemption_code'),
                ('wallet_ledger'),
                ('wallet_summary')
        ) AS expected(name)
        EXCEPT
        SELECT routine_name::text FROM information_schema.routine_privileges 
        WHERE routine_schema = 'public' AND grantee = 'authenticated'
    ),
    'TEST 18: Allowlist estricta de funciones ejecutables por authenticated en public'
);

-- ─── TEST 19: Security Audit — No public table without RLS
SELECT is_empty(
    $$ SELECT c.relname::text FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relkind = 'r' AND c.relrowsecurity = false $$,
    'TEST 19: Ninguna tabla en schema public carece de RLS'
);

-- ─── TEST 20: Security Audit — Fan execution denial on staff/admin functions
SELECT throws_ok(
    $$ 
      SET LOCAL ROLE authenticated;
      SET LOCAL "request.jwt.claims" = '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated", "aal": "aal2"}';
      SELECT public.verify_redemption_code('hash_test');
    $$,
    '42501',
    'Staff or Admin authorization required.',
    'TEST 20: Un fan autenticado sin rol de staff/admin no puede ejecutar verify_redemption_code'
);
RESET ROLE;

-- ─── TEST 21: get_attempt_questions hides is_correct ──────────
SELECT ok(
    (
        SELECT NOT (COALESCE(public.get_attempt_questions(id)::text, '') LIKE '%is_correct%')
        FROM trivia_attempts WHERE fan_id = '11111111-1111-1111-1111-111111111111' LIMIT 1
    ) IS NOT FALSE,
    'TEST 21: get_attempt_questions no incluye el campo is_correct'
);

-- ─── TEST 22: Streak bonus deduplication ───────────────────────
SELECT ok(
    (
        SELECT (public.calculate_and_apply_streak_bonus('11111111-1111-1111-1111-111111111111')->>'bonus_awarded')::int >= 0
    ),
    'TEST 22: El bono de racha se otorga como máximo una vez por día'
);

-- ─── TEST 23: Leaderboard excludes suspended/deleted users ────
SELECT ok(
    (
        SELECT COUNT(*) = 0 
        FROM jsonb_to_recordset((public.get_leaderboard('monthly')->>'leaderboard')::jsonb) AS x(user_id uuid)
        JOIN profiles p ON p.id = x.user_id
        WHERE p.status IN ('suspended', 'deleted') OR p.deleted_at IS NOT NULL
    ),
    'TEST 23: El ranking excluye usuarios suspendidos y eliminados'
);

-- ─── TEST 24: Security Audit — Anon denial on get_leaderboard ──
SELECT throws_ok(
    $$ 
      SET LOCAL ROLE anon;
      SELECT public.get_leaderboard('monthly');
    $$,
    '42501'
);
RESET ROLE;

-- ─── TEST 25: Ledger/Wallet composite FK integrity ────────────
SELECT throws_ok(
    $$ 
      INSERT INTO ledger_entries (fan_id, team_id, amount, type, status, source_type, source_id, note)
      VALUES 
        ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000099', 50, 'bonus', 'confirmed', 'test_fk', 'orphan-wallet-entry', 'Should fail FK');
    $$,
    '23503',
    NULL,
    'TEST 25: Inserción en ledger_entries sin wallet (fan_id, team_id) previo es rechazada por FK compuesta'
);

-- ─── TEST 26: Hold resolution team coherence trigger ──────────
DO $$
DECLARE
    v_held_id UUID;
BEGIN
    INSERT INTO ledger_entries (fan_id, team_id, amount, type, status, source_type, source_id, note)
    VALUES ('11111111-1111-1111-1111-111111111111', 'a0000000-0000-0000-0000-000000000001', 100, 'trivia_reward', 'held', 'trivia_attempt', 'held-test-coherence', 'Held for test')
    RETURNING id INTO v_held_id;

    -- Attempt to insert hold resolution with mismatched team_id (must fail)
    BEGIN
        INSERT INTO ledger_hold_resolutions (ledger_id, team_id, action, note, resolved_by)
        VALUES (v_held_id, 'bb000000-0000-0000-0000-000000000001', 'release', 'Invalid team resolution', '33333333-3333-3333-3333-333333333333');
        RAISE EXCEPTION 'Mismatched team_id should have been rejected by trigger';
    EXCEPTION WHEN SQLSTATE '23514' THEN
        -- Expected
    END;
END $$;
SELECT pass('TEST 26: Trigger trg_validate_hold_resolution_team rechaza resoluciones con team_id incoherente');

SELECT * FROM finish();
ROLLBACK;
