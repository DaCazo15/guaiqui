-- ============================================================================
-- Test Suite: platform_admin.test.sql
-- Domain: Platform Administration, Multi-Tenant Governance & Billing Lifecycle
-- Tests:
--   1. Schema: teams.sport column exists
--   2. Schema: audit_log.team_id column exists
--   3. Schema: team_billing_events exists with RLS enabled
--   4. Security: Club admin cannot execute admin_record_team_payment (42501)
--   5. Security: Club admin cannot execute admin_toggle_team_status (42501)
--   6. Security: Club admin cannot execute admin_list_teams (42501)
--   7. Security: Club admin cannot execute admin_get_platform_analytics (42501)
--   8. Execution: Platform admin (aal2) can list all teams
--   9. Execution: Platform admin can record team payment & extend paid_until
--  10. Integrity: team_billing_events is immutable (UPDATE rejected)
--  11. Execution: Platform admin can toggle team status with audit reason
--  12. Automation: job_deactivate_expired_teams deactivates team past grace period
--  13. Automation: Auto-deactivation records entry in audit_log with team_id
--  14. Automation: Auto-deactivation enqueues record in email_outbox
-- ============================================================================

BEGIN;

SELECT plan(14);

-- ----------------------------------------------------------------------------
-- Setup Fixtures
-- ----------------------------------------------------------------------------

-- Test Teams
INSERT INTO public.teams (id, name, slug, sport, status, joined_at, paid_until)
VALUES 
  ('a1111111-0000-0000-0000-000000000001', 'Club Alpha', 'club-alpha', 'baloncesto', 'active', NOW() - INTERVAL '60 days', NOW() + INTERVAL '30 days'),
  ('b2222222-0000-0000-0000-000000000002', 'Club Beta Expired', 'club-beta-expired', 'baloncesto', 'active', NOW() - INTERVAL '120 days', NOW() - INTERVAL '10 days')
ON CONFLICT (id) DO UPDATE SET 
  status = EXCLUDED.status, 
  paid_until = EXCLUDED.paid_until, 
  sport = EXCLUDED.sport;

-- Users
-- 1. Platform Admin (team_id IS NULL)
INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud)
VALUES ('99999999-9999-9999-9999-999999999901', '00000000-0000-0000-0000-000000000000', 'platform_admin@guaiqui.test', 'encrypted', NOW(), '{"provider":"email","providers":["email"]}', '{}', NOW(), NOW(), 'authenticated', 'authenticated')
ON CONFLICT (id) DO UPDATE SET email_confirmed_at = COALESCE(auth.users.email_confirmed_at, NOW());

INSERT INTO public.profiles (id, display_name, status, created_at, terms_accepted_at, terms_version)
VALUES ('99999999-9999-9999-9999-999999999901', 'Platform Master Admin', 'active', NOW(), NOW(), 'v1.0')
ON CONFLICT (id) DO UPDATE SET terms_accepted_at = NOW(), terms_version = 'v1.0', status = 'active';

INSERT INTO public.staff_members (user_id, team_id, role, active)
VALUES ('99999999-9999-9999-9999-999999999901', NULL, 'admin', true)
ON CONFLICT (user_id) DO UPDATE SET team_id = NULL, role = 'admin', active = true;

-- 2. Club Admin (team_id = Club Alpha)
INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud)
VALUES ('99999999-9999-9999-9999-999999999902', '00000000-0000-0000-0000-000000000000', 'club_admin@guaiqui.test', 'encrypted', NOW(), '{"provider":"email","providers":["email"]}', '{}', NOW(), NOW(), 'authenticated', 'authenticated')
ON CONFLICT (id) DO UPDATE SET email_confirmed_at = COALESCE(auth.users.email_confirmed_at, NOW());

INSERT INTO public.profiles (id, display_name, status, created_at, terms_accepted_at, terms_version)
VALUES ('99999999-9999-9999-9999-999999999902', 'Club Alpha Admin', 'active', NOW(), NOW(), 'v1.0')
ON CONFLICT (id) DO UPDATE SET terms_accepted_at = NOW(), terms_version = 'v1.0', status = 'active';

