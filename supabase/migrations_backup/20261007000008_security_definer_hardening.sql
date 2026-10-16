-- Migration: 20261007000008_security_definer_hardening.sql
-- Description: Harden search_path, REVOKE PUBLIC/anon permissions, and enforce internal role checks on all public schema RPC functions.

-- 1. REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC, anon
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC, anon;

-- 2. Update verify_redemption_code to strictly check is_staff_or_admin
CREATE OR REPLACE FUNCTION public.verify_redemption_code(p_code_hash TEXT)
RETURNS JSONB AS $$
DECLARE
    v_staff_id UUID := auth.uid();
    v_res JSONB;
BEGIN
    IF NOT is_staff_or_admin(v_staff_id) THEN
        RAISE EXCEPTION 'Staff or Admin authorization required.';
    END IF;

    SELECT jsonb_build_object(
        'redemption_id', r.id,
        'status', r.status,
        'cost_pearls', r.cost_pearls,
        'variant', r.variant,
        'created_at', r.created_at,
        'expires_at', r.expires_at,
        'delivered_at', r.delivered_at,
        'fan_name', p.display_name,
        'product_name', pr.name,
        'product_category', pr.category
    ) INTO v_res
    FROM redemptions r
    JOIN profiles p ON p.id = r.fan_id
    JOIN products pr ON pr.id = r.product_id
    WHERE r.code_hash = p_code_hash;

    IF v_res IS NULL THEN
        RAISE EXCEPTION 'Redemption code not found.';
    END IF;

    RETURN v_res;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 3. Explicitly set fixed search_path = public, pg_temp on all SECURITY DEFINER functions
ALTER FUNCTION public.is_admin(UUID) SET search_path = public, pg_temp;
ALTER FUNCTION public.is_staff_or_admin(UUID) SET search_path = public, pg_temp;
ALTER FUNCTION public.start_trivia_attempt(UUID, TEXT) SET search_path = public, pg_temp;
ALTER FUNCTION public.submit_trivia_attempt(UUID, JSONB, TEXT) SET search_path = public, pg_temp;
ALTER FUNCTION public.redeem_product(UUID, TEXT, TEXT) SET search_path = public, pg_temp;
ALTER FUNCTION public.deliver_redemption(TEXT, TEXT) SET search_path = public, pg_temp;
ALTER FUNCTION public.reject_redemption(UUID, TEXT) SET search_path = public, pg_temp;
ALTER FUNCTION public.admin_adjust_pearls(UUID, INT, TEXT) SET search_path = public, pg_temp;
ALTER FUNCTION public.cancel_redemption(UUID, TEXT) SET search_path = public, pg_temp;
ALTER FUNCTION public.approve_redemption(UUID, TEXT) SET search_path = public, pg_temp;
ALTER FUNCTION public.report_redemption_issue(UUID, TEXT) SET search_path = public, pg_temp;
ALTER FUNCTION public.handle_new_user() SET search_path = public, pg_temp;
ALTER FUNCTION public.assert_active_verified_fan() SET search_path = public, auth, pg_temp;
ALTER FUNCTION public.delete_my_account() SET search_path = public, pg_temp;
ALTER FUNCTION public.ensure_profile() SET search_path = public, pg_temp;
ALTER FUNCTION public.purge_auth_identities(UUID) SET search_path = public, auth, pg_temp;

-- 4. Re-grant EXECUTE privileges strictly to authorized roles
GRANT EXECUTE ON FUNCTION public.is_admin(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_staff_or_admin(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.start_trivia_attempt(UUID, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.submit_trivia_attempt(UUID, JSONB, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.redeem_product(UUID, TEXT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.deliver_redemption(TEXT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.reject_redemption(UUID, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.verify_redemption_code(TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_adjust_pearls(UUID, INT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.cancel_redemption(UUID, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.approve_redemption(UUID, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.report_redemption_issue(UUID, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.assert_active_verified_fan() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.ensure_profile() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.purge_auth_identities(UUID) TO service_role;

-- Revoke execute on internal trigger functions from authenticated
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.prevent_ledger_mutation() FROM PUBLIC, anon, authenticated;
