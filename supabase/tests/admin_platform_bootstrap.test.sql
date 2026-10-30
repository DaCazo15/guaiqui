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
SET CONSTRAINTS ALL IMMEDIATE;

-- Setup test teams: Alpha (active) and Beta (active)
INSERT INTO public.teams (id, name, slug, status)
VALUES 
    ('bb000000-0000-0000-0000-000000000001', 'Team Alpha', 'team-alpha-0b', 'active'),
    ('bb000000-0000-0000-0000-000000000002', 'Team Beta', 'team-beta-0b', 'active')
ON CONFLICT (id) DO UPDATE SET status = EXCLUDED.status;

-- Users
INSERT INTO auth.users (id, email, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud)
VALUES
    ('aaaaaaaa-1111-1111-1111-111111111111', 'platform_admin_0b@test.com', NOW(), '{"provider":"email"}', '{}', NOW(), NOW(), 'authenticated', 'authenticated'),
    ('aaaaaaaa-2222-2222-2222-222222222222', 'staff_alpha_0b@test.com', NOW(), '{"provider":"email"}', '{}', NOW(), NOW(), 'authenticated', 'authenticated'),
    ('aaaaaaaa-3333-3333-3333-333333333333', 'staff_beta_0b@test.com', NOW(), '{"provider":"email"}', '{}', NOW(), NOW(), 'authenticated', 'authenticated'),
    ('aaaaaaaa-4444-4444-4444-444444444444', 'regular_fan_0b@test.com', NOW(), '{"provider":"email"}', '{}', NOW(), NOW(), 'authenticated', 'authenticated')
ON CONFLICT (id) DO UPDATE SET email_confirmed_at = COALESCE(auth.users.email_confirmed_at, NOW()), raw_app_meta_data = EXCLUDED.raw_app_meta_data;

INSERT INTO public.profiles (id, display_name, status, terms_accepted_at, terms_version)
VALUES
    ('aaaaaaaa-1111-1111-1111-111111111111', 'Platform Admin 0b', 'active', NOW(), 'v1.0'),
    ('aaaaaaaa-2222-2222-2222-222222222222', 'Staff Alpha 0b', 'active', NOW(), 'v1.0'),
    ('aaaaaaaa-3333-3333-3333-333333333333', 'Staff Beta 0b', 'active', NOW(), 'v1.0'),
    ('aaaaaaaa-4444-4444-4444-444444444444', 'Fan 0b', 'active', NOW(), 'v1.0')
ON CONFLICT (id) DO UPDATE SET terms_accepted_at = NOW(), terms_version = 'v1.0';

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
    $$UPDATE public.staff_members SET active = false WHERE user_id = 'aaaaaaaa-1111-1111-1111-111111111111'$$,
    '23514',
    NULL,
    'TEST 1: Invariante assert_min_admins impide desactivar al único admin de plataforma activo'
);

-- TEST 2: Cannot deactivate the only active team admin for active Team Alpha
SELECT throws_ok(
    $$UPDATE public.staff_members SET active = false WHERE user_id = 'aaaaaaaa-2222-2222-2222-222222222222'$$,
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
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "aaaaaaaa-2222-2222-2222-222222222222", "role": "authenticated", "aal": "aal2"}';

SELECT is(
    jsonb_array_length(public.admin_risk_queue(false)),
    1,
    'TEST 3: Admin de Team Alpha solo ve alertas de riesgo de su propio equipo'
);
RESET ROLE;

-- TEST 4: Club admin Alpha cannot resolve Team Beta risk flag
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "aaaaaaaa-2222-2222-2222-222222222222", "role": "authenticated", "aal": "aal2"}';

SELECT throws_ok(
    $$SELECT public.admin_resolve_risk_flag('22222222-0000-0000-0000-000000000002', 'Nota ilegal')$$,
    '42501',
    NULL,
    'TEST 4: Admin de Team Alpha no puede resolver una alerta de riesgo de Team Beta'
);
RESET ROLE;

-- TEST 5: Platform admin sees all risk flags (Alpha + Beta)
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "aaaaaaaa-1111-1111-1111-111111111111", "role": "authenticated", "aal": "aal2"}';

SELECT ok(
    jsonb_array_length(public.admin_risk_queue(false)) >= 2,
    'TEST 5: Admin de plataforma puede consultar la cola global de alertas de riesgo'
);
RESET ROLE;

-- ─── 3. Multi-Team Scoped Functions (Paso 2 / Paso 3) ─────────────────────────

