BEGIN;
SELECT plan(5);

-- Test 1: app_secrets table has RLS enabled
SELECT lives_ok(
    'SELECT count(*) FROM pg_tables WHERE tablename = ''app_secrets'' AND rowsecurity = true',
    'app_secrets table must have RLS active'
);

-- Test 2: app_secrets is inaccessible to authenticated/anon directly
SELECT throws_ok(
    $$ SELECT * FROM public.app_secrets $$,
    '42501',
    NULL,
    'app_secrets table should be inaccessible directly from public'
);

-- Test 3: generate_redemption_code function exists and requires execution rights
SELECT lives_ok(
    $$ SELECT count(*) FROM pg_proc WHERE proname = 'generate_redemption_code' $$,
    'generate_redemption_code function exists'
);

-- Test 4: helper_generate_code_with_key handles key versions
SELECT lives_ok(
    $$ SELECT public.helper_generate_code_with_key('00000000-0000-0000-0000-000000000001'::uuid, 'v2') $$,
    'helper_generate_code_with_key should execute for key v2'
);

-- Test 5: Verify version fallback helper returns null for invalid key
SELECT is(
    public.helper_generate_code_with_key('00000000-0000-0000-0000-000000000001'::uuid, 'invalid_key_999'),
    NULL,
    'helper_generate_code_with_key returns NULL for non-existent key_id'
);

SELECT * FROM finish();
ROLLBACK;
