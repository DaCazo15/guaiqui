BEGIN;
SELECT plan(13);

-- Setup Teams
INSERT INTO public.teams (id, name, slug, status, primary_color, secondary_color) VALUES
  ('b0000000-0000-0000-0000-000000000001', 'Equipo Activo A', 'equipo-activo-a', 'active', '#005A36', '#E31B23'),
  ('b0000000-0000-0000-0000-000000000002', 'Equipo Inactivo B', 'equipo-inactivo-b', 'inactive', '#112233', '#445566'),
  ('b0000000-0000-0000-0000-000000000003', 'Equipo Activo C', 'equipo-activo-c', 'active', '#0000FF', '#FFFF00')
ON CONFLICT (id) DO UPDATE SET 
  name = EXCLUDED.name,
  slug = EXCLUDED.slug,
  status = EXCLUDED.status;

-- Setup Landing Content
INSERT INTO public.team_landing_content (team_id, hero_title, hero_subtitle) VALUES
  ('b0000000-0000-0000-0000-000000000001', 'Bienvenido a Equipo A', 'Tribu del Equipo A'),
  ('b0000000-0000-0000-0000-000000000002', 'Bienvenido a Equipo B', 'Tribu del Equipo B Secreta'),
  ('b0000000-0000-0000-0000-000000000003', 'Bienvenido a Equipo C', 'Tribu del Equipo C')
ON CONFLICT (team_id) DO UPDATE SET
  hero_title = EXCLUDED.hero_title,
  hero_subtitle = EXCLUDED.hero_subtitle;

-- Setup Users
INSERT INTO auth.users (id, email, aud, role, email_confirmed_at) VALUES
  ('b1111111-1111-1111-1111-111111111111', 'staff_a@test.com', 'authenticated', 'authenticated', NOW()),
  ('b2222222-2222-2222-2222-222222222222', 'staff_c@test.com', 'authenticated', 'authenticated', NOW()),
  ('b3333333-3333-3333-3333-333333333333', 'fan_sensible@test.com', 'authenticated', 'authenticated', NOW()),
  ('b4444444-4444-4444-4444-444444444444', 'platform_admin@test.com', 'authenticated', 'authenticated', NOW())
ON CONFLICT (id) DO UPDATE SET email_confirmed_at = NOW();

INSERT INTO public.profiles (id, display_name, phone, birth_date, municipality, shirt_size, status) VALUES
  ('b1111111-1111-1111-1111-111111111111', 'Staff A', '+584121111111', '1990-01-01', 'Mariño', 'L', 'active'),
  ('b2222222-2222-2222-2222-222222222222', 'Staff C', '+584122222222', '1991-02-02', 'Maneiro', 'M', 'active'),
  ('b3333333-3333-3333-3333-333333333333', 'Fan Ranking Secreto', '+584123333333', '1995-05-05', 'Arismendi', 'XL', 'active'),
  ('b4444444-4444-4444-4444-444444444444', 'Super Admin', '+584124444444', '1988-08-08', 'García', 'L', 'active')
ON CONFLICT (id) DO UPDATE SET display_name = EXCLUDED.display_name, status = 'active';

-- Staff Members
INSERT INTO public.staff_members (user_id, team_id, role, active) VALUES
  ('b1111111-1111-1111-1111-111111111111', 'b0000000-0000-0000-0000-000000000001', 'staff', true),
  ('b2222222-2222-2222-2222-222222222222', 'b0000000-0000-0000-0000-000000000003', 'staff', true),
  ('b4444444-4444-4444-4444-444444444444', NULL, 'admin', true)
ON CONFLICT (user_id) DO UPDATE SET team_id = EXCLUDED.team_id, role = EXCLUDED.role, active = true;

-- Seed Wallet for Fan in Team A
INSERT INTO public.wallets (fan_id, team_id, balance_cache) VALUES
  ('b3333333-3333-3333-3333-333333333333', 'b0000000-0000-0000-0000-000000000001', 500)
ON CONFLICT (fan_id, team_id) DO UPDATE SET balance_cache = 500;

-- ----------------------------------------------------------------------------
-- Test 1 & 2: Anon lee landing de equipo activo
-- ----------------------------------------------------------------------------
SET LOCAL ROLE anon;

SELECT is(
  (SELECT public.get_team_landing('equipo-activo-a')->>'status'),
  'active',
  'Anon lee landing de equipo activo con status active'
);

SELECT is(
  (SELECT public.get_team_landing('equipo-activo-a')->'team'->>'name'),
  'Equipo Activo A',
  'get_team_landing retorna el nombre y datos del equipo activo'
);

