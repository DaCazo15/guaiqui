-- ============================================================================
-- Test Suite: 35_paso0b_refinements.test.sql
-- Description: Tests for Paso 0b Refinements & Protections:
--              1. Invariant assert_min_admins (>= 1 platform admin + >= 1 team admin per active team)
--              2. Scoped risk_flags (club admin isolation vs platform visibility)
--              3. Multi-team temporary guards on fans & analytics
--              4. Classify & correct item E functions (policy publish, reconcile, seed, qr, purge)
-- ============================================================================

BEGIN;
SELECT plan(16);

CREATE EXTENSION IF NOT EXISTS pgtap;

-- Setup test teams: Alpha (active) and Beta (active)
INSERT INTO public.teams (id, name, slug, status)
VALUES 
    ('bb000000-0000-0000-0000-000000000001', 'Team Alpha', 'team-alpha-0b', 'active'),
    ('bb000000-0000-0000-0000-000000000002', 'Team Beta', 'team-beta-0b', 'active')
ON CONFLICT (id) DO UPDATE SET status = EXCLUDED.status;

-- Users
INSERT INTO auth.users (id, email)
VALUES
    ('aaaaaaaa-1111-1111-1111-111111111111', 'platform_admin_0b@test.com'),
    ('aaaaaaaa-2222-2222-2222-222222222222', 'staff_alpha_0b@test.com'),
    ('aaaaaaaa-3333-3333-3333-333333333333', 'staff_beta_0b@test.com'),
    ('aaaaaaaa-4444-4444-4444-444444444444', 'regular_fan_0b@test.com')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, display_name, status)
VALUES
    ('aaaaaaaa-1111-1111-1111-111111111111', 'Platform Admin 0b', 'active'),
    ('aaaaaaaa-2222-2222-2222-222222222222', 'Staff Alpha 0b', 'active'),
    ('aaaaaaaa-3333-3333-3333-333333333333', 'Staff Beta 0b', 'active'),
    ('aaaaaaaa-4444-4444-4444-444444444444', 'Fan 0b', 'active')
ON CONFLICT (id) DO NOTHING;

-- Staff members (Platform admin, Alpha club admin, Beta club admin)
INSERT INTO public.staff_members (user_id, role, team_id, active)
VALUES
    ('aaaaaaaa-1111-1111-1111-111111111111', 'admin', NULL, true),
    ('aaaaaaaa-2222-2222-2222-222222222222', 'admin', 'bb000000-0000-0000-0000-000000000001', true),
    ('aaaaaaaa-3333-3333-3333-333333333333', 'admin', 'bb000000-0000-0000-0000-000000000002', true)
ON CONFLICT (user_id) DO UPDATE SET role = EXCLUDED.role, team_id = EXCLUDED.team_id, active = EXCLUDED.active;

-- ─── 1. Invariante assert_min_admins ─────────────────────────────────────────

-- TEST 1: Cannot deactivate the only active platform admin
SELECT throws_ok(
    $$
        UPDATE public.staff_members
        SET active = false
        WHERE user_id = 'aaaaaaaa-1111-1111-1111-111111111111';
    $$,
    '23514',
    NULL,
    'TEST 1: Invariante assert_min_admins impide desactivar al único admin de plataforma activo'
);

-- TEST 2: Cannot deactivate the only active team admin for active Team Alpha
SELECT throws_ok(
    $$
        UPDATE public.staff_members
        SET active = false
        WHERE user_id = 'aaaaaaaa-2222-2222-2222-222222222222';
    $$,
    '23514',
    NULL,
    'TEST 2: Invariante assert_min_admins impide dejar a un equipo activo sin admin de equipo'
);

-- ─── 2. risk_flags scoping ───────────────────────────────────────────────────

-- Insert risk flags: one for Team Alpha, one for Team Beta
INSERT INTO public.risk_flags (id, fan_id, team_id, reason, severity, resolved)
VALUES 
    ('11111111-0000-0000-0000-000000000001', 'aaaaaaaa-4444-4444-4444-444444444444', 'bb000000-0000-0000-0000-000000000001', 'Alerta Alpha', 'medium', false),
    ('22222222-0000-0000-0000-000000000002', 'aaaaaaaa-4444-4444-4444-444444444444', 'bb000000-0000-0000-0000-000000000002', 'Alerta Beta', 'high', false)
