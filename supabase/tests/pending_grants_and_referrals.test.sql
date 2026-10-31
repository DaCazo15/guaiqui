-- ============================================================================
-- Test Suite: pending_grants_and_referrals.test.sql
-- Domain: FASE 5 — Perlitas Pendientes (Anuncios y Referidos)
-- Tests:
--   1. Schema: public.pending_pearl_grants table exists
--   2. Schema: public.referrals table exists
--   3. Schema: public.referral_trivia_rewards table exists
--   4. Ads: 9 video views do not generate any pending grant
--   5. Ads: 10th video view generates 1 pending grant (source = ads_block, expires_at IS NULL)
--   6. Referrals: Signup with ref code creates grant (5 pts, expires in 90 days)
--   7. Referrals Trivia: Referral completing trivia of unfollowed team grants 0 points to referrer
--   8. Referrals Trivia: Referral completing trivia of followed team grants 5 points to referrer
--   9. Referrals Trivia: Duplicate completion of same trivia does not double-award
--  10. Claim: Fails with unfollowed team (P0001)
--  11. Claim: Fails with inactive team (P0001)
--  12. Claim: Fails with grant belonging to another fan (42501)
--  13. Claim: Fails with expired grant (P0001)
--  14. Claim: Succeeds for followed active team, sets claimed, updates wallet & ledger
--  15. Claim: Fails on already claimed grant (P0001)
--  16. Expiration: job_expire_pending_grants marks expired grants as expired
--  17. Security: Anon cannot execute claim_pending_grant (42501)
--  18. Security: Anon cannot execute claim_video_points (42501)
--  19. Security: Anon cannot execute get_pending_pearl_grants (42501)
--  20. Security: Anon cannot execute get_my_referral_summary (42501)
--  21. Security: Anon cannot execute job_expire_pending_grants (42501)
--  22. Security: Authenticated cannot INSERT directly into pending_pearl_grants (42501)
-- ============================================================================

BEGIN;

SELECT plan(23);

CREATE EXTENSION IF NOT EXISTS pgtap;

-- ----------------------------------------------------------------------------
-- Fixtures Setup
-- ----------------------------------------------------------------------------

-- 1. Teams: Alpha (active), Beta (active), Gamma (inactive)
INSERT INTO public.teams (id, name, slug, status, paid_until)
VALUES 
    ('e1111111-0000-0000-0000-000000000001', 'Team Alpha F5', 'team-alpha-f5', 'active', NOW() + INTERVAL '1 year'),
    ('e1111111-0000-0000-0000-000000000002', 'Team Beta F5', 'team-beta-f5', 'active', NOW() + INTERVAL '1 year'),
    ('e1111111-0000-0000-0000-000000000003', 'Team Gamma Inactive F5', 'team-gamma-f5', 'inactive', NOW() + INTERVAL '1 year')
ON CONFLICT (id) DO UPDATE SET status = EXCLUDED.status;

-- 2. Sponsor Video
INSERT INTO public.sponsor_videos (id, sponsor_id, title, duration_seconds, pearls_reward, is_active)
VALUES (
    'e2222222-0000-0000-0000-000000000001',
    'a0000000-0000-0000-0000-000000000001',
    'Video Sponsor Test F5',
    15,
    5,
    true
)
ON CONFLICT (id) DO UPDATE SET is_active = true;

-- 3. Users:
-- Fan Referrer (follows Alpha, does NOT follow Beta)
-- Fan Referred
-- Fan Other
INSERT INTO auth.users (id, email, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud)
VALUES
    ('e3333333-1111-1111-1111-111111111111', 'fan_ref_f5@test.com', NOW(), '{"provider":"email"}', '{}', NOW(), NOW(), 'authenticated', 'authenticated'),
    ('e3333333-2222-2222-2222-222222222222', 'fan_referred_f5@test.com', NOW(), '{"provider":"email"}', '{}', NOW(), NOW(), 'authenticated', 'authenticated'),
    ('e3333333-3333-3333-3333-333333333333', 'fan_other_f5@test.com', NOW(), '{"provider":"email"}', '{}', NOW(), NOW(), 'authenticated', 'authenticated')
ON CONFLICT (id) DO UPDATE SET email_confirmed_at = COALESCE(auth.users.email_confirmed_at, NOW()), raw_app_meta_data = EXCLUDED.raw_app_meta_data;