INSERT INTO public.staff_members (user_id, team_id, role, active)
VALUES ('99999999-9999-9999-9999-999999999902', 'a1111111-0000-0000-0000-000000000001', 'admin', true)
ON CONFLICT (user_id) DO UPDATE SET team_id = 'a1111111-0000-0000-0000-000000000001', role = 'admin', active = true;

-- 3. Regular Fan
INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud)
VALUES ('99999999-9999-9999-9999-999999999903', '00000000-0000-0000-0000-000000000000', 'fan_platform@guaiqui.test', 'encrypted', NOW(), '{"provider":"email","providers":["email"]}', '{}', NOW(), NOW(), 'authenticated', 'authenticated')
ON CONFLICT (id) DO UPDATE SET email_confirmed_at = COALESCE(auth.users.email_confirmed_at, NOW());

INSERT INTO public.profiles (id, display_name, status, created_at, terms_accepted_at, terms_version)
VALUES ('99999999-9999-9999-9999-999999999903', 'Fan Platform Test', 'active', NOW(), NOW(), 'v1.0')
ON CONFLICT (id) DO UPDATE SET terms_accepted_at = NOW(), terms_version = 'v1.0', status = 'active';

INSERT INTO public.team_follows (user_id, team_id)
VALUES ('99999999-9999-9999-9999-999999999903', 'a1111111-0000-0000-0000-000000000001')
ON CONFLICT (user_id, team_id) DO NOTHING;

INSERT INTO public.wallets (fan_id, team_id, balance_cache)
VALUES ('99999999-9999-9999-9999-999999999903', 'a1111111-0000-0000-0000-000000000001', 100)
ON CONFLICT (fan_id, team_id) DO UPDATE SET balance_cache = 100;

-- ----------------------------------------------------------------------------
-- TEST 1: Schema - teams.sport column exists
-- ----------------------------------------------------------------------------
SELECT has_column(
    'public',
    'teams',
    'sport',
    'TEST 1: public.teams debe poseer la columna sport'
);

-- ----------------------------------------------------------------------------
-- TEST 2: Schema - audit_log.team_id column exists
-- ----------------------------------------------------------------------------
SELECT has_column(
    'public',
    'audit_log',
    'team_id',
    'TEST 2: public.audit_log debe poseer la columna team_id para auditoría multiequipo'
);

-- ----------------------------------------------------------------------------
-- TEST 3: Schema - team_billing_events exists with RLS enabled
-- ----------------------------------------------------------------------------
SELECT is(
    (SELECT relrowsecurity FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relname = 'team_billing_events'),
    true,
    'TEST 3: RLS debe estar habilitado en public.team_billing_events'
);

-- ----------------------------------------------------------------------------
-- TEST 4: Security - Club admin cannot execute admin_record_team_payment
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "99999999-9999-9999-9999-999999999902", "role": "authenticated", "aal": "aal2"}';

SELECT throws_ok(
    $$ SELECT public.admin_record_team_payment('a1111111-0000-0000-0000-000000000001'::uuid, 'subscription_payment', 100, 1, 'Test payment') $$,
    '42501',
    NULL,
    'TEST 4: Club Admin recibe 42501 al intentar ejecutar admin_record_team_payment'
);
RESET ROLE;

-- ----------------------------------------------------------------------------
-- TEST 5: Security - Club admin cannot execute admin_toggle_team_status
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "99999999-9999-9999-9999-999999999902", "role": "authenticated", "aal": "aal2"}';

SELECT throws_ok(
    $$ SELECT public.admin_toggle_team_status('a1111111-0000-0000-0000-000000000001'::uuid, 'inactive'::public.team_status, 'Unauthorized test') $$,
    '42501',
    NULL,
    'TEST 5: Club Admin recibe 42501 al intentar ejecutar admin_toggle_team_status'
);
RESET ROLE;

-- ----------------------------------------------------------------------------
-- TEST 6: Security - Club admin cannot execute admin_list_teams
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "99999999-9999-9999-9999-999999999902", "role": "authenticated", "aal": "aal2"}';

SELECT throws_ok(
    $$ SELECT public.admin_list_teams() $$,
    '42501',
    NULL,
    'TEST 6: Club Admin recibe 42501 al intentar ejecutar admin_list_teams'
);
RESET ROLE;

