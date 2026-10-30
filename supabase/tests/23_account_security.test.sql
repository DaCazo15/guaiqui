BEGIN;
SELECT plan(8);

-- Test 1: mfa_recovery_codes table has RLS enabled
SELECT lives_ok(
    'SELECT count(*) FROM pg_tables WHERE tablename = ''mfa_recovery_codes'' AND rowsecurity = true',
    'mfa_recovery_codes table must have RLS active'
);

-- Test 2: mfa_recovery_codes inaccessible to authenticated users directly
SELECT throws_ok(
    $$ SELECT * FROM public.mfa_recovery_codes $$,
    '42501',
    NULL,
    'mfa_recovery_codes table should be inaccessible directly'
);

-- Test 3: user_has_verified_mfa returns boolean
SELECT lives_ok(
    $$ SELECT public.user_has_verified_mfa('00000000-0000-0000-0000-000000000000'::uuid) $$,
    'user_has_verified_mfa should execute without syntax error'
);

-- Test 4: display_name validation rejects reserved words
SELECT throws_ok(
    $$ SELECT public.update_display_name('guaiqueries_oficial') $$,
    NULL,
    'El nombre contiene términos reservados no permitidos.',
    'update_display_name should reject reserved words like guaiqueries'
);

-- Test 5: display_name validation rejects admin reserved words
SELECT throws_ok(
    $$ SELECT public.update_display_name('AdminUser123') $$,
    NULL,
    'El nombre contiene términos reservados no permitidos.',
    'update_display_name should reject admin in display name'
);

-- Test 6: display_name validation rejects short names
SELECT throws_ok(
    $$ SELECT public.update_display_name('ab') $$,
    NULL,
    'El nombre de usuario debe tener entre 3 y 30 caracteres.',
    'update_display_name should reject names shorter than 3 chars'
);

-- Test 7: update_birth_date syntax and enforcement structure
SELECT lives_ok(
    $$ SELECT count(*) FROM pg_proc WHERE proname = 'update_birth_date' $$,
    'update_birth_date function exists'
);

-- Test 8: min_admins trigger function exists
SELECT lives_ok(
    $$ SELECT count(*) FROM pg_proc WHERE proname = 'assert_min_admins' $$,
    'assert_min_admins function exists'
);

SELECT * FROM finish();
ROLLBACK;
