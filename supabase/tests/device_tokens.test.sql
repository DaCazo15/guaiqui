BEGIN;
SELECT plan(8);

-- Setup Users
INSERT INTO auth.users (id, email, aud, role, email_confirmed_at) VALUES
  ('c1111111-1111-1111-1111-111111111111', 'fan_mobile_1@test.com', 'authenticated', 'authenticated', NOW()),
  ('c2222222-2222-2222-2222-222222222222', 'fan_mobile_2@test.com', 'authenticated', 'authenticated', NOW())
ON CONFLICT (id) DO UPDATE SET email_confirmed_at = NOW();

INSERT INTO public.profiles (id, display_name, status) VALUES
  ('c1111111-1111-1111-1111-111111111111', 'Fan Mobile 1', 'active'),
  ('c2222222-2222-2222-2222-222222222222', 'Fan Mobile 2', 'active')
ON CONFLICT (id) DO UPDATE SET display_name = EXCLUDED.display_name, status = 'active';

-- ----------------------------------------------------------------------------
-- Test 1, 2, 3: Anon bloqueado sin acceso
-- ----------------------------------------------------------------------------
SET LOCAL ROLE anon;

SELECT is(
  (SELECT COUNT(*) FROM public.device_tokens),
  0::bigint,
  'Anon no puede ver ningún token de dispositivo'
);

SELECT throws_ok(
  $$ INSERT INTO public.device_tokens (fan_id, token, platform) VALUES ('c1111111-1111-1111-1111-111111111111', 'fcm-token-anon', 'android') $$,
  '42501',
  NULL,
  'Anon no puede insertar tokens de dispositivo'
);

SELECT throws_ok(
  $$ SELECT public.register_device_token('fcm-token-anon', 'android') $$,
  '42501',
  NULL,
  'Anon no puede ejecutar register_device_token'
);

-- ----------------------------------------------------------------------------
-- Test 4 & 5: Usuario 1 registra y consulta su propio token
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "c1111111-1111-1111-1111-111111111111", "role": "authenticated"}';

SELECT lives_ok(
  $$ SELECT public.register_device_token('fcm-token-user-1', 'android') $$,
  'Usuario 1 puede registrar exitosamente su token de dispositivo'
);

SELECT is(
  (SELECT token FROM public.device_tokens WHERE fan_id = 'c1111111-1111-1111-1111-111111111111'),
  'fcm-token-user-1',
  'Usuario 1 puede consultar su propio token en device_tokens'
);

-- ----------------------------------------------------------------------------
-- Test 6 & 7: Aislamiento RLS - Usuario 2 no ve ni edita tokens de Usuario 1
-- ----------------------------------------------------------------------------
SET LOCAL "request.jwt.claims" = '{"sub": "c2222222-2222-2222-2222-222222222222", "role": "authenticated"}';

SELECT is(
  (SELECT COUNT(*) FROM public.device_tokens WHERE fan_id = 'c1111111-1111-1111-1111-111111111111'),
  0::bigint,
  'Usuario 2 no puede ver los tokens de dispositivo de Usuario 1'
);

SELECT is(
  (
    WITH updated AS (
      UPDATE public.device_tokens
      SET platform = 'ios'
      WHERE token = 'fcm-token-user-1'
      RETURNING *
    )
    SELECT COUNT(*) FROM updated
  ),
  0::bigint,
  'Usuario 2 no puede modificar tokens de dispositivo de Usuario 1'
);

-- ----------------------------------------------------------------------------
-- Test 8: Re-registro de token actualiza sin error de unicidad
-- ----------------------------------------------------------------------------
SET LOCAL "request.jwt.claims" = '{"sub": "c1111111-1111-1111-1111-111111111111", "role": "authenticated"}';

SELECT lives_ok(
  $$ SELECT public.register_device_token('fcm-token-user-1', 'ios') $$,
  'Re-registrar el mismo token actualiza la plataforma sin error de unicidad'
);

SELECT finish();
ROLLBACK;
