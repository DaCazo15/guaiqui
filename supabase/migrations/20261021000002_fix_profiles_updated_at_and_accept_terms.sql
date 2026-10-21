-- ============================================================================
-- Migration: 20261021000002_fix_profiles_updated_at_and_accept_terms.sql
-- Description:
-- 1. Adds updated_at column to public.profiles if not exists.
-- 2. Updates public.accept_terms() RPC to safely update updated_at and sync active policy versions.
-- 3. Grants EXECUTE on get_active_legal_versions() to authenticated, anon, and service_role.
-- ============================================================================

-- 1. Add updated_at to public.profiles
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- 2. Update accept_terms() RPC to sync active policy versions and record updated_at
CREATE OR REPLACE FUNCTION public.accept_terms()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_now TIMESTAMPTZ := NOW();
    v_term_ver TEXT := '1.0';
    v_priv_ver TEXT := '1.0';
    v_perl_ver TEXT := '1.0';
BEGIN
    PERFORM public.assert_active_verified_fan();

    -- Retrieve currently active versions from policy_documents (fallback to default 1.0)
    SELECT COALESCE((SELECT version FROM public.policy_documents WHERE slug = 'terminos' AND is_active = true LIMIT 1), '1.0') INTO v_term_ver;
    SELECT COALESCE((SELECT version FROM public.policy_documents WHERE slug = 'privacidad' AND is_active = true LIMIT 1), '1.0') INTO v_priv_ver;
    SELECT COALESCE((SELECT version FROM public.policy_documents WHERE slug = 'perlitas' AND is_active = true LIMIT 1), '1.0') INTO v_perl_ver;

    UPDATE public.profiles
    SET terms_accepted_at = v_now,
        terms_version = v_term_ver,
        privacy_accepted_at = v_now,
        privacy_version = v_priv_ver,
        pearls_rules_accepted_at = v_now,
        pearls_rules_version = v_perl_ver,
        updated_at = v_now
    WHERE id = v_user_id;

    RETURN jsonb_build_object(
        'success', true,
        'accepted_at', v_now,
        'terms_version', v_term_ver,
        'privacy_version', v_priv_ver,
        'pearls_rules_version', v_perl_ver
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.accept_terms() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accept_terms() TO authenticated, service_role;

-- 3. Ensure get_active_legal_versions() is accessible to authenticated and anon users
REVOKE ALL ON FUNCTION public.get_active_legal_versions() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_active_legal_versions() TO authenticated, anon, service_role;