ON CONFLICT (id) DO NOTHING;

-- TEST 3: Club admin Alpha only sees Team Alpha risk flags
SELECT is(
    (
        SET LOCAL ROLE authenticated;
        SET LOCAL "request.jwt.claims" = '{"sub": "aaaaaaaa-2222-2222-2222-222222222222", "role": "authenticated"}';
        SELECT jsonb_array_length(public.admin_risk_queue(false));
    ),
    1,
    'TEST 3: Admin de Team Alpha solo ve alertas de riesgo de su propio equipo'
);

-- TEST 4: Club admin Alpha cannot resolve Team Beta risk flag
SELECT throws_ok(
    $$
        SET LOCAL ROLE authenticated;
        SET LOCAL "request.jwt.claims" = '{"sub": "aaaaaaaa-2222-2222-2222-222222222222", "role": "authenticated"}';
        SELECT public.admin_resolve_risk_flag('22222222-0000-0000-0000-000000000002', 'Nota ilegal');
    $$,
    '42501',
    NULL,
    'TEST 4: Admin de Team Alpha no puede resolver una alerta de riesgo de Team Beta'
);

-- TEST 5: Platform admin sees all risk flags (Alpha + Beta)
SELECT ok(
    (
        SET LOCAL ROLE authenticated;
        SET LOCAL "request.jwt.claims" = '{"sub": "aaaaaaaa-1111-1111-1111-111111111111", "role": "authenticated", "aal": "aal2"}';
        SELECT jsonb_array_length(public.admin_risk_queue(false)) >= 2;
    ),
    'TEST 5: Admin de plataforma puede consultar la cola global de alertas de riesgo'
);

-- ─── 3. Multi-Team Temporary Guards (Step 0b Item D) ─────────────────────────

-- TEST 6: admin_list_fans guarded for club admin when multiple active teams exist
SELECT throws_ok(
    $$
        SET LOCAL ROLE authenticated;
        SET LOCAL "request.jwt.claims" = '{"sub": "aaaaaaaa-2222-2222-2222-222222222222", "role": "authenticated"}';
        SELECT public.admin_list_fans();
    $$,
    '42501',
    NULL,
    'TEST 6: admin_list_fans protegido con MULTI_TEAM_PENDING_STEP2 para admin de club con >1 equipo activo'
);

-- TEST 7: admin_get_fan guarded for club admin when multiple active teams exist
SELECT throws_ok(
    $$
        SET LOCAL ROLE authenticated;
        SET LOCAL "request.jwt.claims" = '{"sub": "aaaaaaaa-2222-2222-2222-222222222222", "role": "authenticated"}';
        SELECT public.admin_get_fan('aaaaaaaa-4444-4444-4444-444444444444');
    $$,
    '42501',
    NULL,
    'TEST 7: admin_get_fan protegido con MULTI_TEAM_PENDING_STEP2 para admin de club con >1 equipo activo'
);

-- TEST 8: analytics_demographics guarded for club admin
SELECT throws_ok(
    $$
        SET LOCAL ROLE authenticated;
        SET LOCAL "request.jwt.claims" = '{"sub": "aaaaaaaa-2222-2222-2222-222222222222", "role": "authenticated"}';
        SELECT public.analytics_demographics();
    $$,
    '42501',
    NULL,
    'TEST 8: analytics_demographics protegido con MULTI_TEAM_PENDING_STEP2 para admin de club con >1 equipo activo'
);

-- TEST 9: analytics_economy guarded for club admin
SELECT throws_ok(
    $$
        SET LOCAL ROLE authenticated;
        SET LOCAL "request.jwt.claims" = '{"sub": "aaaaaaaa-2222-2222-2222-222222222222", "role": "authenticated"}';
        SELECT public.analytics_economy();
    $$,
    '42501',
    NULL,
    'TEST 9: analytics_economy protegido con MULTI_TEAM_PENDING_STEP2 para admin de club con >1 equipo activo'
);

