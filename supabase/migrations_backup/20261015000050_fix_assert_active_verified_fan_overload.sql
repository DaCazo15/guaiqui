-- Migration: 20261015000050_fix_assert_active_verified_fan_overload.sql
-- Description: Create public.assert_active_verified_fan(uuid) overload to fix 'function public.assert_active_verified_fan(uuid) does not exist'.

CREATE OR REPLACE FUNCTION public.assert_active_verified_fan(p_user_id UUID)
RETURNS UUID AS $$
DECLARE
    v_uid UUID := COALESCE(p_user_id, auth.uid());
    v_email_confirmed TIMESTAMPTZ;
    v_profile_status user_status;
    v_deleted_at TIMESTAMPTZ;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    -- Ensure caller matches the target or caller is service_role
    IF auth.uid() IS NOT NULL AND v_uid != auth.uid() THEN
        RAISE EXCEPTION 'Unauthorized.';
    END IF;

    -- Check email confirmation in auth.users
    SELECT email_confirmed_at INTO v_email_confirmed
    FROM auth.users
    WHERE id = v_uid;

    IF v_email_confirmed IS NULL THEN
        RAISE EXCEPTION 'El correo electrónico debe estar verificado para realizar esta acción.';
    END IF;

    -- Check profile status
    SELECT status, deleted_at INTO v_profile_status, v_deleted_at
    FROM public.profiles
    WHERE id = v_uid;

    IF v_profile_status IS NULL OR v_profile_status != 'active' OR v_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION 'Tu cuenta está inactiva, suspendida o ha sido eliminada.';
    END IF;

    RETURN v_uid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

REVOKE ALL ON FUNCTION public.assert_active_verified_fan(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.assert_active_verified_fan(UUID) TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';