-- ----------------------------------------------------------------------------
-- Test 3: Cero datos privados expuestos en get_team_landing
-- ----------------------------------------------------------------------------
SELECT is(
  (
    SELECT (
      (public.get_team_landing('equipo-activo-a')::text LIKE '%+584123333333%') OR
      (public.get_team_landing('equipo-activo-a')::text LIKE '%fan_sensible@test.com%') OR
      (public.get_team_landing('equipo-activo-a')::text LIKE '%Arismendi%') OR
      (public.get_team_landing('equipo-activo-a')::text LIKE '%1995-05-05%')
    )
  ),
  false,
  'get_team_landing no expone teléfono, email, municipio ni fecha de nacimiento de los fanáticos en el ranking'
);

-- ----------------------------------------------------------------------------
-- Test 4: Anon ante equipo inactivo
-- ----------------------------------------------------------------------------
SELECT is(
  (SELECT public.get_team_landing('equipo-inactivo-b')->>'status'),
  'inactive',
  'get_team_landing ante equipo inactivo retorna status inactive'
);

-- ----------------------------------------------------------------------------
-- Test 5: Anon ante slug inexistente
-- ----------------------------------------------------------------------------
SELECT is(
  (SELECT public.get_team_landing('slug-que-no-existe-xyz')->>'status'),
  'not_found',
  'get_team_landing ante slug inexistente retorna status not_found'
);

-- ----------------------------------------------------------------------------
-- Test 6: Anon ejecuta get_platform_landing exitosamente
-- ----------------------------------------------------------------------------
SELECT ok(
  (SELECT jsonb_array_length(public.get_platform_landing()->'teams') >= 2),
  'get_platform_landing retorna arreglo con equipos activos'
);

-- ----------------------------------------------------------------------------
-- Test 7 & 8: RLS de team_landing_content para anon
-- ----------------------------------------------------------------------------
SELECT is(
  (SELECT COUNT(*) FROM public.team_landing_content WHERE team_id = 'b0000000-0000-0000-0000-000000000001'),
  1::bigint,
  'Anon puede consultar team_landing_content de equipo activo'
);

SELECT is(
  (SELECT COUNT(*) FROM public.team_landing_content WHERE team_id = 'b0000000-0000-0000-0000-000000000002'),
  0::bigint,
  'Anon no puede consultar team_landing_content de equipo inactivo (bloqueado por RLS)'
);

-- ----------------------------------------------------------------------------
-- Test 9 & 10: Anon no escribe en team_landing_content ni ejecuta RPC restringida
-- ----------------------------------------------------------------------------
SELECT throws_ok(
  $$ INSERT INTO public.team_landing_content (team_id, hero_title, hero_subtitle) VALUES ('b0000000-0000-0000-0000-000000000001', 'Hack', 'Hack') $$,
  '42501',
  NULL,
  'Anon no puede insertar en team_landing_content'
);

SELECT throws_ok(
  $$ SELECT public.update_team_landing_content('b0000000-0000-0000-0000-000000000001', 'Hack', 'Hack') $$,
  '42501',
  NULL,
  'Anon no puede ejecutar update_team_landing_content'
);

-- ----------------------------------------------------------------------------
-- Test 11: Staff del Equipo A actualiza su propia landing
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "b1111111-1111-1111-1111-111111111111", "role": "authenticated"}';

SELECT lives_ok(
  $$ SELECT public.update_team_landing_content('b0000000-0000-0000-0000-000000000001', 'Nuevo Titulo A', 'Nuevo Subtitulo A') $$,
  'Staff de Equipo A puede actualizar la landing de su equipo'
);

-- ----------------------------------------------------------------------------
-- Test 12: Staff del Equipo A NO puede actualizar landing del Equipo C
-- ----------------------------------------------------------------------------
SELECT throws_ok(
  $$ SELECT public.update_team_landing_content('b0000000-0000-0000-0000-000000000003', 'Ataque Cruzado', 'Ataque') $$,
  '42501',
  NULL,
  'Staff de Equipo A no puede actualizar la landing de Equipo C'
);

-- ----------------------------------------------------------------------------
-- Test 13: Platform Admin puede actualizar landing de cualquier equipo
-- ----------------------------------------------------------------------------
SET LOCAL "request.jwt.claims" = '{"sub": "b4444444-4444-4444-4444-444444444444", "role": "authenticated"}';

SELECT lives_ok(
  $$ SELECT public.update_team_landing_content('b0000000-0000-0000-0000-000000000003', 'Titulo por Admin', 'Subtitulo por Admin') $$,
  'Platform Admin puede actualizar la landing de cualquier equipo'
);

SELECT finish();
ROLLBACK;
