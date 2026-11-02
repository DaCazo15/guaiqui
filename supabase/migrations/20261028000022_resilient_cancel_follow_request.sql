-- ============================================================================
-- Migration: 20261028000022_resilient_cancel_follow_request.sql
-- Description: Hacer cancel_follow_request tolerante a estados 'pending' y 'accepted'
-- ============================================================================

CREATE OR REPLACE FUNCTION public.cancel_follow_request(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_uid UUID;
BEGIN
    v_uid := public.assert_active_verified_fan();

    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'p_user_id es requerido.' USING ERRCODE = 'P0002';
    END IF;

    -- Eliminar relación de seguimiento ya sea que esté pendiente o aceptada
    DELETE FROM public.user_follows
    WHERE follower_id = v_uid AND followed_id = p_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No hay solicitud o seguimiento para cancelar.' USING ERRCODE = 'P0002';
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'cancelled_user_id', p_user_id
    );
END;
$$;

REVOKE ALL ON FUNCTION public.cancel_follow_request(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_follow_request(UUID) TO authenticated;