-- TEST 10: analytics_top_fans guarded for club admin
SELECT throws_ok(
    $$
        SET LOCAL ROLE authenticated;
        SET LOCAL "request.jwt.claims" = '{"sub": "aaaaaaaa-2222-2222-2222-222222222222", "role": "authenticated"}';
        SELECT public.analytics_top_fans();
    $$,
    '42501',
    NULL,
    'TEST 10: analytics_top_fans protegido con MULTI_TEAM_PENDING_STEP2 para admin de club con >1 equipo activo'
);

-- TEST 11: Platform admin is NOT blocked by multi-team guards on admin_list_fans
SELECT lives_ok(
    $$
        SET LOCAL ROLE authenticated;
        SET LOCAL "request.jwt.claims" = '{"sub": "aaaaaaaa-1111-1111-1111-111111111111", "role": "authenticated", "aal": "aal2"}';
        SELECT public.admin_list_fans();
    $$,
    'TEST 11: Admin de plataforma puede ejecutar admin_list_fans sin bloqueo multi-equipo'
);

-- ─── 4. Clasificación y Corrección de Funciones (Item E) ──────────────────────

-- TEST 12: admin_publish_policy rejected for club admin
SELECT throws_ok(
    $$
        SET LOCAL ROLE authenticated;
        SET LOCAL "request.jwt.claims" = '{"sub": "aaaaaaaa-2222-2222-2222-222222222222", "role": "authenticated"}';
        SELECT public.admin_publish_policy('terminos', 'v2.0', 'Contenido');
    $$,
    '42501',
    NULL,
    'TEST 12: admin_publish_policy denegado a admin de club (solo plataforma)'
);

-- TEST 13: reconcile_wallets rejected for club admin
SELECT throws_ok(
    $$
        SET LOCAL ROLE authenticated;
        SET LOCAL "request.jwt.claims" = '{"sub": "aaaaaaaa-2222-2222-2222-222222222222", "role": "authenticated"}';
        SELECT * FROM public.reconcile_wallets();
    $$,
    '42501',
    NULL,
    'TEST 13: reconcile_wallets denegado a admin de club (solo plataforma)'
);

-- TEST 14: seed_analytics_performance_data throws error (violates no-hardcoded-data rule)
SELECT throws_ok(
    $$
        SELECT public.seed_analytics_performance_data(10, 50);
    $$,
    '0A000',
    NULL,
    'TEST 14: seed_analytics_performance_data deshabilitado por regla no-hardcoded-data'
);

-- TEST 15: get_redemption_qr rejects cross-fan access
INSERT INTO public.products (id, team_id, name, cost_pearls, stock, active)
VALUES ('ee000000-0000-0000-0000-000000000099', 'bb000000-0000-0000-0000-000000000001', 'Producto QR Test', 50, 10, true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.redemptions (id, team_id, fan_id, product_id, cost_pearls, status, code_hash, idempotency_key)
VALUES ('ff000000-0000-0000-0000-000000000099', 'bb000000-0000-0000-0000-000000000001', 'aaaaaaaa-4444-4444-4444-444444444444', 'ee000000-0000-0000-0000-000000000099', 50, 'pending', 'hash_fan_qr', 'idem_qr_1')
ON CONFLICT (id) DO NOTHING;

SELECT throws_ok(
    $$
        SET LOCAL ROLE authenticated;
        SET LOCAL "request.jwt.claims" = '{"sub": "aaaaaaaa-2222-2222-2222-222222222222", "role": "authenticated"}';
        SELECT public.get_redemption_qr('ff000000-0000-0000-0000-000000000099');
    $$,
    '42501',
    NULL,
    'TEST 15: get_redemption_qr bloquea acceso de un usuario que no es el dueño del canje'
);

-- TEST 16: purge_auth_identities rejected for club admin
SELECT throws_ok(
    $$
        SET LOCAL ROLE authenticated;
        SET LOCAL "request.jwt.claims" = '{"sub": "aaaaaaaa-2222-2222-2222-222222222222", "role": "authenticated"}';
        SELECT public.purge_auth_identities('aaaaaaaa-4444-4444-4444-444444444444');
    $$,
    '42501',
    NULL,
    'TEST 16: purge_auth_identities denegado a admin de club (solo plataforma)'
);

SELECT * FROM finish();
ROLLBACK;