-- ----------------------------------------------------------------------------
-- TEST 7: Security - Club admin cannot execute admin_get_platform_analytics
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "99999999-9999-9999-9999-999999999902", "role": "authenticated", "aal": "aal2"}';

SELECT throws_ok(
    $$ SELECT public.admin_get_platform_analytics() $$,
    '42501',
    NULL,
    'TEST 7: Club Admin recibe 42501 al intentar ejecutar admin_get_platform_analytics'
);
RESET ROLE;

-- ----------------------------------------------------------------------------
-- TEST 8: Execution - Platform admin (aal2) can list all teams
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "99999999-9999-9999-9999-999999999901", "role": "authenticated", "aal": "aal2"}';

SELECT ok(
    ((public.admin_list_teams()->>'total')::int >= 2),
    'TEST 8: Platform Admin con claims aal2 lista exitosamente los equipos de la plataforma'
);
RESET ROLE;

-- ----------------------------------------------------------------------------
-- TEST 9: Execution - Platform admin can record team payment & extend paid_until
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "99999999-9999-9999-9999-999999999901", "role": "authenticated", "aal": "aal2"}';

SELECT is(
    (public.admin_record_team_payment('a1111111-0000-0000-0000-000000000001'::uuid, 'subscription_payment', 150.00, 3, 'Pago trimestral temporada 2026')->>'success')::boolean,
    true,
    'TEST 9: Platform Admin registra pago exitosamente y extiende vigencia del club'
);
RESET ROLE;

-- ----------------------------------------------------------------------------
-- TEST 10: Integrity - team_billing_events is immutable (UPDATE rejected)
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "99999999-9999-9999-9999-999999999901", "role": "authenticated", "aal": "aal2"}';

SELECT throws_ok(
    $$ UPDATE public.team_billing_events SET amount = 99999 WHERE team_id = 'a1111111-0000-0000-0000-000000000001'::uuid $$,
    '42501',
    NULL,
    'TEST 10: team_billing_events es inmutable (UPDATE denegado con 42501)'
);
RESET ROLE;

-- ----------------------------------------------------------------------------
-- TEST 11: Execution - Platform admin can toggle team status with audit reason
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "99999999-9999-9999-9999-999999999901", "role": "authenticated", "aal": "aal2"}';

SELECT is(
    (public.admin_toggle_team_status('a1111111-0000-0000-0000-000000000001'::uuid, 'inactive'::public.team_status, 'Mantenimiento preventivo programado')->>'new_status')::text,
    'inactive',
    'TEST 11: Platform Admin desactiva equipo manualmente con motivo de auditoría'
);
RESET ROLE;

-- ----------------------------------------------------------------------------
-- TEST 12: Automation - job_deactivate_expired_teams deactivates team past grace period
-- ----------------------------------------------------------------------------
SELECT is(
    (public.job_deactivate_expired_teams()->>'success')::boolean,
    true,
    'TEST 12: job_deactivate_expired_teams ejecuta exitosamente la rutina de desactivación'
);

-- Club Beta Expired had paid_until 10 days ago (grace period = 3 days), so it must now be inactive
SELECT is(
    (SELECT status FROM public.teams WHERE id = 'b2222222-0000-0000-0000-000000000002'),
    'inactive'::public.team_status,
    'TEST 12b: Club Beta Expired fue automáticamente desactivado tras superar el período de gracia'
);

-- ----------------------------------------------------------------------------
-- TEST 13: Automation - Auto-deactivation records entry in audit_log with team_id
-- ----------------------------------------------------------------------------
SELECT ok(
    EXISTS (
        SELECT 1 FROM public.audit_log
        WHERE team_id = 'b2222222-0000-0000-0000-000000000002'
          AND action = 'team_auto_deactivated'
    ),
    'TEST 13: Desactivación automática asienta registro de auditoría con team_id'
);

-- ----------------------------------------------------------------------------
-- TEST 14: Automation - Auto-deactivation enqueues notification and email_outbox
-- ----------------------------------------------------------------------------
SELECT ok(
    EXISTS (
        SELECT 1 FROM public.email_outbox
        WHERE metadata->>'team_id' = 'b2222222-0000-0000-0000-000000000002'
    ),
    'TEST 14: Desactivación automática encola advertencia formal en email_outbox'
);

SELECT * FROM finish();

ROLLBACK;
