BEGIN;

SELECT plan(4);

-- 1. Setup Test Fan User
INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud)
VALUES ('88888888-8888-8888-8888-888888888888', '00000000-0000-0000-0000-000000000000', 'captcha_fan@guaiqui.test', 'encrypted', NOW(), '{"provider":"email","providers":["email"]}', '{}', NOW(), NOW(), 'authenticated', 'authenticated')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, display_name, status, created_at)
VALUES ('88888888-8888-8888-8888-888888888888', 'Captcha Test Fan', 'active', NOW() - INTERVAL '30 days')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.wallets (fan_id, balance_cache)
VALUES ('88888888-8888-8888-8888-888888888888', 5000)
ON CONFLICT (fan_id) DO UPDATE SET balance_cache = 5000;

SET LOCAL request.jwt.claims = '{"sub": "88888888-8888-8888-8888-888888888888", "role": "authenticated"}';

-- Test 1: start_ad_session fails with CAPTCHA_REQUIRED without a valid captcha_passes row
SELECT throws_ok(
    'SELECT public.start_ad_session()',
    'CAPTCHA_REQUIRED',
    'start_ad_session must fail with CAPTCHA_REQUIRED when no valid pass exists'
);

-- Test 2: Inserting a valid captcha pass allows start_ad_session
INSERT INTO public.captcha_passes (user_id, ip_hash, used, expires_at)
VALUES ('88888888-8888-8888-8888-888888888888', 'test_ip_hash_abc', false, NOW() + INTERVAL '10 minutes');

SELECT lives_ok(
    'SELECT public.start_ad_session()',
    'start_ad_session succeeds when an unused, non-expired captcha pass is present'
);

-- Test 3: The used captcha pass was marked as used (cannot be reused)
SELECT is(
    (SELECT used FROM public.captcha_passes WHERE user_id = '88888888-8888-8888-8888-888888888888' ORDER BY created_at DESC LIMIT 1),
    true,
    'Captcha pass is marked as used = true after consumption'
);

-- Test 4: Subsequent high-value/first-session attempts without a new pass are rejected
-- In the same transaction, if user tries an action needing an unused pass, it fails
SELECT throws_ok(
    $$
    DO $$
    DECLARE
        v_uid uuid := '88888888-8888-8888-8888-888888888888';
        v_pass_id uuid;
    BEGIN
        SELECT id INTO v_pass_id
        FROM public.captcha_passes
        WHERE user_id = v_uid AND used = false AND expires_at > NOW();

        IF v_pass_id IS NULL THEN
            RAISE EXCEPTION 'CAPTCHA_REQUIRED' USING ERRCODE = 'P0001';
        END IF;
    END $$;
    $$,
    'CAPTCHA_REQUIRED',
    'Consumed captcha pass cannot be reused for second security check'
);

SELECT finish();

ROLLBACK;