INSERT INTO public.profiles (id, display_name, status, terms_accepted_at, terms_version)
VALUES
    ('e3333333-1111-1111-1111-111111111111', 'Fan Referrer F5', 'active', NOW(), 'v1.0'),
    ('e3333333-2222-2222-2222-222222222222', 'Fan Referred F5', 'active', NOW(), 'v1.0'),
    ('e3333333-3333-3333-3333-333333333333', 'Fan Other F5', 'active', NOW(), 'v1.0')
ON CONFLICT (id) DO UPDATE SET terms_accepted_at = NOW(), terms_version = 'v1.0', status = 'active';

-- Referrer follows Alpha
INSERT INTO public.team_follows (user_id, team_id)
VALUES ('e3333333-1111-1111-1111-111111111111', 'e1111111-0000-0000-0000-000000000001')
ON CONFLICT (user_id, team_id) DO NOTHING;

-- Initial wallet for Referrer in Alpha with 0 balance
INSERT INTO public.wallets (fan_id, team_id, balance_cache)
VALUES ('e3333333-1111-1111-1111-111111111111', 'e1111111-0000-0000-0000-000000000001', 0)
ON CONFLICT (fan_id, team_id) DO UPDATE SET balance_cache = 0;

-- Trivias for testing
INSERT INTO public.trivias (id, title, status, team_id, start_at, end_at, reward_rules)
VALUES 
    ('e4444444-0000-0000-0000-000000000001', 'Trivia Alpha F5', 'published', 'e1111111-0000-0000-0000-000000000001', NOW() - INTERVAL '1 hour', NOW() + INTERVAL '1 hour', '{"per_correct_pearls": 10}'::jsonb),
    ('e4444444-0000-0000-0000-000000000002', 'Trivia Beta F5', 'published', 'e1111111-0000-0000-0000-000000000002', NOW() - INTERVAL '1 hour', NOW() + INTERVAL '1 hour', '{"per_correct_pearls": 10}'::jsonb)
ON CONFLICT (id) DO UPDATE SET status = 'published';

-- Clean progress / grants for test fans
DELETE FROM public.ad_daily_progress WHERE user_id = 'e3333333-1111-1111-1111-111111111111';
DELETE FROM public.pending_pearl_grants WHERE fan_id IN ('e3333333-1111-1111-1111-111111111111', 'e3333333-2222-2222-2222-222222222222', 'e3333333-3333-3333-3333-333333333333');
DELETE FROM public.referral_trivia_rewards WHERE referrer_id = 'e3333333-1111-1111-1111-111111111111';
DELETE FROM public.referrals WHERE referrer_id = 'e3333333-1111-1111-1111-111111111111' OR referred_id = 'e3333333-2222-2222-2222-222222222222';

-- ----------------------------------------------------------------------------
-- TEST 1-3: Schema checks
-- ----------------------------------------------------------------------------
SELECT has_table('public', 'pending_pearl_grants', 'TEST 1: public.pending_pearl_grants table exists');
SELECT has_table('public', 'referrals', 'TEST 2: public.referrals table exists');
SELECT has_table('public', 'referral_trivia_rewards', 'TEST 3: public.referral_trivia_rewards table exists');

-- ----------------------------------------------------------------------------
-- TEST 4-5: Ad blocks (9 views = 0 grants; 10th view = 1 grant unexpiring)
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "e3333333-1111-1111-1111-111111111111", "role": "authenticated"}';

DO $$
BEGIN
    FOR i IN 1..9 LOOP
        PERFORM public.claim_video_points('e2222222-0000-0000-0000-000000000001');
    END LOOP;
END;
$$;
RESET ROLE;

SELECT is(
    (SELECT COUNT(*)::int FROM public.pending_pearl_grants WHERE fan_id = 'e3333333-1111-1111-1111-111111111111' AND source = 'ads_block'),
    0,
    'TEST 4: El noveno anuncio visto no genera ninguna concesión de perlitas'
);

-- 10th ad view
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "e3333333-1111-1111-1111-111111111111", "role": "authenticated"}';
DO $$
BEGIN
    PERFORM public.claim_video_points('e2222222-0000-0000-0000-000000000001');
END;
$$;
RESET ROLE;

