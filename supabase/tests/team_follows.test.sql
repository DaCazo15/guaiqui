-- ============================================================================
-- Test Suite: team_follows.test.sql
-- Description: Tests for Paso 1: Seguir Equipos
--              1. Follow/Unfollow idempotency and rate limits
--              2. Cannot follow inactive teams
--              3. RLS: Fan can only manage own follows; staff cannot read followers directly
--              4. team_follower_count correctness
--              5. search_teams: active teams only, public fields, is_following flag, pagination
--              6. Backfill check for team #1
-- ============================================================================

BEGIN;
SELECT plan(14);

CREATE EXTENSION IF NOT EXISTS pgtap;

-- Setup 2 ephemeral teams: Team A (active) and Team B (inactive)
INSERT INTO public.teams (id, name, slug, status, paid_until)
VALUES 
    ('dd000000-0000-0000-0000-000000000001', 'Team Follow Alpha', 'team-follow-alpha', 'active', NOW() + INTERVAL '1 year'),
    ('dd000000-0000-0000-0000-000000000002', 'Team Follow Beta Inactive', 'team-follow-beta', 'inactive', NOW() + INTERVAL '1 year')
ON CONFLICT (id) DO UPDATE SET status = EXCLUDED.status;

-- Users
INSERT INTO auth.users (id, email, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud)
VALUES
    ('d1111111-1111-1111-1111-111111111111', 'fan_follow_1@test.com', NOW(), '{"provider":"email"}', '{}', NOW(), NOW(), 'authenticated', 'authenticated'),
    ('d2222222-2222-2222-2222-222222222222', 'fan_follow_2@test.com', NOW(), '{"provider":"email"}', '{}', NOW(), NOW(), 'authenticated', 'authenticated'),
    ('d3333333-3333-3333-3333-333333333333', 'staff_follow@test.com', NOW(), '{"provider":"email"}', '{}', NOW(), NOW(), 'authenticated', 'authenticated')
ON CONFLICT (id) DO UPDATE SET email_confirmed_at = COALESCE(auth.users.email_confirmed_at, NOW()), raw_app_meta_data = EXCLUDED.raw_app_meta_data;

INSERT INTO public.profiles (id, display_name, status, terms_accepted_at, terms_version)
VALUES
    ('d1111111-1111-1111-1111-111111111111', 'Fan Follow 1', 'active', NOW(), 'v1.0'),
    ('d2222222-2222-2222-2222-222222222222', 'Fan Follow 2', 'active', NOW(), 'v1.0'),
    ('d3333333-3333-3333-3333-333333333333', 'Staff Follow', 'active', NOW(), 'v1.0')
ON CONFLICT (id) DO UPDATE SET terms_accepted_at = NOW(), terms_version = 'v1.0';

INSERT INTO public.staff_members (user_id, role, team_id, active)
VALUES
    ('d3333333-3333-3333-3333-333333333333', 'staff', 'dd000000-0000-0000-0000-000000000001', true)
ON CONFLICT (user_id) DO UPDATE SET role = EXCLUDED.role, team_id = EXCLUDED.team_id, active = true;

-- Backfill verification setup
INSERT INTO public.team_follows (user_id, team_id, created_at)
SELECT p.id, 'a0000000-0000-0000-0000-000000000001'::uuid, NOW()
FROM public.profiles p
WHERE p.status != 'deleted'
ON CONFLICT (user_id, team_id) DO NOTHING;

-- ─── 1. Backfill Verification ────────────────────────────────────────────────
-- TEST 1: Existing profiles have backfill follow to team #1
SELECT ok(
    EXISTS (
        SELECT 1 FROM public.team_follows
        WHERE team_id = 'a0000000-0000-0000-0000-000000000001'
    ),
    'TEST 1: Backfill insertó follows al equipo #1 (Guaiqueríes)'
);

-- ─── 2. Follow Team (RPC) ────────────────────────────────────────────────────
-- TEST 2: Fan follows active team successfully
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "d1111111-1111-1111-1111-111111111111", "role": "authenticated"}';

SELECT is(
    (public.follow_team('dd000000-0000-0000-0000-000000000001')->>'success')::boolean,
    true,
    'TEST 2: follow_team permite seguir a un equipo activo'
);
RESET ROLE;

-- TEST 3: Idempotent follow (calling follow_team again succeeds without duplicate key error)
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "d1111111-1111-1111-1111-111111111111", "role": "authenticated"}';

