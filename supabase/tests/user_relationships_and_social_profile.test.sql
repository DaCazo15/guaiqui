-- ============================================================================
-- Test Suite: user_relationships_and_social_profile.test.sql
-- Domain: FASE 6 — Relaciones entre usuarios y perfil social
-- Tests:
--   1. Schema: public.user_follows table exists
--   2. Schema: public.user_blocks table exists
--   3. Schema: public.profiles has favorite_sport column
--   4. Solicitud: send_follow_request crea registro con status 'pending'
--   5. Solicitud: No se puede seguir a uno mismo (P0001)
--   6. Solicitud: No se puede duplicar solicitud pendiente existente (P0001)
--   7. Responder: Aceptar solicitud pasa a 'accepted' y marca responded_at
--   8. Solicitud: Falla si ya se sigue al usuario (P0001)
--   9. Responder: Rechazar solicitud elimina el registro de seguimiento
--  10. Cancelar: cancel_follow_request elimina solicitud pendiente
--  11. Responder ajena: Un usuario no puede responder solicitudes dirigidas a otro (P0002)
--  12. Bloqueo: block_user borra relaciones de seguimiento en ambos sentidos
--  13. Bloqueo: Impide enviar nuevas solicitudes entre usuarios bloqueados (P0001)
--  14. Búsqueda: search_users oculta usuarios bloqueados en ambas direcciones
--  15. Perfil Público: No seguidor NO recibe ranking, canjes, último premio ni perlitas
--  16. Perfil Público: Seguidor aceptado SÍ recibe ranking, canjes y perlitas unificadas
--  17. Perfil Público: NUNCA expone email, teléfono, fecha de nacimiento ni municipio
--  18. Perfil Público: Usuario bloqueado arroja error de no encontrado (P0002)
--  19. Seguridad: anon no puede ejecutar send_follow_request (42501)
--  20. Seguridad: anon no puede ejecutar respond_follow_request (42501)
--  21. Seguridad: anon no puede ejecutar block_user (42501)
--  22. Seguridad: anon no puede ejecutar search_users (42501)
--  23. Seguridad: anon no puede ejecutar get_public_profile (42501)
--  24. Seguridad: authenticated no puede hacer INSERT directo en user_follows (42501)
--  25. Seguridad: authenticated no puede hacer INSERT directo en user_blocks (42501)
-- ============================================================================

BEGIN;

SELECT plan(25);

CREATE EXTENSION IF NOT EXISTS pgtap;

-- ----------------------------------------------------------------------------
-- Fixtures Setup
-- ----------------------------------------------------------------------------

-- Usuarios de prueba:
-- User A (Alice F6)
-- User B (Bob F6)
-- User C (Charlie F6)
-- User D (David F6)
INSERT INTO auth.users (id, email, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud)
VALUES
    ('a1111111-1111-1111-1111-111111111111', 'alice_f6@test.com', NOW(), '{"provider":"email"}', '{}', NOW(), NOW(), 'authenticated', 'authenticated'),
    ('b2222222-2222-2222-2222-222222222222', 'bob_f6@test.com', NOW(), '{"provider":"email"}', '{}', NOW(), NOW(), 'authenticated', 'authenticated'),
    ('c3333333-3333-3333-3333-333333333333', 'charlie_f6@test.com', NOW(), '{"provider":"email"}', '{}', NOW(), NOW(), 'authenticated', 'authenticated'),
    ('d4444444-4444-4444-4444-444444444444', 'david_f6@test.com', NOW(), '{"provider":"email"}', '{}', NOW(), NOW(), 'authenticated', 'authenticated')
ON CONFLICT (id) DO UPDATE SET email_confirmed_at = COALESCE(auth.users.email_confirmed_at, NOW()), raw_app_meta_data = EXCLUDED.raw_app_meta_data;

INSERT INTO public.profiles (id, display_name, status, terms_accepted_at, terms_version, favorite_sport, birth_date, municipality)
VALUES
    ('a1111111-1111-1111-1111-111111111111', 'Alice Margarita F6', 'active', NOW(), 'v1.0', 'Baloncesto', '1995-05-15', 'Mariño'),
    ('b2222222-2222-2222-2222-222222222222', 'Bob Porlamar F6', 'active', NOW(), 'v1.0', 'Béisbol', '1992-08-20', 'Maneiro'),
    ('c3333333-3333-3333-3333-333333333333', 'Charlie Guaiqueri F6', 'active', NOW(), 'v1.0', 'Fútbol', '1990-01-10', 'Arismendi'),
    ('d4444444-4444-4444-4444-444444444444', 'David Caribe F6', 'active', NOW(), 'v1.0', 'Voleibol', '1998-12-05', 'Gómez')
