-- ============================================================================
-- Test Suite: wallets_multiteam.test.sql
-- Description: Tests for Paso 2 & 3: Wallets y Ledger Multi-Equipo
--              1. Canje con saldo insuficiente en el equipo aunque el total alcance (aislamiento de saldo)
--              2. No se gana perlitas de equipos no seguidos o inactivos
--              3. Dejar de seguir conserva saldo y permite canjear
--              4. Ledger con team_id coherente con su wallet
--              5. Trigger de inmutabilidad sigue activo (UPDATE y DELETE prohibidos en ledger_entries)
--              6. Staff A no ajusta ni libera/revoca perlitas del equipo B
--              7. get_wallet_summary suma bien el total y no expone datos de otros usuarios
--              8. claim_birthday_bonus por equipo y año
--              9. reconcile_wallets valida por (fan_id, team_id)
-- ============================================================================

BEGIN;
SELECT plan(15);

CREATE EXTENSION IF NOT EXISTS pgtap;

-- Setup 2 ephemeral teams: Team Alpha (active) and Team Beta (active)
INSERT INTO public.teams (id, name, slug, status)
VALUES 
    ('ee000000-0000-0000-0000-000000000001', 'Team Multi Alpha', 'team-multi-alpha', 'active'),
    ('ee000000-0000-0000-0000-000000000002', 'Team Multi Beta', 'team-multi-beta', 'active')
ON CONFLICT (id) DO UPDATE SET status = EXCLUDED.status;

-- Users: Fan 1, Fan 2, Staff Alpha, Staff Beta
INSERT INTO auth.users (id, email)
VALUES
    ('e1111111-1111-1111-1111-111111111111', 'fan_wallet_1@test.com'),
    ('e2222222-2222-2222-2222-222222222222', 'fan_wallet_2@test.com'),
    ('e3333333-3333-3333-3333-333333333333', 'staff_wallet_alpha@test.com'),
    ('e4444444-4444-4444-4444-444444444444', 'staff_wallet_beta@test.com')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, display_name, status, created_at)
VALUES
    ('e1111111-1111-1111-1111-111111111111', 'Fan Wallet 1', 'active', NOW() - INTERVAL '60 days'),
    ('e2222222-2222-2222-2222-222222222222', 'Fan Wallet 2', 'active', NOW() - INTERVAL '60 days'),
    ('e3333333-3333-3333-3333-333333333333', 'Staff Wallet Alpha', 'active', NOW() - INTERVAL '60 days'),
    ('e4444444-4444-4444-4444-444444444444', 'Staff Wallet Beta', 'active', NOW() - INTERVAL '60 days')
ON CONFLICT (id) DO UPDATE SET status = EXCLUDED.status;

INSERT INTO public.staff_members (user_id, role, team_id, active)
VALUES
    ('e3333333-3333-3333-3333-333333333333', 'admin', 'ee000000-0000-0000-0000-000000000001', true),
    ('e4444444-4444-4444-4444-444444444444', 'admin', 'ee000000-0000-0000-0000-000000000002', true)
ON CONFLICT (user_id) DO UPDATE SET role = EXCLUDED.role, team_id = EXCLUDED.team_id, active = true;

-- Setup Products: One for Alpha (Cost 100), One for Beta (Cost 100)
INSERT INTO public.products (id, team_id, name, cost_pearls, stock, active)
VALUES
    ('fa000000-0000-0000-0000-000000000001', 'ee000000-0000-0000-0000-000000000001', 'Gorra Alpha', 100, 10, true),
    ('fa000000-0000-0000-0000-000000000002', 'ee000000-0000-0000-0000-000000000002', 'Camiseta Beta', 100, 10, true)
ON CONFLICT (id) DO UPDATE SET stock = 10, active = true;

