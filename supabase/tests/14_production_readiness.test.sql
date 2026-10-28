BEGIN;
SELECT plan(4);

-- 1. Verify health_check function exists
SELECT has_function('public', 'health_check', 'health_check function should exist');

-- 2. Execute health_check function
SELECT lives_ok(
  'SELECT public.health_check()',
  'health_check() should execute without errors'
);

-- 3. Verify system_alerts table exists
SELECT has_table('public', 'system_alerts', 'system_alerts table should exist');

-- 4. Verify run_daily_wallet_reconciliation function exists
SELECT has_function('public', 'run_daily_wallet_reconciliation', 'run_daily_wallet_reconciliation should exist');

SELECT * FROM finish();
ROLLBACK;
