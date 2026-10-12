-- Migration: 20261011000042_grant_get_attempt_questions.sql
-- Description: Grant EXECUTE on get_attempt_questions to authenticated and service_role,
--              restoring access that was revoked in strict_rpc_allowlist migration.

REVOKE ALL ON FUNCTION public.get_attempt_questions(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_attempt_questions(UUID) TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';