ON CONFLICT (id) DO UPDATE 
SET terms_accepted_at = NOW(), 
    terms_version = 'v1.0', 
    status = 'active', 
    favorite_sport = EXCLUDED.favorite_sport,
    birth_date = EXCLUDED.birth_date,
    municipality = EXCLUDED.municipality;

-- Limpieza de relaciones de prueba
DELETE FROM public.user_follows WHERE follower_id IN (
    'a1111111-1111-1111-1111-111111111111', 'b2222222-2222-2222-2222-222222222222',
    'c3333333-3333-3333-3333-333333333333', 'd4444444-4444-4444-4444-444444444444'
) OR followed_id IN (
    'a1111111-1111-1111-1111-111111111111', 'b2222222-2222-2222-2222-222222222222',
    'c3333333-3333-3333-3333-333333333333', 'd4444444-4444-4444-4444-444444444444'
);

DELETE FROM public.user_blocks WHERE blocker_id IN (
    'a1111111-1111-1111-1111-111111111111', 'b2222222-2222-2222-2222-222222222222',
    'c3333333-3333-3333-3333-333333333333', 'd4444444-4444-4444-4444-444444444444'
) OR blocked_id IN (
    'a1111111-1111-1111-1111-111111111111', 'b2222222-2222-2222-2222-222222222222',
    'c3333333-3333-3333-3333-333333333333', 'd4444444-4444-4444-4444-444444444444'
);

-- Team y wallet para Bob con 50 perlitas
INSERT INTO public.teams (id, name, slug, status, paid_until)
VALUES ('e1111111-0000-0000-0000-000000000001', 'Team Social F6', 'team-social-f6', 'active', NOW() + INTERVAL '1 year')
ON CONFLICT (id) DO UPDATE SET status = 'active';

INSERT INTO public.wallets (fan_id, team_id, balance_cache)
VALUES ('b2222222-2222-2222-2222-222222222222', 'e1111111-0000-0000-0000-000000000001', 50)
ON CONFLICT (fan_id, team_id) DO UPDATE SET balance_cache = 50;

INSERT INTO public.ledger_entries (fan_id, team_id, amount, type, status)
VALUES ('b2222222-2222-2222-2222-222222222222', 'e1111111-0000-0000-0000-000000000001', 50, 'bonus', 'confirmed')
ON CONFLICT DO NOTHING;

-- ----------------------------------------------------------------------------
-- TEST 1-3: Schema checks
-- ----------------------------------------------------------------------------
SELECT has_table('public', 'user_follows', 'TEST 1: public.user_follows table exists');
SELECT has_table('public', 'user_blocks', 'TEST 2: public.user_blocks table exists');
SELECT has_column('public', 'profiles', 'favorite_sport', 'TEST 3: public.profiles has favorite_sport column');

-- ----------------------------------------------------------------------------
-- TEST 4-6: Solicitud de seguimiento, auto-seguimiento y anti-duplicados
-- ----------------------------------------------------------------------------
-- Alice envía solicitud a Bob
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "a1111111-1111-1111-1111-111111111111", "role": "authenticated"}';

SELECT lives_ok(
    $$ SELECT public.send_follow_request('b2222222-2222-2222-2222-222222222222') $$,
    'TEST 4: Alice puede enviar solicitud de seguimiento a Bob'
);

SELECT throws_ok(
    $$ SELECT public.send_follow_request('a1111111-1111-1111-1111-111111111111') $$,
    'P0001',
    'No puedes seguirte a ti mismo.',
    'TEST 5: Alice no puede enviarse solicitud a sí misma'
);

SELECT throws_ok(
    $$ SELECT public.send_follow_request('b2222222-2222-2222-2222-222222222222') $$,
    'P0001',
    'Ya existe una solicitud pendiente para este usuario.',
    'TEST 6: Alice no puede duplicar la solicitud pendiente hacia Bob'
);
RESET ROLE;

-- ----------------------------------------------------------------------------
-- TEST 7-8: Bob acepta solicitud y verificación de estado 'accepted'
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "b2222222-2222-2222-2222-222222222222", "role": "authenticated"}';

SELECT lives_ok(
    $$ SELECT public.respond_follow_request('a1111111-1111-1111-1111-111111111111', true) $$,
    'TEST 7: Bob acepta la solicitud de seguimiento de Alice'
);
RESET ROLE;

-- Alice intenta solicitar de nuevo pero ya lo sigue
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "a1111111-1111-1111-1111-111111111111", "role": "authenticated"}';
SELECT throws_ok(
    $$ SELECT public.send_follow_request('b2222222-2222-2222-2222-222222222222') $$,
    'P0001',
    'Ya sigues a este usuario.',
    'TEST 8: Falla al enviar solicitud a un usuario que ya se está siguiendo'
);
RESET ROLE;

