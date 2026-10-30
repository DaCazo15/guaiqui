BEGIN;
SELECT plan(15);

-- Setup test users
INSERT INTO auth.users (id, email, aud, role, email_confirmed_at) VALUES
  ('00000000-0000-0000-0000-000000000001', 'admin@guaiqueries.com', 'authenticated', 'authenticated', NOW()),
  ('00000000-0000-0000-0000-000000000002', 'staff@guaiqueries.com', 'authenticated', 'authenticated', NOW()),
  ('00000000-0000-0000-0000-000000000003', 'fan@guaiqueries.com', 'authenticated', 'authenticated', NOW())
ON CONFLICT (id) DO UPDATE SET email_confirmed_at = NOW();

INSERT INTO public.profiles (id, display_name, status, terms_accepted_at, privacy_accepted_at, pearls_rules_accepted_at) VALUES
  ('00000000-0000-0000-0000-000000000001', 'Admin User', 'active', NOW(), NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000002', 'Staff User', 'active', NOW(), NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000003', 'Fan User', 'active', NOW(), NOW(), NOW())
ON CONFLICT (id) DO UPDATE SET status = 'active', terms_accepted_at = NOW(), privacy_accepted_at = NOW(), pearls_rules_accepted_at = NOW();

INSERT INTO public.staff_members (user_id, team_id, role, active) VALUES
  ('00000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'admin', true),
  ('00000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'staff', true)
ON CONFLICT (user_id) DO UPDATE SET team_id = 'a0000000-0000-0000-0000-000000000001', role = EXCLUDED.role, active = true;

INSERT INTO public.wallets (fan_id, team_id, balance_cache) VALUES
  ('00000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 500)
ON CONFLICT (fan_id, team_id) DO UPDATE SET balance_cache = 500;

INSERT INTO public.economy_settings (daily_pearl_cap, weekly_pearl_cap) VALUES (1000, 5000);

-- Test 1 & 2: Fan and Staff cannot call assert_admin()
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "00000000-0000-0000-0000-000000000003", "role": "authenticated"}';

SELECT throws_ok(
  $$ SELECT public.assert_admin() $$,
  '42501',
  'Admin authorization required.',
  'Fan call to assert_admin fails'
);

SET LOCAL "request.jwt.claims" = '{"sub": "00000000-0000-0000-0000-000000000002", "role": "authenticated"}';

SELECT throws_ok(
  $$ SELECT public.assert_admin() $$,
  '42501',
  'Admin authorization required.',
  'Staff call to assert_admin fails'
);

-- Test 3: Admin call to assert_admin succeeds
SET LOCAL "request.jwt.claims" = '{"sub": "00000000-0000-0000-0000-000000000001", "role": "authenticated", "aal": "aal2"}';
SELECT is(public.assert_admin(), true, 'Admin call to assert_admin succeeds');

-- Test 4: audit_log rejects UPDATE and DELETE
SELECT throws_ok(
  $$ UPDATE public.audit_log SET action = 'hacked' $$,
  'Audit Log entries are immutable. UPDATE and DELETE operations are forbidden.',
  'audit_log UPDATE trigger blocks mutation'
);

SELECT throws_ok(
  $$ DELETE FROM public.audit_log $$,
  'Audit Log entries are immutable. UPDATE and DELETE operations are forbidden.',
  'audit_log DELETE trigger blocks mutation'
);

-- Test 5: publish_trivia rejects trivia with 0 questions
SET LOCAL "request.jwt.claims" = '{"sub": "00000000-0000-0000-0000-000000000001", "role": "authenticated", "aal": "aal2"}';
INSERT INTO public.trivias (id, team_id, title, status, starts_at, ends_at, time_limit_seconds)
VALUES ('11111111-1111-1111-1111-111111111111', 'a0000000-0000-0000-0000-000000000001', 'Trivia Vacia', 'draft', NOW(), NOW() + INTERVAL '1 day', 60);

SELECT throws_ok(
  $$ SELECT public.admin_publish_trivia('11111111-1111-1111-1111-111111111111'::uuid) $$,
  'La trivia debe tener al menos una pregunta para poder publicarse.',
  'publish_trivia rejects trivia with 0 questions'
);

-- Test 6: publish_trivia rejects question without correct answer
INSERT INTO public.trivia_questions (id, team_id, trivia_id, question_text, points)
VALUES ('22222222-2222-2222-2222-222222222222', 'a0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', '¿Cuál es el capital?', 50);

INSERT INTO public.trivia_options (question_id, option_text, is_correct)
VALUES ('33333333-3333-3333-3333-333333333333', 'La Asunción', false);

SELECT throws_ok(
  $$ SELECT public.admin_publish_trivia('11111111-1111-1111-1111-111111111111'::uuid) $$,
  'Cada pregunta debe tener exactamente una opción correcta.',
  'publish_trivia rejects question with 0 correct options'
);

-- Test 7: publish_trivia succeeds when valid
UPDATE public.trivia_options SET is_correct = true WHERE id = '33333333-3333-3333-3333-333333333333';

SELECT lives_ok(
  $$ SELECT public.admin_publish_trivia('11111111-1111-1111-1111-111111111111'::uuid) $$,
  'publish_trivia succeeds when trivia is valid'
);

-- Test 8: Cannot demote or deactivate the last active admin
SELECT throws_ok(
  $$ SELECT public.admin_toggle_staff_active('00000000-0000-0000-0000-000000000001'::uuid, false) $$,
  'Un administrador no puede desactivar su propia cuenta.',
  'Admin cannot deactivate self'
);

SELECT throws_ok(
  $$ SELECT public.admin_update_staff_role('00000000-0000-0000-0000-000000000001'::uuid, 'staff'::staff_role) $$,
  'Un administrador no puede modificar su propio rol.',
  'Admin cannot demote self'
);

-- Test 9: Price change on product does not alter past redemptions cost_pearls
INSERT INTO public.products (id, team_id, name, cost_pearls, stock)
VALUES ('44444444-4444-4444-4444-444444444444', 'a0000000-0000-0000-0000-000000000001', 'Camiseta Oficial', 500, 10);

INSERT INTO public.redemptions (id, team_id, fan_id, product_id, cost_pearls, code_hash, idempotency_key)
VALUES ('55555555-5555-5555-5555-555555555555', 'a0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', '44444444-4444-4444-4444-444444444444', 500, 'hash123', 'idemp123');

-- Admin updates price to 800
SELECT public.admin_upsert_product('{"id": "44444444-4444-4444-4444-444444444444", "team_id": "a0000000-0000-0000-0000-000000000001", "name": "Camiseta Oficial", "cost_pearls": 800, "stock": 10}'::jsonb);

-- Verify past redemption cost is still 500
SELECT is(
  (SELECT cost_pearls FROM public.redemptions WHERE id = '55555555-5555-5555-5555-555555555555'),
  500,
  'Past redemption cost remains frozen despite product price update'
);

-- Test 10: Segment filter validation rejects non-whitelisted keys
SELECT throws_ok(
  $$ SELECT public.admin_upsert_segment('{"team_id": "a0000000-0000-0000-0000-000000000001", "name": "Bad Segment", "filters": {"invalid_field": "test"}}'::jsonb) $$,
  'Campo de filtro no permitido en segmentos: invalid_field',
  'Segment filter rejects disallowed key'
);

-- Test 11: Refund issue adds positive ledger entry exactly once
SELECT lives_ok(
  $$ SELECT public.admin_resolve_redemption_issue('55555555-5555-5555-5555-555555555555'::uuid, 'refund', 'Producto defectuoso') $$,
  'admin_resolve_redemption_issue refund succeeds'
);

SELECT throws_ok(
  $$ SELECT public.admin_resolve_redemption_issue('55555555-5555-5555-5555-555555555555'::uuid, 'refund', 'Segundo intento') $$,
  'Este canje ya ha sido reembolsado previamente.',
  'Second refund call for same redemption is rejected'
);

SELECT finish();
ROLLBACK;