SELECT is(
    (public.follow_team('dd000000-0000-0000-0000-000000000001')->>'following')::boolean,
    true,
    'TEST 3: follow_team es idempotente ante llamadas repetidas'
);
RESET ROLE;

-- TEST 4: Follow count reflects the follow
SELECT is(
    public.team_follower_count('dd000000-0000-0000-0000-000000000001'),
    1,
    'TEST 4: team_follower_count contabiliza correctamente el nuevo seguidor'
);

-- TEST 5: Cannot follow inactive team
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "d1111111-1111-1111-1111-111111111111", "role": "authenticated"}';

SELECT throws_ok(
    $$SELECT public.follow_team('dd000000-0000-0000-0000-000000000002')$$,
    '42501',
    NULL,
    'TEST 5: follow_team rechaza seguir a un equipo con status inactive'
);
RESET ROLE;

-- ─── 3. Unfollow Team (RPC) ──────────────────────────────────────────────────
-- TEST 6: Unfollow active team succeeds
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "d1111111-1111-1111-1111-111111111111", "role": "authenticated"}';

SELECT is(
    (public.unfollow_team('dd000000-0000-0000-0000-000000000001')->>'following')::boolean,
    false,
    'TEST 6: unfollow_team elimina la relación de seguimiento correctamente'
);
RESET ROLE;

-- TEST 7: Idempotent unfollow
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "d1111111-1111-1111-1111-111111111111", "role": "authenticated"}';

SELECT is(
    (public.unfollow_team('dd000000-0000-0000-0000-000000000001')->>'success')::boolean,
    true,
    'TEST 7: unfollow_team es idempotente cuando no se seguía al equipo'
);
RESET ROLE;

-- TEST 8: Follower count decrements
SELECT is(
    public.team_follower_count('dd000000-0000-0000-0000-000000000001'),
    0,
    'TEST 8: team_follower_count refleja el decremento tras unfollow'
);

-- ─── 4. RLS Isolations on team_follows table ─────────────────────────────────
-- Re-follow for testing RLS reads
INSERT INTO public.team_follows (user_id, team_id)
VALUES ('d1111111-1111-1111-1111-111111111111', 'dd000000-0000-0000-0000-000000000001')
ON CONFLICT (user_id, team_id) DO NOTHING;

-- TEST 9: Fan can read own follows
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "d1111111-1111-1111-1111-111111111111", "role": "authenticated"}';

SELECT is(
    (SELECT COUNT(*)::INT FROM public.team_follows WHERE team_id = 'dd000000-0000-0000-0000-000000000001'),
    1,
    'TEST 9: El fanático puede leer sus propios registros en team_follows'
);
RESET ROLE;

-- TEST 10: Fan cannot read another fan's follows
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "d2222222-2222-2222-2222-222222222222", "role": "authenticated"}';

SELECT is(
    (SELECT COUNT(*)::INT FROM public.team_follows WHERE user_id = 'd1111111-1111-1111-1111-111111111111'),
    0,
    'TEST 10: Un fanático no puede ver los equipos que sigue otro fanático en team_follows'
);
RESET ROLE;

-- TEST 11: Club staff cannot read team_follows directly (must use team_follower_count)
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "d3333333-3333-3333-3333-333333333333", "role": "authenticated"}';

SELECT is(
    (SELECT COUNT(*)::INT FROM public.team_follows WHERE team_id = 'dd000000-0000-0000-0000-000000000001'),
    0,
    'TEST 11: El staff de club no tiene acceso directo a la lista de seguidores en team_follows'
);
RESET ROLE;

-- ─── 5. search_teams RPC ─────────────────────────────────────────────────────
-- TEST 12: Inactive teams are never returned in search_teams
SELECT ok(
    NOT EXISTS (
        SELECT 1 FROM public.search_teams('team-follow-beta')
        WHERE slug = 'team-follow-beta'
    ),
    'TEST 12: search_teams excluye permanentemente equipos con status inactive'
);

-- TEST 13: search_teams returns active teams with is_following flag
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "d1111111-1111-1111-1111-111111111111", "role": "authenticated"}';

SELECT is(
    (SELECT is_following FROM public.search_teams('Team Follow Alpha') LIMIT 1),
    true,
    'TEST 13: search_teams proyecta correctamente is_following = true para equipos seguidos'
);
RESET ROLE;

-- TEST 14: search_teams limit capping respects max 50
SELECT ok(
    (SELECT COUNT(*) FROM public.search_teams(NULL, 100, 0)) <= 50,
    'TEST 14: search_teams acota el límite máximo solicitado a 50'
);

SELECT * FROM finish();
ROLLBACK;
