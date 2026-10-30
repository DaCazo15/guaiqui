-- ============================================================================
-- Test Suite: 34_phase1_security_corrections.test.sql
-- Description: Verifies Paso 0 fixes for Phase 1 Multi-Tenancy:
--              1. No defaults on team_id (prevents silent pollution of team #1)
--              2. Tenant trigger derives team_id and prevents cross-team writes
--              3. Child-parent team_id consistency enforcement
--              4. Inactive team blocks club staff/admin access
--              5. Cross-team isolation on staff/admin RPCs (redemptions, trivias, games, segments)
--              6. Staff management boundaries (club admin cannot touch platform admin or other clubs)
--              7. Platform admin 2FA (AAL2) requirement
-- ============================================================================

BEGIN;
SELECT plan(15);

-- Setup ephemeral test data
CREATE EXTENSION IF NOT EXISTS pgtap;

-- Ensure clean test state with two teams: Team A (active) and Team B (inactive)
INSERT INTO public.teams (id, name, slug, status)
VALUES 
    ('bb000000-0000-0000-0000-000000000001', 'Team Alpha', 'team-alpha', 'active'),
    ('bb000000-0000-0000-0000-000000000002', 'Team Beta Inactive', 'team-beta', 'inactive')
ON CONFLICT (id) DO UPDATE SET status = EXCLUDED.status;

-- Users
INSERT INTO auth.users (id, email, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud)
VALUES
    ('aaaaaaaa-1111-1111-1111-111111111111', 'platform_admin@test.com', NOW(), '{"provider":"email"}', '{}', NOW(), NOW(), 'authenticated', 'authenticated'),
    ('aaaaaaaa-2222-2222-2222-222222222222', 'staff_alpha@test.com', NOW(), '{"provider":"email"}', '{}', NOW(), NOW(), 'authenticated', 'authenticated'),
    ('aaaaaaaa-3333-3333-3333-333333333333', 'staff_beta@test.com', NOW(), '{"provider":"email"}', '{}', NOW(), NOW(), 'authenticated', 'authenticated')
ON CONFLICT (id) DO UPDATE SET email_confirmed_at = COALESCE(auth.users.email_confirmed_at, NOW()), raw_app_meta_data = EXCLUDED.raw_app_meta_data;

INSERT INTO public.profiles (id, display_name, status, terms_accepted_at, terms_version)
VALUES
    ('aaaaaaaa-1111-1111-1111-111111111111', 'Platform Admin', 'active', NOW(), 'v1.0'),
    ('aaaaaaaa-2222-2222-2222-222222222222', 'Staff Alpha', 'active', NOW(), 'v1.0'),
    ('aaaaaaaa-3333-3333-3333-333333333333', 'Staff Beta', 'active', NOW(), 'v1.0')
ON CONFLICT (id) DO UPDATE SET terms_accepted_at = NOW(), terms_version = 'v1.0';

-- Staff members
INSERT INTO public.staff_members (user_id, role, team_id, active)
VALUES
    ('aaaaaaaa-1111-1111-1111-111111111111', 'admin', NULL, true),
    ('aaaaaaaa-2222-2222-2222-222222222222', 'admin', 'bb000000-0000-0000-0000-000000000001', true),
    ('aaaaaaaa-3333-3333-3333-333333333333', 'admin', 'bb000000-0000-0000-0000-000000000002', true)
ON CONFLICT (user_id) DO UPDATE SET role = EXCLUDED.role, team_id = EXCLUDED.team_id, active = EXCLUDED.active;

-- ─── TEST 1: Default on team_id has been removed from trivias ─────────────────
SELECT is(
    (SELECT column_default FROM information_schema.columns 
     WHERE table_schema = 'public' AND table_name = 'trivias' AND column_name = 'team_id'),
    NULL,
    'TEST 1: team_id en public.trivias no posee valor por defecto'
);

-- ─── TEST 2: Default on team_id has been removed from products ────────────────
SELECT is(
    (SELECT column_default FROM information_schema.columns 
     WHERE table_schema = 'public' AND table_name = 'products' AND column_name = 'team_id'),
    NULL,
    'TEST 2: team_id en public.products no posee valor por defecto'
);

-- ─── TEST 3: Platform admin helper detects platform admin ─────────────────────
SELECT ok(
    public.is_platform_admin('aaaaaaaa-1111-1111-1111-111111111111'),
    'TEST 3: is_platform_admin identifica correctamente a un admin con team_id NULL'
);

-- ─── TEST 4: Platform admin helper rejects club admin ─────────────────────────
SELECT ok(
    NOT public.is_platform_admin('aaaaaaaa-2222-2222-2222-222222222222'),
    'TEST 4: is_platform_admin rechaza a un admin de club'
);

-- ─── TEST 5: assert_platform_admin fails without AAL2 ─────────────────────────
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "aaaaaaaa-1111-1111-1111-111111111111", "role": "authenticated", "aal": "aal1"}';

SELECT throws_ok(
    $$SELECT public.assert_platform_admin()$$,
    '42501',
    NULL,
    'TEST 5: assert_platform_admin deniega acceso a admin de plataforma si el token carece de aal2'
);
RESET ROLE;

-- ─── TEST 6: Inactive team blocks staff operations via is_team_staff ─────────
SELECT ok(
    NOT public.is_team_staff('aaaaaaaa-3333-3333-3333-333333333333', 'bb000000-0000-0000-0000-000000000002'),
    'TEST 6: is_team_staff bloquea a miembros de equipos con status inactive'
);

-- ─── TEST 7: Inactive team blocks admin operations via is_team_admin ─────────
SELECT ok(
    NOT public.is_team_admin('aaaaaaaa-3333-3333-3333-333333333333', 'bb000000-0000-0000-0000-000000000002'),
    'TEST 7: is_team_admin bloquea a admins de equipos con status inactive'
);

