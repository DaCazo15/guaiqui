BEGIN;
SELECT plan(10);

-- Setup users
INSERT INTO auth.users (id, email, aud, role, email_confirmed_at) VALUES
  ('00000000-0000-0000-0000-000000000001', 'admin9b@guaiqueries.com', 'authenticated', 'authenticated', NOW()),
  ('00000000-0000-0000-0000-000000000002', 'staff9b@guaiqueries.com', 'authenticated', 'authenticated', NOW())
ON CONFLICT (id) DO UPDATE SET email_confirmed_at = NOW();

INSERT INTO public.profiles (id, display_name, status, terms_version, terms_accepted_at, privacy_accepted_at, pearls_rules_accepted_at) VALUES
  ('00000000-0000-0000-0000-000000000001', 'Admin 9B', 'active', 'v1.0', NOW(), NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000002', 'Staff 9B', 'active', 'v1.0', NOW(), NOW(), NOW())
ON CONFLICT (id) DO UPDATE SET terms_accepted_at = NOW(), privacy_accepted_at = NOW(), pearls_rules_accepted_at = NOW();

INSERT INTO public.staff_members (user_id, team_id, role, active) VALUES
  ('00000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'admin', true),
  ('00000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'staff', true)
ON CONFLICT (user_id) DO UPDATE SET team_id = 'a0000000-0000-0000-0000-000000000001', role = EXCLUDED.role, active = true;

-- Seed content (1 published, 1 unpublished)
INSERT INTO public.site_announcements (id, team_id, message, is_published) VALUES
  ('a1111111-1111-1111-1111-111111111111', 'a0000000-0000-0000-0000-000000000001', 'Anuncio Publico', true),
  ('a2222222-2222-2222-2222-222222222222', 'a0000000-0000-0000-0000-000000000001', 'Borrador Oculto', false);

-- Test 1 & 2: Anon reads only published announcements
SET LOCAL ROLE anon;
SELECT is(
  (SELECT COUNT(*) FROM public.site_announcements),
  1::bigint,
  'Anon sees only published announcements'
);

SELECT throws_ok(
  $$ INSERT INTO public.site_announcements (message) VALUES ('Hacked') $$,
  '42501',
  NULL,
  'Anon write to site_announcements is rejected'
);

-- Test 3 & 4: Staff cannot insert into site_announcements or publish policies
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "00000000-0000-0000-0000-000000000002", "role": "authenticated"}';

SELECT throws_ok(
  $$ INSERT INTO public.site_announcements (message) VALUES ('Staff Message') $$,
  '42501',
  NULL,
  'Staff write to site_announcements is rejected'
);

SELECT throws_ok(
  $$ SELECT public.admin_publish_policy('terminos', 'v2.0', 'Nuevos terminos') $$,
  '42501',
  'Admin authorization required.',
  'Staff publish_policy is rejected'
);

-- Test 5 & 6: Admin can publish policy and new version replaces active version
SET LOCAL "request.jwt.claims" = '{"sub": "00000000-0000-0000-0000-000000000001", "role": "authenticated", "aal": "aal2"}';

SELECT lives_ok(
  $$ SELECT public.admin_publish_policy('terminos', 'v2.0', 'Términos v2.0 actualizados') $$,
  'Admin successfully publishes new policy version v2.0'
);

SELECT is(
  (SELECT version FROM public.policy_documents WHERE slug = 'terminos' AND is_active = true LIMIT 1),
  'v2.0',
  'New policy version v2.0 is now active'
);

SELECT is(
  (SELECT COUNT(*) FROM public.policy_documents WHERE slug = 'terminos' AND is_active = true),
  1::bigint,
  'Exactly one active version exists for terminos'
);

-- Test 7: get_active_legal_versions returns active versions
SELECT is(
  (SELECT public.get_active_legal_versions()->>'terminos'),
  'v2.0',
  'get_active_legal_versions returns updated v2.0 version'
);

-- Test 8: Old profile with v1.0 terms is now out of date compared to v2.0 active
SELECT is(
  ((SELECT terms_version FROM public.profiles WHERE id = '00000000-0000-0000-0000-000000000002') = (SELECT public.get_active_legal_versions()->>'terminos')),
  false,
  'User with v1.0 has outdated terms version compared to v2.0 active'
);

-- Test 9: Admin can insert into site_team_members
SELECT lives_ok(
  $$ INSERT INTO public.site_team_members (team_id, name, role, group_category) VALUES ('a0000000-0000-0000-0000-000000000001', 'Carlos Perez', 'DT', 'tecnico') $$,
  'Admin can insert into site_team_members'
);

SELECT finish();
ROLLBACK;