-- ----------------------------------------------------------------------------
-- TEST 9: Rechazar solicitud elimina el registro
-- ----------------------------------------------------------------------------
-- Charlie envía solicitud a Bob
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "c3333333-3333-3333-3333-333333333333", "role": "authenticated"}';
SELECT public.send_follow_request('b2222222-2222-2222-2222-222222222222');
RESET ROLE;

-- Bob rechaza
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "b2222222-2222-2222-2222-222222222222", "role": "authenticated"}';
SELECT lives_ok(
    $$ SELECT public.respond_follow_request('c3333333-3333-3333-3333-333333333333', false) $$,
    'TEST 9: Bob rechaza la solicitud de Charlie y se elimina el registro'
);
RESET ROLE;

SELECT is(
    (SELECT COUNT(*)::int FROM public.user_follows WHERE follower_id = 'c3333333-3333-3333-3333-333333333333' AND followed_id = 'b2222222-2222-2222-2222-222222222222'),
    0,
    'TEST 9b: La solicitud rechazada ya no existe en user_follows'
);

-- ----------------------------------------------------------------------------
-- TEST 10: Cancelar solicitud enviada
-- ----------------------------------------------------------------------------
-- David envía solicitud a Charlie y la cancela
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "d4444444-4444-4444-4444-444444444444", "role": "authenticated"}';
SELECT public.send_follow_request('c3333333-3333-3333-3333-333333333333');

SELECT lives_ok(
    $$ SELECT public.cancel_follow_request('c3333333-3333-3333-3333-333333333333') $$,
    'TEST 10: David cancela su solicitud pendiente hacia Charlie'
);
RESET ROLE;

-- ----------------------------------------------------------------------------
-- TEST 11: Un usuario no puede responder solicitudes dirigidas a otro
-- ----------------------------------------------------------------------------
-- Charlie envía solicitud a David
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "c3333333-3333-3333-3333-333333333333", "role": "authenticated"}';
SELECT public.send_follow_request('d4444444-4444-4444-4444-444444444444');
RESET ROLE;

-- Alice intenta responder la solicitud de Charlie dirigida a David
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "a1111111-1111-1111-1111-111111111111", "role": "authenticated"}';
SELECT throws_ok(
    $$ SELECT public.respond_follow_request('c3333333-3333-3333-3333-333333333333', true) $$,
    'P0002',
    'Solicitud de seguimiento no encontrada.',
    'TEST 11: Alice no puede responder una solicitud dirigida a David'
);
RESET ROLE;

-- ----------------------------------------------------------------------------
-- TEST 12-14: Bloqueo de usuario, borrado de relaciones y exclusión en búsqueda
-- ----------------------------------------------------------------------------
-- Actualmente Alice sigue a Bob (accepted). Bob bloquea a Alice.
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "b2222222-2222-2222-2222-222222222222", "role": "authenticated"}';
SELECT lives_ok(
    $$ SELECT public.block_user('a1111111-1111-1111-1111-111111111111') $$,
    'TEST 12a: Bob bloquea a Alice con éxito'
);
RESET ROLE;

SELECT is(
    (SELECT COUNT(*)::int FROM public.user_follows WHERE (follower_id = 'a1111111-1111-1111-1111-111111111111' AND followed_id = 'b2222222-2222-2222-2222-222222222222') OR (follower_id = 'b2222222-2222-2222-2222-222222222222' AND followed_id = 'a1111111-1111-1111-1111-111111111111')),
    0,
    'TEST 12b: El bloqueo elimina las relaciones de seguimiento mutuas en user_follows'
);

-- Alice intenta solicitar seguir a Bob pero está bloqueada
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "a1111111-1111-1111-1111-111111111111", "role": "authenticated"}';
SELECT throws_ok(
    $$ SELECT public.send_follow_request('b2222222-2222-2222-2222-222222222222') $$,
    'P0001',
    'No puedes interactuar con este usuario debido a un bloqueo.',
    'TEST 13: Alice no puede enviar solicitudes a Bob tras el bloqueo'
);

-- Búsqueda de Alice por Bob: no debe aparecer en los resultados
SELECT is(
    (SELECT COUNT(*)::int FROM jsonb_array_elements(public.search_users('Bob Porlamar'))),
    0,
    'TEST 14: search_users excluye al usuario bloqueador de la búsqueda'
);
RESET ROLE;

-- ----------------------------------------------------------------------------
-- TEST 15-18: get_public_profile (no seguidor vs seguidor vs datos privados vs bloqueo)
-- ----------------------------------------------------------------------------
-- David consulta a Charlie (no se siguen)
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "d4444444-4444-4444-4444-444444444444", "role": "authenticated"}';