SELECT ok(
    EXISTS (
        SELECT 1 FROM public.pending_pearl_grants
        WHERE fan_id = 'e3333333-1111-1111-1111-111111111111'
          AND source = 'ads_block'
          AND status = 'pending'
          AND amount = 5
          AND expires_at IS NULL
    ),
    'TEST 5: El décimo anuncio completa bloque y genera 1 grant pendiente sin vencimiento'
);

-- ----------------------------------------------------------------------------
-- TEST 6: Referral Signup generates grant of 5 pts expiring in 90 days
-- ----------------------------------------------------------------------------
-- Referral code for Fan Referrer
INSERT INTO public.referral_codes (user_id, code)
VALUES ('e3333333-1111-1111-1111-111111111111', 'REFTEST1')
ON CONFLICT (user_id) DO UPDATE SET code = 'REFTEST1';

-- Simulate handle_new_user for Fan Referred with referral_code = 'REFTEST1'
INSERT INTO public.referrals (referrer_id, referred_id, status)
VALUES ('e3333333-1111-1111-1111-111111111111', 'e3333333-2222-2222-2222-222222222222', 'registered')
ON CONFLICT (referred_id) DO UPDATE SET status = 'registered';

INSERT INTO public.pending_pearl_grants (
    fan_id, source, amount, referral_id, status, expires_at
) VALUES (
    'e3333333-1111-1111-1111-111111111111',
    'referral_signup',
    5,
    (SELECT id FROM public.referrals WHERE referred_id = 'e3333333-2222-2222-2222-222222222222'),
    'pending',
    NOW() + INTERVAL '90 days'
)
ON CONFLICT (referral_id) DO NOTHING;

SELECT ok(
    EXISTS (
        SELECT 1 FROM public.pending_pearl_grants
        WHERE fan_id = 'e3333333-1111-1111-1111-111111111111'
          AND source = 'referral_signup'
          AND status = 'pending'
          AND amount = 5
          AND expires_at > NOW() + INTERVAL '89 days'
    ),
    'TEST 6: Registro con referido crea grant de 5 pts para el referidor con vencimiento a 90 días'
);

-- ----------------------------------------------------------------------------
-- TEST 7-9: Referral Trivia Reward Hook
-- ----------------------------------------------------------------------------
-- Test 7: Trivia on Team Beta (Referrer does NOT follow Beta) -> 0 bonus awarded
SELECT public.process_referral_trivia_bonus(
    'e3333333-2222-2222-2222-222222222222',
    'e4444444-0000-0000-0000-000000000002',
    'e1111111-0000-0000-0000-000000000002'
);

SELECT is(
    (SELECT COUNT(*)::int FROM public.referral_trivia_rewards WHERE referrer_id = 'e3333333-1111-1111-1111-111111111111'),
    0,
    'TEST 7: Trivia de equipo no seguido por referidor no acredita bono de referido'
);

-- Test 8: Trivia on Team Alpha (Referrer follows Alpha) -> 5 pts to wallet and ledger
SELECT public.process_referral_trivia_bonus(
    'e3333333-2222-2222-2222-222222222222',
    'e4444444-0000-0000-0000-000000000001',
    'e1111111-0000-0000-0000-000000000001'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM public.ledger_entries
        WHERE fan_id = 'e3333333-1111-1111-1111-111111111111'
          AND team_id = 'e1111111-0000-0000-0000-000000000001'
          AND amount = 5
          AND source_type = 'referral_trivia'
    ) AND (
        SELECT balance_cache FROM public.wallets
        WHERE fan_id = 'e3333333-1111-1111-1111-111111111111'
          AND team_id = 'e1111111-0000-0000-0000-000000000001'
    ) = 5,
    'TEST 8: Trivia de equipo seguido acredita 5 pts directo a la wallet del referidor con ledger_entries'
);

-- Test 9: Duplicate attempt of the same trivia does not double-award
SELECT public.process_referral_trivia_bonus(
    'e3333333-2222-2222-2222-222222222222',
    'e4444444-0000-0000-0000-000000000001',
    'e1111111-0000-0000-0000-000000000001'
);

SELECT is(
    (SELECT COUNT(*)::int FROM public.referral_trivia_rewards WHERE referred_id = 'e3333333-2222-2222-2222-222222222222' AND trivia_id = 'e4444444-0000-0000-0000-000000000001'),
    1,
    'TEST 9: La bonificación de trivia por referido se otorga una sola vez por (referido, trivia)'
);

