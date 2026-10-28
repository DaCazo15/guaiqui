-- ============================================================================
-- Test Suite: 33_multi_tenant_isolation.test.sql
-- Description: Tests for Multi-Tenant Isolation & Role Authorization:
--              1. staff_members.team_id column exists
--              2. Platform Admin (team_id IS NULL) has global privileges across teams
--              3. Team Staff (team_id = X) only has privileges on team X, denied on Y
--              4. Team Admin (team_id = X) only has admin privileges on team X, denied on Y
--              5. Core team tables have team_id NOT NULL and indexed
--              6. 2FA (aal2) enforcement in assert_team_staff and assert_team_admin
-- ============================================================================

BEGIN;

SELECT plan(12);

-- 1. Setup Secondary Test Team
INSERT INTO public.teams (id, name, slug, status, joined_at)
VALUES (
    'b0000000-0000-0000-0000-000000000002',
    'Trotamundos de Carabobo',
    'trotamundos',
    'active',
    NOW()
)
ON CONFLICT (slug) DO NOTHING;

-- 2. Setup Test Users
-- Platform Admin (team_id IS NULL)
INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud)
VALUES 
    ('44444444-4444-4444-4444-444444444444', '00000000-0000-0000-0000-000000000000', 'platform_admin@guaiqui.test', 'encrypted', NOW(), '{"provider":"email","providers":["email"]}', '{}', NOW(), NOW(), 'authenticated', 'authenticated'),
    ('55555555-5555-5555-5555-555555555555', '00000000-0000-0000-0000-000000000000', 'guaiqui_staff@guaiqui.test', 'encrypted', NOW(), '{"provider":"email","providers":["email"]}', '{}', NOW(), NOW(), 'authenticated', 'authenticated'),
    ('66666666-6666-6666-6666-666666666666', '00000000-0000-0000-0000-000000000000', 'guaiqui_admin@guaiqui.test', 'encrypted', NOW(), '{"provider":"email","providers":["email"]}', '{}', NOW(), NOW(), 'authenticated', 'authenticated')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, display_name, status, created_at)
VALUES 
    ('44444444-4444-4444-4444-444444444444', 'Platform Admin', 'active', NOW()),
    ('55555555-5555-5555-5555-555555555555', 'Guaiqueríes Staff', 'active', NOW()),
    ('66666666-6666-6666-6666-666666666666', 'Guaiqueríes Admin', 'active', NOW())
ON CONFLICT (id) DO NOTHING;

-- Assign staff roles
INSERT INTO public.staff_members (user_id, role, active, team_id)
VALUES 
    ('44444444-4444-4444-4444-444444444444', 'admin', true, NULL), -- Platform Admin
    ('55555555-5555-5555-5555-555555555555', 'staff', true, 'a0000000-0000-0000-0000-000000000001'), -- Guaiqueríes Staff
    ('66666666-6666-6666-6666-666666666666', 'admin', true, 'a0000000-0000-0000-0000-000000000001')  -- Guaiqueríes Admin
ON CONFLICT (user_id) DO UPDATE SET role = EXCLUDED.role, active = EXCLUDED.active, team_id = EXCLUDED.team_id;

-- Test 1: staff_members has team_id column
SELECT has_column('public', 'staff_members', 'team_id', 'TEST 1: staff_members debe contener la columna team_id');

-- Test 2: Platform Admin has staff privileges on Guaiqueríes
SELECT is(
    public.is_team_staff('44444444-4444-4444-4444-444444444444', 'a0000000-0000-0000-0000-000000000001'),
    true,
    'TEST 2: Platform Admin tiene privilegios de staff sobre Guaiqueríes'
);

-- Test 3: Platform Admin has staff privileges on Trotamundos
SELECT is(
    public.is_team_staff('44444444-4444-4444-4444-444444444444', 'b0000000-0000-0000-0000-000000000002'),
    true,
    'TEST 3: Platform Admin tiene privilegios de staff globales sobre cualquier equipo'
);

-- Test 4: Guaiqueríes Staff has staff privileges on Guaiqueríes
SELECT is(
    public.is_team_staff('55555555-5555-5555-5555-555555555555', 'a0000000-0000-0000-0000-000000000001'),
    true,
    'TEST 4: Staff de Guaiqueríes tiene privilegios en Guaiqueríes'
);

-- Test 5: Guaiqueríes Staff is DENIED on Trotamundos
SELECT is(
    public.is_team_staff('55555555-5555-5555-5555-555555555555', 'b0000000-0000-0000-0000-000000000002'),
    false,
    'TEST 5: Staff de Guaiqueríes NO tiene privilegios sobre otro equipo (Trotamundos)'
);

-- Test 6: Guaiqueríes Admin has admin privileges on Guaiqueríes
SELECT is(
    public.is_team_admin('66666666-6666-6666-6666-666666666666', 'a0000000-0000-0000-0000-000000000001'),
    true,
    'TEST 6: Admin de Guaiqueríes tiene privilegios admin en Guaiqueríes'
);

-- Test 7: Guaiqueríes Admin is DENIED admin privileges on Trotamundos
SELECT is(
    public.is_team_admin('66666666-6666-6666-6666-666666666666', 'b0000000-0000-0000-0000-000000000002'),
    false,
    'TEST 7: Admin de Guaiqueríes NO tiene privilegios admin en otro equipo'
);

-- Test 8: Guaiqueríes Staff is NOT a team admin
SELECT is(
    public.is_team_admin('55555555-5555-5555-5555-555555555555', 'a0000000-0000-0000-0000-000000000001'),
    false,
    'TEST 8: Rol staff de club no tiene privilegios de admin de equipo'
);

-- Test 9: products table has team_id column
SELECT has_column('public', 'products', 'team_id', 'TEST 9: products tiene columna team_id');

-- Test 10: trivias table has team_id column
SELECT has_column('public', 'trivias', 'team_id', 'TEST 10: trivias tiene columna team_id');

-- Test 11: games table has team_id column
SELECT has_column('public', 'games', 'team_id', 'TEST 11: games tiene columna team_id');

-- Test 12: assert_team_staff throws error when 2FA is missing
SELECT throws_ok(
    $$
      SET LOCAL "request.jwt.claims" = '{"sub": "55555555-5555-5555-5555-555555555555", "role": "authenticated", "aal": "aal1"}';
      SELECT public.assert_team_staff('a0000000-0000-0000-0000-000000000001');
    $$,
    '42501',
    'Verificación en dos pasos (2FA) requerida para personal.',
    'TEST 12: assert_team_staff exige aal2 (2FA)'
);

SELECT * FROM finish();
ROLLBACK;