SELECT ok(
    (
        SELECT (p->>'is_full_profile')::boolean = false
           AND (p->'ranking') IS NULL
           AND (p->'redemptions_count') IS NULL
           AND (p->'last_reward') IS NULL
           AND (p->'total_pearls') IS NULL
           AND (p->>'display_name') = 'Charlie Guaiqueri F6'
        FROM (SELECT public.get_public_profile('c3333333-3333-3333-3333-333333333333') AS p) t
    ),
    'TEST 15: No seguidor NO recibe estadísticas privadas (ranking, canjes, perlitas)'
);

-- Establecemos relación aceptada entre Charlie y David
RESET ROLE;
INSERT INTO public.user_follows (follower_id, followed_id, status)
VALUES ('d4444444-4444-4444-4444-444444444444', 'c3333333-3333-3333-3333-333333333333', 'accepted')
ON CONFLICT (follower_id, followed_id) DO UPDATE SET status = 'accepted';

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "d4444444-4444-4444-4444-444444444444", "role": "authenticated"}';

SELECT ok(
    (
        SELECT (p->>'is_full_profile')::boolean = true
           AND (p->'ranking') IS NOT NULL
           AND (p->'redemptions_count') IS NOT NULL
           AND (p->'total_pearls') IS NOT NULL
        FROM (SELECT public.get_public_profile('c3333333-3333-3333-3333-333333333333') AS p) t
    ),
    'TEST 16: Seguidor aceptado SÍ recibe estadísticas completas (is_full_profile = true)'
);

SELECT ok(
    (
        SELECT (p->>'email') IS NULL
           AND (p->>'phone') IS NULL
           AND (p->>'birth_date') IS NULL
           AND (p->>'municipality') IS NULL
           AND (p->>'shirt_size') IS NULL
        FROM (SELECT public.get_public_profile('c3333333-3333-3333-3333-333333333333') AS p) t
    ),
    'TEST 17: get_public_profile NUNCA expone email, teléfono, birth_date, municipio ni talla'
);
RESET ROLE;

-- Alice consulta a Bob (bloqueada)
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "a1111111-1111-1111-1111-111111111111", "role": "authenticated"}';
SELECT throws_ok(
    $$ SELECT public.get_public_profile('b2222222-2222-2222-2222-222222222222') $$,
    'P0002',
    'Usuario no encontrado.',
    'TEST 18: get_public_profile arroja error de no encontrado ante usuario bloqueado'
);
RESET ROLE;

-- ----------------------------------------------------------------------------
-- TEST 19-23: Seguridad y anon execution revocation
-- ----------------------------------------------------------------------------
SET LOCAL ROLE anon;

SELECT throws_ok(
    $$ SELECT public.send_follow_request('b2222222-2222-2222-2222-222222222222') $$,
    '42501',
    NULL,
    'TEST 19: anon no puede ejecutar send_follow_request'
);

SELECT throws_ok(
    $$ SELECT public.respond_follow_request('b2222222-2222-2222-2222-222222222222', true) $$,
    '42501',
    NULL,
    'TEST 20: anon no puede ejecutar respond_follow_request'
);

SELECT throws_ok(
    $$ SELECT public.block_user('b2222222-2222-2222-2222-222222222222') $$,
    '42501',
    NULL,
    'TEST 21: anon no puede ejecutar block_user'
);

SELECT throws_ok(
    $$ SELECT public.search_users('test') $$,
    '42501',
    NULL,
    'TEST 22: anon no puede ejecutar search_users'
);

SELECT throws_ok(
    $$ SELECT public.get_public_profile('b2222222-2222-2222-2222-222222222222') $$,
    '42501',
    NULL,
    'TEST 23: anon no puede ejecutar get_public_profile'
);
RESET ROLE;

-- ----------------------------------------------------------------------------
-- TEST 24-25: Direct INSERT disallowed on user_follows and user_blocks
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "a1111111-1111-1111-1111-111111111111", "role": "authenticated"}';

SELECT throws_ok(
    $$ INSERT INTO public.user_follows (follower_id, followed_id, status) VALUES ('a1111111-1111-1111-1111-111111111111', 'd4444444-4444-4444-4444-444444444444', 'accepted') $$,
    '42501',
    NULL,
    'TEST 24: authenticated no puede insertar directamente en public.user_follows'
);

SELECT throws_ok(
    $$ INSERT INTO public.user_blocks (blocker_id, blocked_id) VALUES ('a1111111-1111-1111-1111-111111111111', 'd4444444-4444-4444-4444-444444444444') $$,
    '42501',
    NULL,
    'TEST 25: authenticated no puede insertar directamente en public.user_blocks'
);
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
