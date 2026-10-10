-- Migration: 20261010000023_strict_rpc_allowlist.sql
-- Description: Strict RPC Allowlist & Default Privileges Lockdown

-- 1. Ensure future functions in public schema inherit NO execute privileges by default
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon, authenticated;

-- 2. Revoke execute on ALL existing functions in schema public from PUBLIC, anon, and authenticated
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC, anon, authenticated;

-- 3. Update health_check() to return ONLY {status} without exposing version() or alert/redemption counts to anon
CREATE OR REPLACE FUNCTION public.health_check()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_unresolved_alerts INT;
  v_status TEXT := 'ok';
BEGIN
  SELECT COUNT(*) INTO v_unresolved_alerts FROM public.system_alerts WHERE resolved = false;

  IF v_unresolved_alerts > 0 THEN
    v_status := 'degraded';
  END IF;

  -- Only return high-level status token to prevent information disclosure
  RETURN jsonb_build_object('status', v_status);
END;
$$;

-- 4. confirm_test_user_email restricted strictly to service_role
REVOKE ALL ON FUNCTION public.confirm_test_user_email(TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_test_user_email(TEXT) TO service_role, postgres;

-- 5. Explicit Allowlist for ANON (Strictly public endpoints)
GRANT EXECUTE ON FUNCTION public.health_check() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.home_summary() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_leaderboard(TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.parse_instagram_shortcode(TEXT) TO anon, authenticated, service_role;

-- 6. Explicit Allowlist for AUTHENTICATED (Fan / Staff / Admin endpoints)
GRANT EXECUTE ON FUNCTION public.wallet_summary() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.wallet_ledger(TEXT, TIMESTAMPTZ, INT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_birthday_card() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.claim_birthday_bonus() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.register_push_subscription(TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.unregister_push_subscription(TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.mark_notification_read(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.mark_all_notifications_read() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.start_trivia_attempt(UUID, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.submit_trivia_attempt(UUID, JSONB, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.redeem_product(UUID, TEXT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.cancel_redemption(UUID, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.report_redemption_issue(UUID, TEXT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_redemption_qr(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.staff_redemption_queue(TEXT, TEXT, TIMESTAMPTZ, INT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.approve_redemption(UUID, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.verify_redemption_code(TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.generate_redemption_code(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.compute_redemption_code_hash(TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_upsert_product(JSONB) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_upsert_trivia(JSONB, JSONB) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_publish_trivia(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_duplicate_trivia(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_upsert_game(JSONB) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_delete_game(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.adjust_stock(UUID, INT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.update_birthday_settings(BOOLEAN, TEXT, TEXT, TEXT, INT, INT, INT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.send_test_birthday_notification() TO authenticated, service_role;

-- 7. Explicit Allowlist for SERVICE_ROLE / POSTGRES (Internal System & Background Cron functions)
GRANT EXECUTE ON FUNCTION public.purge_auth_identities() TO service_role, postgres;
GRANT EXECUTE ON FUNCTION public.create_notification(UUID, TEXT, TEXT, TEXT, JSONB, TEXT) TO service_role, postgres;
GRANT EXECUTE ON FUNCTION public.check_rate_limit(UUID, TEXT, INT, INT) TO service_role, postgres;
GRANT EXECUTE ON FUNCTION public.compute_risk(UUID) TO service_role, postgres;
GRANT EXECUTE ON FUNCTION public.enqueue_birthday_notifications(TIMESTAMPTZ) TO service_role, postgres;
GRANT EXECUTE ON FUNCTION public.cron_notify_expiring_redemptions() TO service_role, postgres;
GRANT EXECUTE ON FUNCTION public.cron_notify_new_trivias() TO service_role, postgres;
GRANT EXECUTE ON FUNCTION public.cron_notify_match_day() TO service_role, postgres;
GRANT EXECUTE ON FUNCTION public.cron_cleanup_old_notifications() TO service_role, postgres;
GRANT EXECUTE ON FUNCTION public.refresh_analytics_materialized_views() TO service_role, postgres;
GRANT EXECUTE ON FUNCTION public.run_daily_wallet_reconciliation() TO service_role, postgres;
GRANT EXECUTE ON FUNCTION public.seed_analytics_performance_data(INT, INT) TO service_role, postgres;
GRANT EXECUTE ON FUNCTION public.purge_fraud_telemetry(INT) TO service_role, postgres;
