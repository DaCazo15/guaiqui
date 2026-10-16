-- Migration: 20261010000021_hardening_rpc_grants.sql
-- Description: Hardening RPC permissions. Revoke anon/PUBLIC execute from sensitive RPCs and restrict internal functions to service_role.

-- 1. Ensure schema usage
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

-- 2. Revoke execute on all functions in schema public from PUBLIC and anon
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC, anon;

-- 3. Grant execute on public schema functions to authenticated role
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

-- 4. Grant execute on strictly public endpoints to anon (Landing & Public summary)
GRANT EXECUTE ON FUNCTION public.home_summary() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_leaderboard(INT, INT, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.parse_instagram_shortcode(TEXT) TO authenticated, anon;

-- 5. Revoke execute on internal background functions from authenticated & anon
REVOKE ALL ON FUNCTION public.enqueue_birthday_notifications(TIMESTAMPTZ) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.enqueue_birthday_notifications(TIMESTAMPTZ) TO service_role, postgres;

-- 6. Ensure audit_log is strictly immutable for non-admin/non-system
REVOKE UPDATE, DELETE ON public.audit_log FROM PUBLIC, anon, authenticated;
REVOKE UPDATE, DELETE ON public.ledger_entries FROM PUBLIC, anon, authenticated;
