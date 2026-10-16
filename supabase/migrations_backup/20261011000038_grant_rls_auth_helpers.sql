-- Migration: 20261011000038_grant_rls_auth_helpers.sql
-- Description: Restores execute privileges on RLS helper functions (is_staff_or_admin, is_admin, is_admin_check) for authenticated and anon roles.

-- 1. Grant execute on staff and admin RLS helper functions
GRANT EXECUTE ON FUNCTION public.is_staff_or_admin(UUID) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.is_admin(UUID) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.is_admin_check() TO authenticated, anon, service_role;

-- 2. Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
