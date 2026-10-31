-- ============================================================================
-- Test: profile_and_leaderboard.test.sql
-- Domain: Perfil Enriquecido, Insignias, Vincular Referente y Ranking Multi-Equipo
-- ============================================================================

BEGIN;
SELECT plan(15);

-- 1. Setup de usuarios de prueba
INSERT INTO auth.users (id, email, aud, role, email_confirmed_at) VALUES
  ('22000000-0000-0000-0000-000000000001', 'ref_owner@guaiqueries.com', 'authenticated', 'authenticated', NOW()),
  ('22000000-0000-0000-0000-000000000002', 'new_fan@guaiqueries.com', 'authenticated', 'authenticated', NOW()),
  ('22000000-0000-0000-0000-000000000003', 'fan_three@guaiqueries.com', 'authenticated', 'authenticated', NOW())
ON CONFLICT (id) DO UPDATE SET email_confirmed_at = NOW();

INSERT INTO public.profiles (id, display_name, status, terms_version, terms_accepted_at, privacy_accepted_at, pearls_rules_accepted_at) VALUES
  ('22000000-0000-0000-0000-000000000001', 'Referidor Pro', 'active', 'v1.0', NOW(), NOW(), NOW()),
  ('22000000-0000-0000-0000-000000000002', 'Nuevo Fanatico', 'active', 'v1.0', NOW(), NOW(), NOW()),
  ('22000000-0000-0000-0000-000000000003', 'Tercer Fanatico', 'active', 'v1.0', NOW(), NOW(), NOW())
ON CONFLICT (id) DO UPDATE SET terms_accepted_at = NOW(), privacy_accepted_at = NOW(), pearls_rules_accepted_at = NOW();

-- Código de referido conocido para user 1
INSERT INTO public.referral_codes (user_id, code) VALUES
  ('22000000-0000-0000-0000-000000000001', 'TESTREF1')
ON CONFLICT (user_id) DO UPDATE SET code = 'TESTREF1';

-- Movimiento en ledger para ranking
INSERT INTO public.ledger_entries (
  id, fan_id, team_id, amount, type, status, created_at
) VALUES (
  'e1111111-1111-1111-1111-111111111111',
  '22000000-0000-0000-0000-000000000001',
  'a0000000-0000-0000-0000-000000000001',
  150,
  'trivia_reward',
  'confirmed',
  NOW()
) ON CONFLICT (id) DO NOTHING;

-- Seguir al equipo
INSERT INTO public.team_follows (user_id, team_id) VALUES
  ('22000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001')
ON CONFLICT (user_id, team_id) DO NOTHING;

-- Test 1 & 2: Tablas badges y fan_badges
SELECT has_table('public', 'badges', 'badges table exists');
SELECT has_table('public', 'fan_badges', 'fan_badges table exists');

-- Test 3: Insignias sembradas
SELECT is(
  (SELECT COUNT(*) FROM public.badges WHERE slug IN ('fan_fiel', 'primer_canje', 'embajador')),
  3::bigint,
  'Official system badges exist'
);

-- Test 4: Anon no puede invocar claim_referral_code
SET LOCAL ROLE anon;
SELECT throws_ok(
  $$ SELECT public.claim_referral_code('TESTREF1') $$,
  '42501',
  NULL,
  'Anon cannot claim referral code'
);

-- Test 5: Usuario autenticado no puede reclamar su propio código
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "22000000-0000-0000-0000-000000000001", "role": "authenticated"}';

SELECT throws_ok(
  $$ SELECT public.claim_referral_code('TESTREF1') $$,
  'P0003',
  NULL,
  'User cannot claim their own referral code'
);

-- Test 6: Usuario 2 vincula exitosamente el código de usuario 1
SET LOCAL "request.jwt.claims" = '{"sub": "22000000-0000-0000-0000-000000000002", "role": "authenticated"}';

SELECT is(
  (public.claim_referral_code('TESTREF1')->>'success')::boolean,
  true,
  'New fan successfully links referral code'
);

-- Test 7: get_my_referral_summary para usuario 2 proyecta referred_by
SELECT is(
  (public.get_my_referral_summary()->'referred_by'->>'has_referrer')::boolean,
  true,
  'Referee summary projects has_referrer = true'
);

SELECT is(
  (public.get_my_referral_summary()->'referred_by'->>'referrer_name'),
  'Referidor Pro',
  'Referee summary projects correct referrer name'
);

-- Test 9: Usuario 2 no puede vincular un segundo código
SELECT throws_ok(
  $$ SELECT public.claim_referral_code('OTHER99') $$,
  '42501',
  NULL,
  'User cannot link a second referral code'
);

-- Test 10: Referidor tiene concesión pendiente creada
SELECT is(
  (SELECT COUNT(*) FROM public.pending_pearl_grants WHERE fan_id = '22000000-0000-0000-0000-000000000001' AND source = 'referral_signup'),
  1::bigint,
  'Referrer received 5 pending pearls grant'
);

-- Test 11: get_fan_profile_enriched retorna nivel e insignias
SET LOCAL "request.jwt.claims" = '{"sub": "22000000-0000-0000-0000-000000000001", "role": "authenticated"}';

SELECT is(
  (public.get_fan_profile_enriched()->>'found')::boolean,
  true,
  'Enriched profile returns found = true'
);

SELECT is(
  (public.get_fan_profile_enriched()->'level'->>'tier_name'),
  'Fan Novato',
  'Returns correct fan tier for pearls earned'
);

-- Test 13: Leaderboard funciona para todos los equipos
SELECT is(
  (public.get_leaderboard('all_time', NULL)->>'period'),
  'all_time',
  'Leaderboard returns all_time period'
);

-- Test 14: Leaderboard con filtro por equipo Guaiqueríes
SELECT is(
  (public.get_leaderboard('all_time', 'a0000000-0000-0000-0000-000000000001'::uuid)->'team'->>'name'),
  'Guaiqueríes de Margarita',
  'Team-scoped leaderboard returns team metadata'
);

-- Test 15: Leaderboard calcula my_rank para el usuario en sesión
SELECT is(
  (public.get_leaderboard('all_time', 'a0000000-0000-0000-0000-000000000001'::uuid)->'my_rank'->>'rank')::int,
  1,
  'Calculates my_rank correctly for current user'
);

RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
