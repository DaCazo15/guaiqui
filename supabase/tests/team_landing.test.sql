-- ============================================================================
-- Test: team_landing.test.sql
-- Domain: Landing Pública por Equipo, Subdominios y CMS Atómico
-- ============================================================================

BEGIN;
SELECT plan(16);

-- 1. Setup users de prueba con perfiles y roles claros
INSERT INTO auth.users (id, email, aud, role, email_confirmed_at) VALUES
  ('11000000-0000-0000-0000-000000000001', 'landing_admin@guaiqueries.com', 'authenticated', 'authenticated', NOW()),
  ('11000000-0000-0000-0000-000000000002', 'landing_staff@guaiqueries.com', 'authenticated', 'authenticated', NOW()),
  ('11000000-0000-0000-0000-000000000003', 'other_staff@otherteam.com', 'authenticated', 'authenticated', NOW()),
  ('11000000-0000-0000-0000-000000000004', 'landing_fan@guaiqueries.com', 'authenticated', 'authenticated', NOW())
ON CONFLICT (id) DO UPDATE SET email_confirmed_at = NOW();

INSERT INTO public.profiles (id, display_name, status, terms_version, terms_accepted_at, privacy_accepted_at, pearls_rules_accepted_at) VALUES
  ('11000000-0000-0000-0000-000000000001', 'Admin Landing', 'active', 'v1.0', NOW(), NOW(), NOW()),
  ('11000000-0000-0000-0000-000000000002', 'Staff Landing', 'active', 'v1.0', NOW(), NOW(), NOW()),
  ('11000000-0000-0000-0000-000000000003', 'Other Staff', 'active', 'v1.0', NOW(), NOW(), NOW()),
  ('11000000-0000-0000-0000-000000000004', 'Fan Landing', 'active', 'v1.0', NOW(), NOW(), NOW())
ON CONFLICT (id) DO UPDATE SET terms_accepted_at = NOW(), privacy_accepted_at = NOW(), pearls_rules_accepted_at = NOW();

-- Equipo secundario para pruebas multi-inquilino
INSERT INTO public.teams (
  id, name, slug, subdomain, short_name, primary_color, secondary_color, status
) VALUES (
  'b0000000-0000-0000-0000-000000000002',
  'Cocodrilos de Caracas',
  'cocodrilos',
  'cocodrilos',
  'Los Saurios',
  '#000000',
  '#E31B23',
  'active'
) ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.staff_members (user_id, team_id, role, active) VALUES
  ('11000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'admin', true),
  ('11000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'staff', true),
  ('11000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000002', 'staff', true)
ON CONFLICT (user_id) DO UPDATE SET active = true;

-- Test 1: Verificar existencia de columnas clave en public.teams
SELECT has_column('public', 'teams', 'subdomain', 'teams table has subdomain column');
SELECT has_column('public', 'teams', 'arena_name', 'teams table has arena_name column');
SELECT has_column('public', 'teams', 'city', 'teams table has city column');
SELECT has_column('public', 'teams', 'championships_summary', 'teams table has championships_summary column');
SELECT has_column('public', 'teams', 'landing_config', 'teams table has landing_config column');

-- Test 6: teams_public proyecta subdominio y bio
SELECT has_column('public', 'teams_public', 'subdomain', 'teams_public view exposes subdomain');
SELECT has_column('public', 'teams_public', 'bio', 'teams_public view exposes bio');

-- Test 8: Anon puede ejecutar get_team_landing_data por slug
SET LOCAL ROLE anon;
SELECT is(
  (public.get_team_landing_data('guaiqueries')->>'found')::boolean,
  true,
  'Anon gets team landing data successfully by slug'
);

-- Test 9: Anon puede ejecutar get_team_landing_data por subdominio
SELECT is(
  (public.get_team_landing_data('guaiqueries')->'team'->>'name'),
  'Guaiqueríes de Margarita',
  'Anon retrieves correct team name from landing data'
);

-- Test 10: Retorna arena_name correcto
SELECT is(
  (public.get_team_landing_data('guaiqueries')->'team'->>'arena_name'),
  'Gimnasio Ciudad de La Asunción',
  'Anon retrieves official arena name'
);

-- Test 11: Retorna found = false para equipo inexistente
SELECT is(
  (public.get_team_landing_data('equipo-inexistente-xyz')->>'found')::boolean,
  false,
  'Returns found = false for non-existent team'
);

-- Test 12: Retorna found = false para string vacío
SELECT is(
  (public.get_team_landing_data('')->>'found')::boolean,
  false,
  'Returns found = false for empty identifier'
);

-- Test 13: Fan autenticado ordinario no puede actualizar perfil de landing
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "11000000-0000-0000-0000-000000000004", "role": "authenticated"}';

SELECT throws_ok(
  $$ SELECT public.admin_update_team_landing_profile('a0000000-0000-0000-0000-000000000001'::uuid, 'Nuevo Estadio') $$,
  '42501',
  NULL,
  'Regular fan cannot update team landing profile'
);

-- Test 14: Staff de otro equipo no puede actualizar perfil de Guaiqueríes
SET LOCAL "request.jwt.claims" = '{"sub": "11000000-0000-0000-0000-000000000003", "role": "authenticated"}';

SELECT throws_ok(
  $$ SELECT public.admin_update_team_landing_profile('a0000000-0000-0000-0000-000000000001'::uuid, 'Nuevo Estadio') $$,
  '42501',
  NULL,
  'Staff from another team cannot update Guaiqueries profile'
);

-- Test 15: Staff del equipo sí puede actualizar perfil de landing
SET LOCAL "request.jwt.claims" = '{"sub": "11000000-0000-0000-0000-000000000002", "role": "authenticated"}';

SELECT lives_ok(
  $$ SELECT public.admin_update_team_landing_profile(
      'a0000000-0000-0000-0000-000000000001'::uuid,
      'Gimnasio Ciudad de La Asunción - La Caldera Verde',
      'La Asunción, Isla de Margarita',
      'La Tribu Insular 8 veces campeona.',
      1977
  ) $$,
  'Team staff can update their team landing profile'
);

-- Test 16: Verificar que la actualización surtió efecto
SELECT is(
  (SELECT arena_name FROM public.teams WHERE id = 'a0000000-0000-0000-0000-000000000001'::uuid),
  'Gimnasio Ciudad de La Asunción - La Caldera Verde',
  'Arena name was updated successfully'
);

RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
