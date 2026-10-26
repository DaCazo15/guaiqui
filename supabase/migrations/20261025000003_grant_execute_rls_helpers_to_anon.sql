-- Migration: 20261025000003_grant_execute_rls_helpers_to_anon.sql
-- Description:
-- Grants EXECUTE permission to anon and authenticated on RLS helper functions:
-- - is_admin_check()
-- - is_staff_or_admin(uuid)
-- - is_admin(uuid)
-- These security definer functions evaluate RLS policies during public queries and return a boolean.
-- Without EXECUTE permission, Postgres aborts RLS evaluation with "permission denied for function",
-- causing PostgREST to return HTTP 401 on public landing queries.

GRANT EXECUTE ON FUNCTION public.is_admin_check() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_staff_or_admin(uuid) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_admin(uuid) TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';
