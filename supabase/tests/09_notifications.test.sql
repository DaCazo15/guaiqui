-- =============================================================
-- TEST SUITE: Fase 8B — Sistema de Notificaciones pgTAP
-- =============================================================

BEGIN;
SELECT plan(15);

-- Setup: Usuarios de prueba
DO $$
DECLARE
    v_u1 UUID := '44444444-4444-4444-4444-444444444444';
    v_u2 UUID := '55555555-5555-5555-5555-555555555555';
BEGIN
    INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_confirmed_at)
    VALUES
        ('00000000-0000-0000-0000-000000000000', v_u1, 'authenticated', 'authenticated', 'notif_u1@guaiqui.test', crypt('Test123!', gen_salt('bf')), '{"provider":"email"}'::jsonb, '{}'::jsonb, NOW(), NOW(), '', NOW()),
        ('00000000-0000-0000-0000-000000000000', v_u2, 'authenticated', 'authenticated', 'notif_u2@guaiqui.test', crypt('Test123!', gen_salt('bf')), '{"provider":"email"}'::jsonb, '{}'::jsonb, NOW(), NOW(), '', NOW())
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO profiles (id, display_name, status, notification_prefs)
    VALUES
        (v_u1, 'Notif User 1', 'active', '{"redemptions": true, "trivias_matches": true, "news": true, "push": true, "email": true}'::jsonb),
        (v_u2, 'Notif User 2', 'active', '{"redemptions": true, "trivias_matches": false, "news": false, "push": true, "email": true}'::jsonb)
    ON CONFLICT (id) DO UPDATE SET notification_prefs = EXCLUDED.notification_prefs;
END $$;

-- 1. Intentar llamar create_notification como authenticated debe fallar (REVOKE ALL)
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" TO '44444444-4444-4444-4444-444444444444';

SELECT throws_ok(
    $$ SELECT public.create_notification('44444444-4444-4444-4444-444444444444', 'team_news', 'Prueba', 'Cuerpo', '{}'::jsonb, 'test_key_1') $$,
    '42501' -- permission denied
);

-- 2. Inserción directa en notifications por cliente debe fallar por RLS
SELECT throws_ok(
    $$ INSERT INTO notifications (user_id, type, title, body, dedup_key) VALUES ('44444444-4444-4444-4444-444444444444', 'test', 'Test', 'Body', 'dedup_direct_1') $$,
    '42501'
);

-- 3. Inserción directa en notification_outbox debe fallar por RLS
SELECT throws_ok(
    $$ INSERT INTO notification_outbox (notification_id, channel, status) VALUES ('00000000-0000-0000-0000-000000000000', 'push', 'pending') $$,
    '42501'
);

-- Restablecer rol a postgres para probar create_notification internal
RESET ROLE;

-- 4. Inserción de notificación transaccional con create_notification
SELECT isnt_null(
    public.create_notification(
        '44444444-4444-4444-4444-444444444444',
        'redemption_approved',
        'Canje Aprobado',
        'Tu QR está listo',
        '{"redemption_id":"11111111-1111-1111-1111-111111111111"}'::jsonb,
        'dedup_tx_1'
    ),
    'Notificación transaccional debe retornar UUID'
);

-- 5. Idempotencia por dedup_key (segunda llamada retorna NULL)
SELECT is_null(
    public.create_notification(
        '44444444-4444-4444-4444-444444444444',
        'redemption_approved',
        'Canje Aprobado Reintento',
        'Tu QR está listo',
        '{}'::jsonb,
        'dedup_tx_1'
    ),
    'Notificación con dedup_key existente debe ser ignorada'
);

-- 6. Respeto de preferencias del usuario: User 2 tiene trivias_matches = false
SELECT is_null(
    public.create_notification(
        '55555555-5555-5555-5555-555555555555',
        'new_trivia',
        'Nueva Trivia',
        'Participa ya',
        '{}'::jsonb,
        'dedup_u2_trivia_1'
    ),
    'Notificación no transaccional desactivada debe retornar NULL'
);

-- 7. Transaccional para User 2 sí debe ingresar aun si desactivó no transaccionales
SELECT isnt_null(
    public.create_notification(
        '55555555-5555-5555-5555-555555555555',
        'redemption_delivered',
        'Entrega',
        'Entregado',
        '{}'::jsonb,
        'dedup_u2_tx_1'
    ),
    'Notificación transaccional debe crearse independientemente de la preferencia'
);

-- 8. Tope de 1 notificación no transaccional al día por usuario
SELECT isnt_null(
    public.create_notification(
        '44444444-4444-4444-4444-444444444444',
        'new_trivia',
        'Trivia 1 Hoy',
        'Trivia 1',
        '{}'::jsonb,
        'dedup_u1_nontx_1'
    ),
    'Primera no transaccional del día debe crearse'
);

SELECT is_null(
    public.create_notification(
        '44444444-4444-4444-4444-444444444444',
        'team_news',
        'Novedad 2 Hoy',
        'Novedad 2',
        '{}'::jsonb,
        'dedup_u1_nontx_2'
    ),
    'Segunda no transaccional del mismo día debe ser rechazada por tope diario'
);

-- 9. Aislamiento RLS de lectura: User 1 no puede leer notificaciones de User 2
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" TO '44444444-4444-4444-4444-444444444444';

SELECT is(
    (SELECT COUNT(*)::int FROM notifications WHERE user_id = '55555555-5555-5555-5555-555555555555'),
    0,
    'Usuario 1 no puede ver notificaciones de Usuario 2'
);

-- 10. Registrar suscripción push con RPC como User 1
SELECT lives_ok(
    $$ SELECT public.register_push_subscription('https://push.example.com/sub/u1', 'p256_key_1', 'auth_key_1', 'Mozilla/5.0') $$,
    'User 1 puede registrar su propia suscripción push'
);

RESET ROLE;

-- 11. Verificar que push_subscriptions fue actualizado para u1 y no es accesible directo
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" TO '55555555-5555-5555-5555-555555555555';

SELECT throws_ok(
    $$ SELECT * FROM push_subscriptions $$,
    '42501' -- RLS sin acceso directo
);

-- 12. User 2 no puede cancelar/desregistrar la suscripción de User 1
SELECT lives_ok(
    $$ SELECT public.unregister_push_subscription('https://push.example.com/sub/u1') $$,
    'Desregistrar la URL de otro usuario no afecta a ese usuario'
);

RESET ROLE;
SELECT is_null(
    (SELECT disabled_at FROM push_subscriptions WHERE endpoint = 'https://push.example.com/sub/u1'),
    'La suscripción de User 1 permanece activa'
);

-- 13. Desregistrar la propia suscripción como User 1
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" TO '44444444-4444-4444-4444-444444444444';

SELECT lives_ok(
    $$ SELECT public.unregister_push_subscription('https://push.example.com/sub/u1') $$,
    'User 1 desregistra exitosamente su propia suscripción'
);

RESET ROLE;
SELECT isnt_null(
    (SELECT disabled_at FROM push_subscriptions WHERE endpoint = 'https://push.example.com/sub/u1'),
    'Suscripción de User 1 fue deshabilitada'
);

SELECT * FROM finish();
ROLLBACK;