-- TEST 6: admin_list_fans succeeds for club admin (scoped to followers of their club)
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "aaaaaaaa-2222-2222-2222-222222222222", "role": "authenticated", "aal": "aal2"}';

SELECT lives_ok(
    $$SELECT public.admin_list_fans()$$,
    'TEST 6: admin_list_fans ejecuta correctamente para admin de club (acotado a seguidores)'
);
RESET ROLE;

-- TEST 7: admin_get_fan rejects club admin if fan does NOT follow their club
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "aaaaaaaa-2222-2222-2222-222222222222", "role": "authenticated", "aal": "aal2"}';

SELECT throws_ok(
    $$SELECT public.admin_get_fan('aaaaaaaa-4444-4444-4444-444444444444')$$,
    '42501',
    'El fanático solicitado no sigue a tu equipo.',
    'TEST 7: admin_get_fan rechaza acceso si el fan no sigue al equipo del admin de club'
);
RESET ROLE;

-- TEST 8: analytics_demographics succeeds for club admin (scoped to club followers)
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "aaaaaaaa-2222-2222-2222-222222222222", "role": "authenticated", "aal": "aal2"}';

SELECT lives_ok(
    $$SELECT public.analytics_demographics()$$,
    'TEST 8: analytics_demographics ejecuta correctamente para admin de club'
);
RESET ROLE;

-- TEST 9: analytics_economy rejects club admin querying another club's data
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "aaaaaaaa-2222-2222-2222-222222222222", "role": "authenticated", "aal": "aal2"}';

SELECT throws_ok(
    $$SELECT public.analytics_economy('bb000000-0000-0000-0000-000000000002')$$,
    '42501',
    'No tienes autorización para consultar analítica de otro equipo.',
    'TEST 9: analytics_economy rechaza que admin de club consulte otro equipo'
);
RESET ROLE;

-- TEST 10: analytics_top_fans rejects club admin querying another club's data
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "aaaaaaaa-2222-2222-2222-222222222222", "role": "authenticated", "aal": "aal2"}';

SELECT throws_ok(
    $$SELECT public.analytics_top_fans(10, NULL, NULL, 'bb000000-0000-0000-0000-000000000002')$$,
    '42501',
    'No tienes autorización para consultar analítica de otro equipo.',
    'TEST 10: analytics_top_fans rechaza que admin de club consulte otro equipo'
);
RESET ROLE;

-- TEST 11: Platform admin is NOT blocked by multi-team guards on admin_list_fans
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "aaaaaaaa-1111-1111-1111-111111111111", "role": "authenticated", "aal": "aal2"}';

SELECT lives_ok(
    $$SELECT public.admin_list_fans()$$,
    'TEST 11: Admin de plataforma puede ejecutar admin_list_fans sin bloqueo multi-equipo'
);
RESET ROLE;

-- ─── 4. Clasificación y Corrección de Funciones (Item E) ──────────────────────

-- TEST 12: admin_publish_policy rejected for club admin
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "aaaaaaaa-2222-2222-2222-222222222222", "role": "authenticated", "aal": "aal2"}';

SELECT throws_ok(
    $$SELECT public.admin_publish_policy('terminos', 'v2.0', 'Contenido')$$,
    '42501',
    NULL,
    'TEST 12: admin_publish_policy denegado a admin de club (solo plataforma)'
);
RESET ROLE;

-- TEST 13: reconcile_wallets rejected for club admin
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "aaaaaaaa-2222-2222-2222-222222222222", "role": "authenticated", "aal": "aal2"}';

SELECT throws_ok(
    $$SELECT * FROM public.reconcile_wallets()$$,
    '42501',
    NULL,
    'TEST 13: reconcile_wallets denegado a admin de club (solo plataforma)'
);
RESET ROLE;

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

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "aaaaaaaa-2222-2222-2222-222222222222", "role": "authenticated"}';

SELECT throws_ok(
    $$SELECT public.get_redemption_qr('ff000000-0000-0000-0000-000000000099')$$,
    '42501',
    NULL,
    'TEST 15: get_redemption_qr bloquea acceso de un usuario que no es el dueño del canje'
);
RESET ROLE;

-- TEST 16: purge_auth_identities rejected for club admin
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "aaaaaaaa-2222-2222-2222-222222222222", "role": "authenticated", "aal": "aal2"}';

SELECT throws_ok(
    $$SELECT public.purge_auth_identities('aaaaaaaa-4444-4444-4444-444444444444')$$,
    '42501',
    NULL,
    'TEST 16: purge_auth_identities denegado a admin de club (solo plataforma)'
);
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