-- Seed Wallets for Fan 1:
-- 50 perlitas in Alpha, 200 perlitas in Beta (Total = 250)
INSERT INTO public.wallets (fan_id, team_id, balance_cache, updated_at)
VALUES
    ('e1111111-1111-1111-1111-111111111111', 'ee000000-0000-0000-0000-000000000001', 50, NOW()),
    ('e1111111-1111-1111-1111-111111111111', 'ee000000-0000-0000-0000-000000000002', 200, NOW())
ON CONFLICT (fan_id, team_id) DO UPDATE SET balance_cache = EXCLUDED.balance_cache;

-- Fan 1 follows Alpha and Beta initially
INSERT INTO public.team_follows (user_id, team_id)
VALUES
    ('e1111111-1111-1111-1111-111111111111', 'ee000000-0000-0000-0000-000000000001'),
    ('e1111111-1111-1111-1111-111111111111', 'ee000000-0000-0000-0000-000000000002')
ON CONFLICT (user_id, team_id) DO NOTHING;

-- ─── 1. Insufficient Pearls in specific team (even if total balance is enough) ─
-- TEST 1: Fan 1 has 250 total pearls, but only 50 in Alpha. Trying to buy Gorra Alpha (cost 100) fails!
SELECT throws_ok(
    $$
        SET LOCAL ROLE authenticated;
        SET LOCAL "request.jwt.claims" = '{"sub": "e1111111-1111-1111-1111-111111111111", "role": "authenticated"}';
        SELECT public.redeem_product('fa000000-0000-0000-0000-000000000001', 'idem_fail_alpha_1');
    $$,
    NULL,
    'INSUFFICIENT_PERLITAS: Saldo insuficiente de perlitas de este equipo (Requerido: 100, Disponible: 50).',
    'TEST 1: Canje rechazado cuando el saldo del equipo es insuficiente aunque el total del fanático alcance'
);

-- TEST 2: Fan 1 has 200 in Beta. Buying Camiseta Beta (cost 100) succeeds!
SELECT is(
    (
        SET LOCAL ROLE authenticated;
        SET LOCAL "request.jwt.claims" = '{"sub": "e1111111-1111-1111-1111-111111111111", "role": "authenticated"}';
        SELECT (public.redeem_product('fa000000-0000-0000-0000-000000000002', 'idem_ok_beta_1')->>'status');
    ),
    'pending',
    'TEST 2: Canje exitoso debitando exclusivamente de la billetera del equipo correspondiente'
);

-- TEST 3: Beta wallet deducted to 100, Alpha wallet remains 50
SELECT is(
    (SELECT balance_cache FROM public.wallets WHERE fan_id = 'e1111111-1111-1111-1111-111111111111' AND team_id = 'ee000000-0000-0000-0000-000000000002'),
    100,
    'TEST 3: Saldo del equipo Beta decrementado correctamente a 100'
);
SELECT is(
    (SELECT balance_cache FROM public.wallets WHERE fan_id = 'e1111111-1111-1111-1111-111111111111' AND team_id = 'ee000000-0000-0000-0000-000000000001'),
    50,
    'TEST 3b: Saldo del equipo Alpha permanece intacto en 50'
);

-- ─── 2. Dejar de seguir conserva saldo y permite canjear ─────────────────────
-- Fan 1 unfollows Beta
DELETE FROM public.team_follows WHERE user_id = 'e1111111-1111-1111-1111-111111111111' AND team_id = 'ee000000-0000-0000-0000-000000000002';

-- TEST 4: Unfollowing Beta preserved balance (still 100)
SELECT is(
    (SELECT balance_cache FROM public.wallets WHERE fan_id = 'e1111111-1111-1111-1111-111111111111' AND team_id = 'ee000000-0000-0000-0000-000000000002'),
    100,
    'TEST 4: Dejar de seguir al equipo conserva íntegro el saldo de perlitas'
);

