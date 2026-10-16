-- Migration: 20261007000007_security_audit_purge_identities.sql
-- Description: Drop any execute_sql function if present, and create secure purge_auth_identities RPC executable ONLY by service_role.

-- 1. Drop public.execute_sql if any ever existed
DROP FUNCTION IF EXISTS public.execute_sql;
DROP FUNCTION IF EXISTS public.execute_sql(text);

-- 2. Create public.purge_auth_identities(p_user_id UUID)
-- Strictly static SQL without string concatenation or interpolation
CREATE OR REPLACE FUNCTION public.purge_auth_identities(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_deleted_count INT := 0;
BEGIN
    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'User ID is required.';
    END IF;

    -- Delete identities matching exact user_id parameter
    DELETE FROM auth.identities WHERE user_id = p_user_id;
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

    RETURN jsonb_build_object(
        'success', true,
        'purged_user_id', p_user_id,
        'identities_removed', v_deleted_count
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 3. Strict Permissions: Revoke execute from PUBLIC, anon, and authenticated (fan / staff)
-- Grant execute ONLY to service_role (used by Edge Functions / Admin client)
REVOKE ALL ON FUNCTION public.purge_auth_identities(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.purge_auth_identities(UUID) TO service_role;
