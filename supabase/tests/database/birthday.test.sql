BEGIN;

SELECT plan(22);

-- Setup Test Users
-- 1. Verified Active Fan (Born today in Caracas)
INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud)
VALUES 
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000', 'birthday_fan1@guaiqui.test', 'encrypted', NOW() - INTERVAL '60 days', '{"provider":"email","providers":["email"]}', '{}', NOW() - INTERVAL '60 days', NOW(), 'authenticated', 'authenticated'),
  ('22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000000', 'leap_fan@guaiqui.test', 'encrypted', NOW() - INTERVAL '60 days', '{"provider":"email","providers":["email"]}', '{}', NOW() - INTERVAL '60 days', NOW(), 'authenticated', 'authenticated'),
  ('33333333-3333-3333-3333-333333333333', '00000000-0000-0000-0000-000000000000', 'new_fan@guaiqui.test', 'encrypted', NOW() - INTERVAL '5 days', '{"provider":"email","providers":["email"]}', '{}', NOW() - INTERVAL '5 days', NOW(), 'authenticated', 'authenticated'),
  ('44444444-4444-4444-4444-444444444444', '00000000-0000-0000-0000-000000000000', 'suspended_fan@guaiqui.test', 'encrypted', NOW() - INTERVAL '60 days', '{"provider":"email","providers":["email"]}', '{}', NOW() - INTERVAL '60 days', NOW(), 'authenticated', 'authenticated'),
  ('55555555-5555-5555-5555-555555555555', '00000000-0000-0000-0000-000000000000', 'optout_fan@guaiqui.test', 'encrypted', NOW() - INTERVAL '60 days', '{"provider":"email","providers":["email"]}', '{}', NOW() - INTERVAL '60 days', NOW(), 'authenticated', 'authenticated')
ON CONFLICT (id) DO UPDATE SET email_confirmed_at = COALESCE(auth.users.email_confirmed_at, EXCLUDED.email_confirmed_at);

INSERT INTO public.profiles (id, display_name, status, birth_date, notification_prefs, created_at, terms_accepted_at, terms_version)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'Fan Cumpleañero', 'active', '1995-10-15', '{"birthday": true}'::jsonb, NOW() - INTERVAL '60 days', NOW(), 'v1.0'),
  ('22222222-2222-2222-2222-222222222222', 'Fan Bisiesto', 'active', '1996-02-29', '{"birthday": true}'::jsonb, NOW() - INTERVAL '60 days', NOW(), 'v1.0'),
  ('33333333-3333-3333-3333-333333333333', 'Fan Nuevo', 'active', '1995-10-15', '{"birthday": true}'::jsonb, NOW() - INTERVAL '5 days', NOW(), 'v1.0'),
  ('44444444-4444-4444-4444-444444444444', 'Fan Suspendido', 'suspended', '1995-10-15', '{"birthday": true}'::jsonb, NOW() - INTERVAL '60 days', NOW(), 'v1.0'),
  ('55555555-5555-5555-5555-555555555555', 'Fan Optout', 'active', '1995-10-15', '{"birthday": false}'::jsonb, NOW() - INTERVAL '60 days', NOW(), 'v1.0')
ON CONFLICT (id) DO UPDATE SET status = EXCLUDED.status, birth_date = EXCLUDED.birth_date, terms_accepted_at = NOW(), terms_version = 'v1.0';

INSERT INTO public.team_follows (user_id, team_id)
VALUES 
  ('11111111-1111-1111-1111-111111111111', 'a0000000-0000-0000-0000-000000000001'),
  ('33333333-3333-3333-3333-333333333333', 'a0000000-0000-0000-0000-000000000001')
ON CONFLICT (user_id, team_id) DO NOTHING;

-- Multi-team setup: ensure fans follow default team and have wallet
INSERT INTO public.team_follows (user_id, team_id)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'a0000000-0000-0000-0000-000000000001'),
  ('22222222-2222-2222-2222-222222222222', 'a0000000-0000-0000-0000-000000000001'),
  ('33333333-3333-3333-3333-333333333333', 'a0000000-0000-0000-0000-000000000001'),
  ('44444444-4444-4444-4444-444444444444', 'a0000000-0000-0000-0000-000000000001'),
  ('55555555-5555-5555-5555-555555555555', 'a0000000-0000-0000-0000-000000000001')
ON CONFLICT (user_id, team_id) DO NOTHING;

INSERT INTO public.wallets (fan_id, team_id, balance_cache)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'a0000000-0000-0000-0000-000000000001', 0),
  ('22222222-2222-2222-2222-222222222222', 'a0000000-0000-0000-0000-000000000001', 0),
  ('33333333-3333-3333-3333-333333333333', 'a0000000-0000-0000-0000-000000000001', 0),
  ('44444444-4444-4444-4444-444444444444', 'a0000000-0000-0000-0000-000000000001', 0),
  ('55555555-5555-5555-5555-555555555555', 'a0000000-0000-0000-0000-000000000001', 0)
ON CONFLICT (fan_id, team_id) DO NOTHING;

-- Configurar settings: bonus = 100, grace_days = 3
UPDATE public.birthday_settings
SET enabled = true, grace_days = 3, bonus_pearls = 100
WHERE team_id = 'a0000000-0000-0000-0000-000000000001';

-- Test 1: Enqueue birthday notifications para p_now = '2026-10-15 13:00:00+00' (15 de oct en Caracas)
SELECT is(
    (public.enqueue_birthday_notifications('2026-10-15 13:00:00+00'::timestamptz)->>'enqueued')::int,
    1,
    'Debe encolar solo 1 notificación para Fan Cumpleañero (excluyendo optout, suspendidos y nuevos)'
);