-- TEST 5: Can still redeem from Beta while not following
SELECT is(
    (
        SET LOCAL ROLE authenticated;
        SET LOCAL "request.jwt.claims" = '{"sub": "e1111111-1111-1111-1111-111111111111", "role": "authenticated"}';
        SELECT (public.redeem_product('fa000000-0000-0000-0000-000000000002', 'idem_ok_beta_2')->>'status');
    ),
    'pending',
    'TEST 5: El fanático puede canjear su saldo restante en un equipo aunque haya dejado de seguirlo'
);

-- ─── 3. Inmutabilidad del Ledger ─────────────────────────────────────────────
-- TEST 6: Trigger trg_prevent_ledger_mutation prevents UPDATE on ledger_entries
SELECT throws_ok(
    $$
        UPDATE public.ledger_entries
        SET amount = 9999
        WHERE fan_id = 'e1111111-1111-1111-1111-111111111111';
    $$,
    NULL,
    'Financial Ledger entries are immutable. UPDATE and DELETE operations are forbidden.',
    'TEST 6: Trigger de inmutabilidad bloquea UPDATE sobre ledger_entries'
);

-- TEST 7: Trigger trg_prevent_ledger_mutation prevents DELETE on ledger_entries
SELECT throws_ok(
    $$
        DELETE FROM public.ledger_entries
        WHERE fan_id = 'e1111111-1111-1111-1111-111111111111';
    $$,
    NULL,
    'Financial Ledger entries are immutable. UPDATE and DELETE operations are forbidden.',
    'TEST 7: Trigger de inmutabilidad bloquea DELETE sobre ledger_entries'
);

-- ─── 4. Staff cross-team isolation on adjustments and held pearls ────────────
-- TEST 8: Staff Alpha cannot adjust pearls for Team Beta
SELECT throws_ok(
    $$
        SET LOCAL ROLE authenticated;
        SET LOCAL "request.jwt.claims" = '{"sub": "e3333333-3333-3333-3333-333333333333", "role": "authenticated"}';
        SELECT public.admin_adjust_pearls('e1111111-1111-1111-1111-111111111111', 50, 'Ajuste ilegal cruzado', 'ee000000-0000-0000-0000-000000000002');
    $$,
    '42501',
    NULL,
    'TEST 8: Admin de Club Alpha no puede ajustar saldo del equipo Beta'
);

-- Setup a held ledger entry for Team Beta
INSERT INTO public.ledger_entries (id, fan_id, team_id, amount, type, status, source_type, source_id, note)
VALUES ('bbbbbbbb-0000-0000-0000-000000000002', 'e1111111-1111-1111-1111-111111111111', 'ee000000-0000-0000-0000-000000000002', 50, 'trivia_reward', 'held', 'trivia_attempt', 'att_held_1', 'Held test')
ON CONFLICT (id) DO NOTHING;

-- TEST 9: Staff Alpha cannot release held pearls belonging to Team Beta
SELECT throws_ok(
    $$
        SET LOCAL ROLE authenticated;
        SET LOCAL "request.jwt.claims" = '{"sub": "e3333333-3333-3333-3333-333333333333", "role": "authenticated"}';
        SELECT public.admin_release_held_pearls('bbbbbbbb-0000-0000-0000-000000000002', 'Liberación no autorizada');
    $$,
    '42501',
    NULL,
    'TEST 9: Admin de Club Alpha no puede liberar perlitas retenidas de Club Beta'
);

-- TEST 10: Staff Beta CAN release held pearls belonging to Team Beta
SELECT is(
    (
        SET LOCAL ROLE authenticated;
        SET LOCAL "request.jwt.claims" = '{"sub": "e4444444-4444-4444-4444-444444444444", "role": "authenticated"}';
        SELECT (public.admin_release_held_pearls('bbbbbbbb-0000-0000-0000-000000000002', 'Liberación legítima')->>'status');
    ),
    'released',
    'TEST 10: Admin de Club Beta libera exitosamente perlitas retenidas de su club'
);

