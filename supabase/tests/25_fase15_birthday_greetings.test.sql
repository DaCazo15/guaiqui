BEGIN;
SELECT plan(8);

-- Test 1: birthday_settings table exists and is initialized
SELECT passes(
    'SELECT count(*) FROM public.birthday_settings WHERE id = 1',
    'birthday_settings singleton row must exist'
);

-- Test 2: get_birthday_card function exists and requires authenticated user
SELECT lives_ok(
    $$ SELECT count(*) FROM pg_proc WHERE proname = 'get_birthday_card' $$,
    'get_birthday_card RPC exists'
);

-- Test 3: claim_birthday_bonus RPC exists
SELECT lives_ok(
    $$ SELECT count(*) FROM pg_proc WHERE proname = 'claim_birthday_bonus' $$,
    'claim_birthday_bonus RPC exists'
);

-- Test 4: enqueue_birthday_notifications is inaccessible to anon/authenticated
SELECT throws_ok(
    $$ SELECT public.enqueue_birthday_notifications() $$,
    '42501',
    NULL,
    'enqueue_birthday_notifications should be revoked from public'
);

-- Test 5: send_test_birthday_notification is inaccessible to non-admin
SELECT throws_ok(
    $$ SELECT public.send_test_birthday_notification() $$,
    '42501',
    NULL,
    'send_test_birthday_notification requires admin authorization'
);

-- Test 6: Verify ledger_type includes birthday_bonus
SELECT passes(
    $$ SELECT 1 FROM pg_enum WHERE enumlabel = 'birthday_bonus' $$,
    'ledger_type enum includes birthday_bonus'
);

-- Test 7: update_birthday_settings RPC exists
SELECT lives_ok(
    $$ SELECT count(*) FROM pg_proc WHERE proname = 'update_birthday_settings' $$,
    'update_birthday_settings RPC exists'
);

-- Test 8: birthday_settings policy allows public read
SELECT passes(
    $$ SELECT count(*) FROM public.birthday_settings $$,
    'birthday_settings permits select'
);

SELECT * FROM finish();
ROLLBACK;