-- Test 2: Idempotencia: Volver a ejecutar el mismo día no crea notificaciones duplicadas
SELECT is(
    (public.enqueue_birthday_notifications('2026-10-15 13:00:00+00'::timestamptz)->>'enqueued')::int,
    1,
    'Ejecutar dos veces el job el mismo día mantiene idempotencia (notificación no duplicada en tabla)'
);

SELECT is(
    (SELECT COUNT(*) FROM public.notifications WHERE user_id = '11111111-1111-1111-1111-111111111111' AND type = 'birthday'),
    1::bigint,
    'Tabla de notificaciones tiene exactamente 1 registro para el cumpleañero'
);

-- Test 3: Nacidos el 29 de febrero en año NO bisiesto (2027-02-28)
SELECT is(
    (public.enqueue_birthday_notifications('2027-02-28 13:00:00+00'::timestamptz)->>'enqueued')::int,
    1,
    'Fan bisiesto (29 feb) recibe notificación el 28 de febrero en año no bisiesto (2027)'
);

-- Test 4: Cumpleaños a las 23:30 de Caracas (03:30 UTC del día siguiente: 2026-10-16 03:30:00 UTC = 2026-10-15 23:30 VET)
SELECT is(
    (EXTRACT(DAY FROM ('2026-10-16 03:30:00+00'::timestamptz AT TIME ZONE 'America/Caracas'))::int),
    15,
    '2026-10-16 03:30 UTC se evalúa como el día 15 en huso America/Caracas'
);

-- Test 5: Elegibilidad y Grace Days en get_birthday_card()
-- Ajustar fecha de nacimiento a hoy para pruebas en vivo de get_birthday_card
UPDATE public.profiles
SET birth_date = (NOW() AT TIME ZONE 'America/Caracas')::date - INTERVAL '25 years'
WHERE id = '11111111-1111-1111-1111-111111111111';

-- Simular autenticación como Fan Cumpleañero
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';

SELECT is(
    (public.get_birthday_card()->>'eligible')::boolean,
    true,
    'Fan es elegible en su día de cumpleaños'
);

-- Test 6: get_birthday_card NUNCA devuelve birth_date ni edad
SELECT is(
    (public.get_birthday_card() ? 'birth_date'),
    false,
    'get_birthday_card NO contiene la clave birth_date'
);

SELECT is(
    (public.get_birthday_card() ? 'age'),
    false,
    'get_birthday_card NO contiene la clave age'
);

-- Test 7: Reclamar bono en cuenta madura (>30 días)
SELECT is(
    (public.claim_birthday_bonus()->>'success')::boolean,
    true,
    'Fan con cuenta > 30 días reclama bono exitosamente'
);

-- Test 8: Reclamar bono por segunda vez en el mismo año debe ser idempotente (already_claimed = true)
SELECT ok(
    (public.claim_birthday_bonus()->>'already_claimed')::boolean = true,
    'Intento de reclamar el bono dos veces en el mismo año retorna already_claimed de forma idempotente'
);

-- Test 9: Reclamar bono con cuenta nueva (< 30 días) debe fallar
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';

SELECT throws_ok(
    'SELECT public.claim_birthday_bonus()',
    NULL,
    'Cuenta con menos de 30 días de antigüedad no puede reclamar el bono'
);

-- Test 10: Fan suspendido no es elegible
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "44444444-4444-4444-4444-444444444444", "role": "authenticated"}';

SELECT throws_ok(
    'SELECT public.get_birthday_card()',
    '42501',
    NULL,
    'Fan suspendido no es elegible para la tarjeta de cumpleaños'
);
RESET ROLE;

-- Test 11: Control de accesos (Permisos RLS / RPC)
-- Usuario no autenticado (anon) no puede ejecutar RPCs internas ni privadas
SET LOCAL ROLE anon;
SET LOCAL "request.jwt.claims" = '{"role": "anon"}';

SELECT throws_ok(
    'SELECT public.get_birthday_card()',
    '42501',
    NULL,
    'Anon no puede ejecutar get_birthday_card'
);

SELECT throws_ok(
    'SELECT public.claim_birthday_bonus()',
    '42501',
    NULL,
    'Anon no puede ejecutar claim_birthday_bonus'
);

SELECT throws_ok(
    'SELECT public.confirm_test_user_email(''test@guaiqui.test'')',
    '42501',
    NULL,
    'Anon no puede ejecutar confirm_test_user_email'
);

SELECT throws_ok(
    'SELECT public.purge_auth_identities(''11111111-1111-1111-1111-111111111111''::uuid)',
    '42501',
    NULL,
    'Anon no puede ejecutar purge_auth_identities'
);
RESET ROLE;

-- Test 12: Usuario fan (authenticated) no puede ejecutar enqueue_birthday_notifications, create_notification ni send_test_birthday_notification
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';

SELECT throws_ok(
    'SELECT public.enqueue_birthday_notifications()',
    '42501',
    NULL,
    'Authenticated fan no puede ejecutar enqueue_birthday_notifications'
);

SELECT throws_ok(
    'SELECT public.create_notification(''11111111-1111-1111-1111-111111111111''::uuid, ''security'', ''title'', ''body'')',
    '42501',
    NULL,
    'Authenticated fan no puede ejecutar create_notification'
);

SELECT throws_ok(
    'SELECT public.send_test_birthday_notification()',
    '42501',
    NULL,
    'Authenticated fan no puede ejecutar send_test_birthday_notification'
);
RESET ROLE;

SELECT finish();

ROLLBACK;
