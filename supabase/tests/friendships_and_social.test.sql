-- ============================================================================
-- TEST SUITE: friendships_and_social.test.sql
-- Fase 8: Amistades, Solicitudes, Insignias Sociales y Leaderboard de Amigos
-- ============================================================================

BEGIN;
SELECT plan(15);

-- 1. Estructura y RLS de tabla friendships
SELECT has_table('public', 'friendships', 'La tabla friendships debe existir');
SELECT has_column('public', 'friendships', 'id', 'friendships tiene id');
SELECT has_column('public', 'friendships', 'requester_id', 'friendships tiene requester_id');
SELECT has_column('public', 'friendships', 'addressee_id', 'friendships tiene addressee_id');
SELECT has_column('public', 'friendships', 'status', 'friendships tiene status');

-- 2. RLS activo
SELECT tests.rls_enabled('public', 'friendships');

-- 3. Funciones RPC registradas
SELECT has_function('public', 'send_friend_request', ARRAY['text'], 'send_friend_request debe existir');
SELECT has_function('public', 'respond_friend_request', ARRAY['uuid', 'text'], 'respond_friend_request debe existir');
SELECT has_function('public', 'remove_friend', ARRAY['uuid'], 'remove_friend debe existir');
SELECT has_function('public', 'get_my_friends_and_requests', ARRAY[]::text[], 'get_my_friends_and_requests debe existir');
SELECT has_function('public', 'get_leaderboard', ARRAY['text', 'uuid', 'boolean'], 'get_leaderboard(text, uuid, boolean) debe existir');

-- 4. Setup de usuarios de prueba
DO $$
DECLARE
    v_u1 UUID := '11111111-8888-8888-8888-111111111111';
    v_u2 UUID := '22222222-8888-8888-8888-222222222222';
BEGIN
    INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data)
    VALUES 
        (v_u1, 'fan1_social@guaiqui.test', crypt('Test1234!', gen_salt('bf')), NOW(), '{"provider":"email"}'::jsonb, '{}'::jsonb),
        (v_u2, 'fan2_social@guaiqui.test', crypt('Test1234!', gen_salt('bf')), NOW(), '{"provider":"email"}'::jsonb, '{}'::jsonb)
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.profiles (id, display_name, status, terms_accepted_at, privacy_accepted_at, pearls_rules_accepted_at)
    VALUES 
        (v_u1, 'Fan Social 1', 'active', NOW(), NOW(), NOW()),
        (v_u2, 'Fan Social 2', 'active', NOW(), NOW(), NOW())
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.referral_codes (fan_id, code)
    VALUES 
        (v_u1, 'SOCIAL01'),
        (v_u2, 'SOCIAL02')
    ON CONFLICT (fan_id) DO NOTHING;
END $$;

-- 5. No se puede enviar solicitud a uno mismo
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "11111111-8888-8888-8888-111111111111", "role": "authenticated"}';

SELECT throws_ok(
    $$ SELECT public.send_friend_request('SOCIAL01') $$,
    'CANNOT_FRIEND_SELF',
    'No se puede enviar solicitud de amistad a uno mismo'
);

-- 6. Enviar solicitud al fan 2 usando su código
SELECT lives_ok(
    $$ SELECT public.send_friend_request('SOCIAL02') $$,
    'El fan 1 puede enviar solicitud de amistad al fan 2 usando su código SOCIAL02'
);

-- 7. Intentar enviar otra vez lanza REQUEST_ALREADY_SENT
SELECT throws_ok(
    $$ SELECT public.send_friend_request('SOCIAL02') $$,
    'REQUEST_ALREADY_SENT',
    'No se puede reenviar solicitud si ya está pendiente'
);

-- 8. El fan 2 puede responder y aceptar
RESET ROLE;
RESET "request.jwt.claims";

DO $$
DECLARE
    v_u2 UUID := '22222222-8888-8888-8888-222222222222';
    v_f_id UUID;
    v_res JSONB;
BEGIN
    SELECT id INTO v_f_id FROM public.friendships WHERE addressee_id = v_u2 LIMIT 1;
    
    -- Simular authenticated fan 2
    PERFORM set_config('role', 'authenticated', true);
    PERFORM set_config('request.jwt.claims', '{"sub": "22222222-8888-8888-8888-222222222222", "role": "authenticated"}', true);

    v_res := public.respond_friend_request(v_f_id, 'accepted');
END $$;

SELECT is(
    (SELECT status FROM public.friendships WHERE addressee_id = '22222222-8888-8888-8888-222222222222' LIMIT 1),
    'accepted',
    'La amistad debe quedar en estado accepted tras la respuesta del fan 2'
);

-- 9. Insignia amigo_fiel desbloqueada para ambos
SELECT ok(
    EXISTS(
        SELECT 1 FROM public.fan_badges fb
        JOIN public.badges b ON b.id = fb.badge_id
        WHERE fb.fan_id = '11111111-8888-8888-8888-111111111111' AND b.slug = 'amigo_fiel'
    ),
    'Fan 1 desbloquea insignia amigo_fiel'
);

SELECT * FROM finish();
ROLLBACK;