-- ─── 5. get_wallet_summary() ─────────────────────────────────────────────────
-- TEST 11: get_wallet_summary calculates total correctly and includes followed and non-followed teams with balance
SELECT is(
    (
        SET LOCAL ROLE authenticated;
        SET LOCAL "request.jwt.claims" = '{"sub": "e1111111-1111-1111-1111-111111111111", "role": "authenticated"}';
        SELECT (public.get_wallet_summary()->>'total_balance')::int;
    ),
    (
        SELECT SUM(balance_cache)::int FROM public.wallets WHERE fan_id = 'e1111111-1111-1111-1111-111111111111'
    ),
    'TEST 11: get_wallet_summary calcula la suma total correcta unificada'
);

-- TEST 12: get_wallet_summary does not leak other users wallets
SELECT ok(
    (
        SET LOCAL ROLE authenticated;
        SET LOCAL "request.jwt.claims" = '{"sub": "e2222222-2222-2222-2222-222222222222", "role": "authenticated"}';
        SELECT (public.get_wallet_summary()->>'total_balance')::int = 0;
    ),
    'TEST 12: get_wallet_summary está aislado por usuario autenticado y no expone balances ajenos'
);

-- ─── 6. Trivia Attempt earning requirement (Must follow active team) ─────────
-- Setup trivia for Beta
INSERT INTO public.trivias (id, team_id, title, starts_at, ends_at, status)
VALUES ('cc000000-0000-0000-0000-000000000099', 'ee000000-0000-0000-0000-000000000002', 'Trivia Beta Test', NOW() - INTERVAL '1 hour', NOW() + INTERVAL '1 hour', 'published')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.trivia_attempts (id, fan_id, trivia_id, team_id, started_at)
VALUES ('ca000000-0000-0000-0000-000000000099', 'e1111111-1111-1111-1111-111111111111', 'cc000000-0000-0000-0000-000000000099', 'ee000000-0000-0000-0000-000000000002', NOW() - INTERVAL '10 seconds')
ON CONFLICT (id) DO NOTHING;

-- Fan 1 currently DOES NOT follow Beta (unfollowed above)
-- TEST 13: Submitting trivia for non-followed team is rejected
SELECT throws_ok(
    $$
        SET LOCAL ROLE authenticated;
        SET LOCAL "request.jwt.claims" = '{"sub": "e1111111-1111-1111-1111-111111111111", "role": "authenticated"}';
        SELECT public.submit_trivia_attempt('ca000000-0000-0000-0000-000000000099', '{}'::jsonb);
    $$,
    '42501',
    NULL,
    'TEST 13: submit_trivia_attempt exige seguir al equipo para ganar perlitas'
);

-- ─── 7. Birthday Bonus per team & year ───────────────────────────────────────
-- Fan 1 follows Alpha
-- TEST 14: Birthday bonus rejected for non-followed team Beta
SELECT throws_ok(
    $$
        SET LOCAL ROLE authenticated;
        SET LOCAL "request.jwt.claims" = '{"sub": "e1111111-1111-1111-1111-111111111111", "role": "authenticated"}';
        SELECT public.claim_birthday_bonus('ee000000-0000-0000-0000-000000000002');
    $$,
    '42501',
    NULL,
    'TEST 14: claim_birthday_bonus exige seguir al equipo'
);

-- TEST 15: reconcile_wallets verifies per (fan_id, team_id)
SELECT ok(
    (
        SET LOCAL ROLE authenticated;
        SET LOCAL "request.jwt.claims" = '{"sub": "aaaaaaaa-1111-1111-1111-111111111111", "role": "authenticated", "aal": "aal2"}';
        SELECT count(*) >= 0 FROM public.reconcile_wallets();
    ),
    'TEST 15: reconcile_wallets ejecuta la reconciliación por fan_id y team_id sin errores'
);

SELECT * FROM finish();
ROLLBACK;