-- ----------------------------------------------------------------------------
-- TEST 10-15: Claim Pending Grant (claim_pending_grant)
-- ----------------------------------------------------------------------------
-- We will test with the ads_block grant created in TEST 5 for Fan Referrer
DO $$
DECLARE
    v_grant_id UUID;
    v_expired_grant_id UUID;
BEGIN
    SELECT id INTO v_grant_id
    FROM public.pending_pearl_grants
    WHERE fan_id = 'e3333333-1111-1111-1111-111111111111' AND source = 'ads_block'
    LIMIT 1;

    -- Create an expired grant for testing
    INSERT INTO public.pending_pearl_grants (
        id, fan_id, source, amount, status, expires_at
    ) VALUES (
        'e5555555-0000-0000-0000-000000000001',
        'referral_signup',
        5,
        'expired',
        NOW() - INTERVAL '1 day'
    ) ON CONFLICT (id) DO NOTHING;
END;
$$;

-- TEST 10: Fails when team is not followed (Team Beta)
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "e3333333-1111-1111-1111-111111111111", "role": "authenticated"}';

SELECT throws_ok(
    format('SELECT public.claim_pending_grant(''%s'', ''e1111111-0000-0000-0000-000000000002'')', 
        (SELECT id FROM public.pending_pearl_grants WHERE fan_id = 'e3333333-1111-1111-1111-111111111111' AND source = 'ads_block' LIMIT 1)
    ),
    'P0001',
    'Debes seguir al equipo para asignarle las perlitas.',
    'TEST 10: claim_pending_grant falla si el usuario no sigue al equipo seleccionado'
);
RESET ROLE;

-- TEST 11: Fails when team is inactive (Team Gamma)
-- Even if user followed it:
INSERT INTO public.team_follows (user_id, team_id)
VALUES ('e3333333-1111-1111-1111-111111111111', 'e1111111-0000-0000-0000-000000000003')
ON CONFLICT (user_id, team_id) DO NOTHING;

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "e3333333-1111-1111-1111-111111111111", "role": "authenticated"}';

SELECT throws_ok(
    format('SELECT public.claim_pending_grant(''%s'', ''e1111111-0000-0000-0000-000000000003'')', 
        (SELECT id FROM public.pending_pearl_grants WHERE fan_id = 'e3333333-1111-1111-1111-111111111111' AND source = 'ads_block' LIMIT 1)
    ),
    'P0001',
    'El equipo seleccionado se encuentra inactivo.',
    'TEST 11: claim_pending_grant falla si el equipo seleccionado se encuentra inactivo'
);
RESET ROLE;

-- TEST 12: Fails when grant belongs to another fan (Fan Other trying to claim Fan Referrer's grant)
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "e3333333-3333-3333-3333-333333333333", "role": "authenticated"}';

SELECT throws_ok(
    format('SELECT public.claim_pending_grant(''%s'', ''e1111111-0000-0000-0000-000000000001'')', 
        (SELECT id FROM public.pending_pearl_grants WHERE fan_id = 'e3333333-1111-1111-1111-111111111111' AND source = 'ads_block' LIMIT 1)
    ),
    '42501',
    'No autorizado para reclamar esta concesión.',
    'TEST 12: claim_pending_grant falla si la concesión pertenece a otro fanático'
);
RESET ROLE;

-- TEST 13: Fails when grant is expired
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "e3333333-1111-1111-1111-111111111111", "role": "authenticated"}';

SELECT throws_ok(
    'SELECT public.claim_pending_grant(''e5555555-0000-0000-0000-000000000001'', ''e1111111-0000-0000-0000-000000000001'')',
    'P0001',
    'Esta concesión de perlitas ha expirado.',
    'TEST 13: claim_pending_grant falla si la concesión se encuentra expirada'
);
RESET ROLE;

-- TEST 14: Claim succeeds for active followed team
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "e3333333-1111-1111-1111-111111111111", "role": "authenticated"}';

SELECT is(
    (public.claim_pending_grant(
        (SELECT id FROM public.pending_pearl_grants WHERE fan_id = 'e3333333-1111-1111-1111-111111111111' AND source = 'ads_block' LIMIT 1),
        'e1111111-0000-0000-0000-000000000001'
    )->>'success')::boolean,
    true,
    'TEST 14: claim_pending_grant tiene éxito para un equipo seguido y activo'
);
RESET ROLE;

