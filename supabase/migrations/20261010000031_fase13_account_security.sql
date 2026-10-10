-- Migration: 20261010000031_fase13_account_security.sql
-- Description: Account Security (Fase 13) - 2FA AAL2 server enforcement, mfa_recovery_codes, profile protection, birth_date 12-month limit, display_name rules, and min-2-admins invariant.

-- 1. Helper user_has_verified_mfa(p_uid)
CREATE OR REPLACE FUNCTION public.user_has_verified_mfa(p_uid UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM auth.mfa_factors
    WHERE user_id = p_uid AND status = 'verified';
    
    RETURN COALESCE(v_count, 0) > 0;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

REVOKE ALL ON FUNCTION public.user_has_verified_mfa(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.user_has_verified_mfa(UUID) TO authenticated, service_role;

-- 2. Update assert_staff() to enforce AAL2
CREATE OR REPLACE FUNCTION public.assert_staff()
RETURNS BOOLEAN AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_aal TEXT := (auth.jwt() ->> 'aal');
    v_active BOOLEAN;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Usuario no autenticado' USING ERRCODE = '42501';
    END IF;

    IF v_aal IS NULL OR v_aal != 'aal2' THEN
        RAISE EXCEPTION 'Verificación en dos pasos (2FA) requerida para personal.' USING ERRCODE = '42501';
    END IF;

    SELECT active INTO v_active
    FROM public.staff_members
    WHERE user_id = v_uid;

    IF v_active IS NOT TRUE THEN
        RAISE EXCEPTION 'Staff or Admin authorization required.' USING ERRCODE = '42501';
    END IF;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.assert_staff() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.assert_staff() TO authenticated, service_role;

-- 3. Update assert_admin() to enforce AAL2
CREATE OR REPLACE FUNCTION public.assert_admin()
RETURNS BOOLEAN AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_aal TEXT := (auth.jwt() ->> 'aal');
    v_role staff_role;
    v_active BOOLEAN;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Usuario no autenticado' USING ERRCODE = '42501';
    END IF;

    IF v_aal IS NULL OR v_aal != 'aal2' THEN
        RAISE EXCEPTION 'Verificación en dos pasos (2FA) requerida para administradores.' USING ERRCODE = '42501';
    END IF;

    SELECT role, active INTO v_role, v_active
    FROM public.staff_members
    WHERE user_id = v_uid;

    IF v_active IS NOT TRUE OR v_role != 'admin' THEN
        RAISE EXCEPTION 'Admin authorization required.' USING ERRCODE = '42501';
    END IF;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.assert_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.assert_admin() TO authenticated, service_role;

-- 4. Table mfa_recovery_codes (Server-Only)
CREATE TABLE IF NOT EXISTS public.mfa_recovery_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    code_hash TEXT NOT NULL,
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.mfa_recovery_codes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.mfa_recovery_codes FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.mfa_recovery_codes TO service_role;

-- RPC save_mfa_recovery_code_hashes
CREATE OR REPLACE FUNCTION public.save_mfa_recovery_code_hashes(p_hashes TEXT[])
RETURNS JSONB AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_aal TEXT := (auth.jwt() ->> 'aal');
    v_hash TEXT;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Usuario no autenticado' USING ERRCODE = '42501';
    END IF;

    -- Replace existing recovery codes for user
    DELETE FROM public.mfa_recovery_codes WHERE user_id = v_uid;

    FOREACH v_hash IN ARRAY p_hashes LOOP
        INSERT INTO public.mfa_recovery_codes (user_id, code_hash)
        VALUES (v_uid, v_hash);
    END LOOP;

    RETURN jsonb_build_object('success', true, 'count', array_length(p_hashes, 1));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.save_mfa_recovery_code_hashes(TEXT[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_mfa_recovery_code_hashes(TEXT[]) TO authenticated, service_role;

-- 5. Birth Date Rate Limiting (1 change per 12 months for fans)
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_birth_date_change TIMESTAMPTZ;

CREATE OR REPLACE FUNCTION public.update_birth_date(p_birth_date DATE)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_current_bdate DATE;
    v_last_change TIMESTAMPTZ;
BEGIN
    PERFORM public.assert_active_verified_fan();

    IF p_birth_date IS NULL THEN
        RAISE EXCEPTION 'La fecha de nacimiento es obligatoria.';
    END IF;

    SELECT birth_date, last_birth_date_change INTO v_current_bdate, v_last_change
    FROM public.profiles WHERE id = v_user_id;

    IF v_current_bdate IS NULL THEN
        -- Initial set
        UPDATE public.profiles
        SET birth_date = p_birth_date,
            last_birth_date_change = NOW(),
            updated_at = NOW()
        WHERE id = v_user_id;
    ELSE
        -- Check 12 month interval
        IF v_last_change IS NOT NULL AND v_last_change > NOW() - INTERVAL '12 months' THEN
            RAISE EXCEPTION 'Solo se permite una corrección de fecha de nacimiento cada 12 meses.';
        END IF;

        UPDATE public.profiles
        SET birth_date = p_birth_date,
            last_birth_date_change = NOW(),
            updated_at = NOW()
        WHERE id = v_user_id;
    END IF;

    RETURN jsonb_build_object('success', true, 'birth_date', p_birth_date);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.update_birth_date(DATE) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_birth_date(DATE) TO authenticated, service_role;

-- Admin update birth date with reason
CREATE OR REPLACE FUNCTION public.admin_update_birth_date(
    p_user_id UUID,
    p_birth_date DATE,
    p_reason TEXT
)
RETURNS JSONB AS $$
BEGIN
    PERFORM public.assert_admin();

    IF p_user_id IS NULL OR p_birth_date IS NULL OR p_reason IS NULL OR TRIM(p_reason) = '' THEN
        RAISE EXCEPTION 'El usuario, la nueva fecha y el motivo son obligatorios.';
    END IF;

    UPDATE public.profiles
    SET birth_date = p_birth_date,
        updated_at = NOW()
    WHERE id = p_user_id;

    INSERT INTO public.audit_logs (actor_id, action, target_table, target_id, details)
    VALUES (
        auth.uid(),
        'admin_update_birth_date',
        'profiles',
        p_user_id::text,
        jsonb_build_object('new_birth_date', p_birth_date, 'reason', p_reason)
    );

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.admin_update_birth_date(UUID, DATE, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_birth_date(UUID, DATE, TEXT) TO authenticated, service_role;

-- 6. Display Name Validation & Rate Limiting (max 3 changes per month)
CREATE TABLE IF NOT EXISTS public.display_name_change_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    old_name TEXT,
    new_name TEXT NOT NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.display_name_change_logs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.display_name_change_logs FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.display_name_change_logs TO service_role;

CREATE OR REPLACE FUNCTION public.update_display_name(p_display_name TEXT)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_clean_name TEXT := TRIM(p_display_name);
    v_lower_name TEXT := LOWER(v_clean_name);
    v_changes_count INT;
    v_old_name TEXT;
    v_reserved_match TEXT;
BEGIN
    PERFORM public.assert_active_verified_fan();

    -- Length validation
    IF v_clean_name IS NULL OR CHAR_LENGTH(v_clean_name) < 3 OR CHAR_LENGTH(v_clean_name) > 30 THEN
        RAISE EXCEPTION 'El nombre de usuario debe tener entre 3 y 30 caracteres.';
    END IF;

    -- Valid characters (alphanumeric, spaces, underscores, Spanish accents)
    IF v_clean_name !~ '^[a-zA-Z0-9_ áéíóúÁÉÍÓÚñÑ]+$' THEN
        RAISE EXCEPTION 'El nombre contiene caracteres no permitidos.';
    END IF;

    -- Check static reserved words
    IF v_lower_name LIKE '%admin%' OR v_lower_name LIKE '%guaiqueries%' OR v_lower_name LIKE '%oficial%' THEN
        RAISE EXCEPTION 'El nombre contiene términos reservados no permitidos.';
    END IF;

    -- Check player names reserved words
    SELECT full_name INTO v_reserved_match
    FROM public.players
    WHERE LOWER(v_clean_name) LIKE '%' || LOWER(full_name) || '%'
    LIMIT 1;

    IF v_reserved_match IS NOT NULL THEN
        RAISE EXCEPTION 'El nombre no puede ser idéntico al de un jugador del equipo.';
    END IF;

    -- Monthly rate limit check (max 3 per calendar month)
    SELECT COUNT(*) INTO v_changes_count
    FROM public.display_name_change_logs
    WHERE user_id = v_user_id
      AND DATE_TRUNC('month', changed_at) = DATE_TRUNC('month', NOW());

    IF v_changes_count >= 3 THEN
        RAISE EXCEPTION 'Has alcanzado el límite máximo de 3 cambios de nombre por mes.';
    END IF;

    SELECT display_name INTO v_old_name FROM public.profiles WHERE id = v_user_id;

    UPDATE public.profiles
    SET display_name = v_clean_name,
        updated_at = NOW()
    WHERE id = v_user_id;

    INSERT INTO public.display_name_change_logs (user_id, old_name, new_name)
    VALUES (v_user_id, v_old_name, v_clean_name);

    RETURN jsonb_build_object('success', true, 'display_name', v_clean_name);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.update_display_name(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_display_name(TEXT) TO authenticated, service_role;

-- 7. Minimum 2 Admins Invariant Protection
CREATE OR REPLACE FUNCTION public.assert_min_admins()
RETURNS TRIGGER AS $$
DECLARE
    v_admin_count INT;
BEGIN
    -- Check active admins count
    SELECT COUNT(*) INTO v_admin_count
    FROM public.staff_members
    WHERE role = 'admin' AND active = true;

    IF v_admin_count < 2 THEN
        RAISE EXCEPTION 'Operación denegada: debe existir siempre al menos 2 administradores activos en el sistema.' USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

DROP TRIGGER IF EXISTS trg_assert_min_admins ON public.staff_members;
CREATE CONSTRAINT TRIGGER trg_assert_min_admins
AFTER UPDATE OR DELETE ON public.staff_members
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.assert_min_admins();

-- 8. Security Notifications Helper
CREATE OR REPLACE FUNCTION public.create_security_notification(
    p_user_id UUID,
    p_title TEXT,
    p_body TEXT
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO public.notifications (user_id, title, message, type)
    VALUES (p_user_id, p_title, p_body, 'security');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.create_security_notification(UUID, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_security_notification(UUID, TEXT, TEXT) TO authenticated, service_role;

-- Grant EXECUTE permission on public functions to allowlist