-- ─── TEST 8: Child consistency trigger rejects mismatched child team_id ───────
INSERT INTO public.trivias (id, team_id, title, starts_at, ends_at, status)
VALUES ('cc000000-0000-0000-0000-000000000001', 'bb000000-0000-0000-0000-000000000001', 'Trivia Alpha', NOW(), NOW() + INTERVAL '1 day', 'draft')
ON CONFLICT (id) DO NOTHING;

SELECT throws_ok(
    $$
        INSERT INTO public.trivia_questions (trivia_id, team_id, question_text, points, order_index)
        VALUES ('cc000000-0000-0000-0000-000000000001', 'bb000000-0000-0000-0000-000000000002', 'Pregunta con team_id cruzado', 50, 1);
    $$,
    '23503',
    NULL,
    'TEST 8: Inserción de pregunta con team_id diferente a su trivia padre es rechazada'
);

-- ─── TEST 9: Child consistency trigger auto-derives parent team_id if null ────
INSERT INTO public.trivia_questions (id, trivia_id, question_text, points, order_index)
VALUES ('cc000000-0000-0000-0000-000000000002', 'cc000000-0000-0000-0000-000000000001', 'Pregunta auto-derivada', 50, 1);

SELECT is(
    (SELECT team_id FROM public.trivia_questions WHERE id = 'cc000000-0000-0000-0000-000000000002'),
    'bb000000-0000-0000-0000-000000000001'::uuid,
    'TEST 9: Trigger deriva automáticamente el team_id del padre cuando el hijo se inserta sin team_id'
);

-- ─── TEST 10: Club admin cannot modify platform admin active status ───────────
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "aaaaaaaa-2222-2222-2222-222222222222", "role": "authenticated"}';

SELECT throws_ok(
    $$SELECT public.admin_toggle_staff_active('aaaaaaaa-1111-1111-1111-111111111111', false)$$,
    '42501',
    NULL,
    'TEST 10: Admin de club no puede modificar el estado activo de un admin de plataforma'
);
RESET ROLE;

-- ─── TEST 11: Club admin cannot modify staff role of another team ─────────────
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "aaaaaaaa-2222-2222-2222-222222222222", "role": "authenticated"}';

SELECT throws_ok(
    $$SELECT public.admin_update_staff_role('aaaaaaaa-3333-3333-3333-333333333333', 'staff')$$,
    '42501',
    NULL,
    'TEST 11: Admin de club no puede alterar el rol de personal de otro equipo'
);
RESET ROLE;

-- ─── TEST 12: Cross-team redemption approval is blocked ───────────────────────
INSERT INTO public.products (id, team_id, name, cost_pearls, stock, active)
VALUES ('ee000000-0000-0000-0000-000000000001', 'bb000000-0000-0000-0000-000000000002', 'Producto Beta', 100, 10, true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.redemptions (id, team_id, fan_id, product_id, cost_pearls, status, code_hash, idempotency_key)
VALUES ('ff000000-0000-0000-0000-000000000001', 'bb000000-0000-0000-0000-000000000002', 'aaaaaaaa-1111-1111-1111-111111111111', 'ee000000-0000-0000-0000-000000000001', 100, 'pending', 'hash_beta_redemption', 'idem_beta_1')
ON CONFLICT (id) DO NOTHING;

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "aaaaaaaa-2222-2222-2222-222222222222", "role": "authenticated"}';

SELECT throws_ok(
    $$SELECT public.approve_redemption('ff000000-0000-0000-0000-000000000001')$$,
    '42501',
    NULL,
    'TEST 12: Staff de Team Alpha no puede aprobar un canje perteneciente a Team Beta'
);
RESET ROLE;

-- ─── TEST 13: Cross-team segment inspection is blocked ────────────────────────
INSERT INTO public.segments (id, team_id, name, filters)
VALUES ('ff000000-0000-0000-0000-000000000002', 'bb000000-0000-0000-0000-000000000002', 'Segmento Beta', '{}'::jsonb)
ON CONFLICT (id) DO NOTHING;

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "aaaaaaaa-2222-2222-2222-222222222222", "role": "authenticated"}';

SELECT throws_ok(
    $$SELECT public.segment_count('ff000000-0000-0000-0000-000000000002')$$,
    '42501',
    NULL,
    'TEST 13: Staff de Team Alpha no puede consultar el conteo de un segmento de Team Beta'
);
RESET ROLE;

-- ─── TEST 14: Regular club admin cannot suspend fans globally ─────────────────
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "aaaaaaaa-2222-2222-2222-222222222222", "role": "authenticated"}';

SELECT throws_ok(
    $$SELECT public.admin_suspend_fan('aaaaaaaa-3333-3333-3333-333333333333', 'Motivo de prueba')$$,
    '42501',
    NULL,
    'TEST 14: Admin de club no puede suspender fans (reservado exclusivamente a plataforma)'
);
RESET ROLE;

-- ─── TEST 15: Cross-team trivia publishing is blocked ─────────────────────────
INSERT INTO public.trivias (id, team_id, title, starts_at, ends_at, status)
VALUES ('cc000000-0000-0000-0000-000000000003', 'bb000000-0000-0000-0000-000000000002', 'Trivia Beta', NOW(), NOW() + INTERVAL '1 day', 'draft')
ON CONFLICT (id) DO NOTHING;

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "aaaaaaaa-2222-2222-2222-222222222222", "role": "authenticated"}';

SELECT throws_ok(
    $$SELECT public.admin_publish_trivia('cc000000-0000-0000-0000-000000000003')$$,
    '42501',
    NULL,
    'TEST 15: Staff de Team Alpha no puede publicar trivias de Team Beta'
);
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