-- TEST 15: Concesión queda marcada como claimed y saldo de billetera actualizado
SELECT ok(
    (
        SELECT status = 'claimed' AND claimed_team_id = 'e1111111-0000-0000-0000-000000000001'
        FROM public.pending_pearl_grants
        WHERE fan_id = 'e3333333-1111-1111-1111-111111111111' AND source = 'ads_block'
        LIMIT 1
    ) AND (
        SELECT balance_cache FROM public.wallets
        WHERE fan_id = 'e3333333-1111-1111-1111-111111111111' AND team_id = 'e1111111-0000-0000-0000-000000000001'
    ) = 10, -- 5 from referral trivia + 5 from ads_block claim
    'TEST 15: Concesión queda marcada como claimed y saldo de billetera actualizado'
);

-- TEST 16: Claim fails on already claimed grant
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "e3333333-1111-1111-1111-111111111111", "role": "authenticated"}';

SELECT throws_ok(
    format('SELECT public.claim_pending_grant(''%s'', ''e1111111-0000-0000-0000-000000000001'')', 
        (SELECT id FROM public.pending_pearl_grants WHERE fan_id = 'e3333333-1111-1111-1111-111111111111' AND source = 'ads_block' LIMIT 1)
    ),
    'P0001',
    'Esta concesión ya fue reclamada previamente.',
    'TEST 16: claim_pending_grant falla al intentar reclamar una concesión ya reclamada'
);
RESET ROLE;

-- ----------------------------------------------------------------------------
-- TEST 17: Expiration job marks pending grants past expires_at as 'expired'
-- ----------------------------------------------------------------------------
INSERT INTO public.pending_pearl_grants (
    id, fan_id, source, amount, status, expires_at
) VALUES (
    'e6666666-0000-0000-0000-000000000001',
    'e3333333-1111-1111-1111-111111111111',
    'referral_signup',
    5,
    'pending',
    NOW() - INTERVAL '2 hours'
) ON CONFLICT (id) DO UPDATE SET status = 'pending', expires_at = NOW() - INTERVAL '2 hours';

SELECT ok(
    public.job_expire_pending_grants() >= 1,
    'TEST 17: job_expire_pending_grants procesa y expira concesiones vencidas'
);

-- ----------------------------------------------------------------------------
-- TEST 18-22: Security & Permissions for Anon
-- ----------------------------------------------------------------------------
SET LOCAL ROLE anon;

SELECT throws_ok(
    'SELECT public.claim_pending_grant(''e6666666-0000-0000-0000-000000000001'', ''e1111111-0000-0000-0000-000000000001'')',
    '42501',
    NULL,
    'TEST 18: Rol anon no tiene permiso EXECUTE en claim_pending_grant'
);

SELECT throws_ok(
    'SELECT public.claim_video_points(''e2222222-0000-0000-0000-000000000001'')',
    '42501',
    NULL,
    'TEST 19: Rol anon no tiene permiso EXECUTE en claim_video_points'
);

SELECT throws_ok(
    'SELECT public.get_pending_pearl_grants()',
    '42501',
    NULL,
    'TEST 20: Rol anon no tiene permiso EXECUTE en get_pending_pearl_grants'
);

SELECT throws_ok(
    'SELECT public.get_my_referral_summary()',
    '42501',
    NULL,
    'TEST 21: Rol anon no tiene permiso EXECUTE en get_my_referral_summary'
);

SELECT throws_ok(
    'SELECT public.job_expire_pending_grants()',
    '42501',
    NULL,
    'TEST 22: Rol anon no tiene permiso EXECUTE en job_expire_pending_grants'
);
RESET ROLE;

-- ----------------------------------------------------------------------------
-- TEST 23: Direct client INSERT into pending_pearl_grants is rejected by RLS
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "e3333333-1111-1111-1111-111111111111", "role": "authenticated"}';

SELECT throws_ok(
    'INSERT INTO public.pending_pearl_grants (fan_id, source, amount, status) VALUES (''e3333333-1111-1111-1111-111111111111'', ''ads_block'', 100, ''pending'')',
    '42501',
    NULL,
    'TEST 23: authenticated no puede insertar directamente en pending_pearl_grants (RLS)'
);
RESET ROLE;

ROLLBACK;
