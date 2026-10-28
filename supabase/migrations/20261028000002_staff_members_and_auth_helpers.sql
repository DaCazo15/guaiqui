-- ============================================================================
-- Migration: 20261028000002_staff_members_and_auth_helpers.sql
-- Description: Multi-tenant Steps 2 & 3:
--              1. Adds team_id to public.staff_members (nullable: NULL for platform
--                 admin, NOT NULL for club staff/admin).
--              2. Backfills existing club staff with Guaiqueríes de Margarita team ID.
--              3. Creates multi-tenant authorization helpers:
--                 - is_team_staff(user_id, team_id)
--                 - is_team_admin(user_id, team_id)
--                 - assert_team_staff(team_id)
--                 - assert_team_admin(team_id)
--              4. Enforces strict search_path, revokes PUBLIC/anon, grants authenticated.
-- ============================================================================

-- 1. Alter public.staff_members to add team_id
ALTER TABLE public.staff_members
ADD COLUMN IF NOT EXISTS team_id UUID REFERENCES public.teams(id) ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS staff_members_team_id_idx ON public.staff_members(team_id);

-- 2. Backfill existing staff members:
-- Club staff members (role = 'staff') are assigned to Guaiqueríes de Margarita.
-- Admins without team_id remain platform administrators (global).
UPDATE public.staff_members
SET team_id = 'a0000000-0000-0000-0000-000000000001'
WHERE team_id IS NULL AND role = 'staff';

-- 3. Multi-tenant Authorization Helpers

-- Helper: is_team_staff
CREATE OR REPLACE FUNCTION public.is_team_staff(p_user_id UUID, p_team_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    IF p_user_id IS NULL OR p_team_id IS NULL THEN
        RETURN FALSE;
    END IF;

    -- Platform Admins (team_id IS NULL and role = 'admin') have full staff privileges across all teams
    IF EXISTS (
        SELECT 1 FROM public.staff_members
        WHERE user_id = p_user_id AND team_id IS NULL AND role = 'admin' AND active = true
    ) THEN
        RETURN TRUE;
    END IF;

    -- Team staff or team admin specifically assigned to this team
    RETURN EXISTS (
        SELECT 1 FROM public.staff_members
        WHERE user_id = p_user_id AND team_id = p_team_id AND active = true
    );
END;
$function$;

-- Helper: is_team_admin
CREATE OR REPLACE FUNCTION public.is_team_admin(p_user_id UUID, p_team_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    IF p_user_id IS NULL OR p_team_id IS NULL THEN
        RETURN FALSE;
    END IF;

    -- Platform Admins (team_id IS NULL and role = 'admin') have full admin privileges across all teams
    IF EXISTS (
        SELECT 1 FROM public.staff_members
        WHERE user_id = p_user_id AND team_id IS NULL AND role = 'admin' AND active = true
    ) THEN
        RETURN TRUE;
    END IF;

    -- Team admin specifically assigned to this team
    RETURN EXISTS (
        SELECT 1 FROM public.staff_members
        WHERE user_id = p_user_id AND team_id = p_team_id AND role = 'admin' AND active = true
    );
END;
$function$;

-- Guard: assert_team_staff
CREATE OR REPLACE FUNCTION public.assert_team_staff(p_team_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_uid UUID := auth.uid();
    v_aal TEXT := (auth.jwt() ->> 'aal');
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Usuario no autenticado' USING ERRCODE = '42501';
    END IF;

    IF v_aal IS NULL OR v_aal != 'aal2' THEN
        RAISE EXCEPTION 'Verificación en dos pasos (2FA) requerida para personal.' USING ERRCODE = '42501';
    END IF;

    IF NOT public.is_team_staff(v_uid, p_team_id) THEN
        RAISE EXCEPTION 'Team Staff authorization required.' USING ERRCODE = '42501';
    END IF;

    RETURN TRUE;
END;
$function$;

-- Guard: assert_team_admin
CREATE OR REPLACE FUNCTION public.assert_team_admin(p_team_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_uid UUID := auth.uid();
    v_aal TEXT := (auth.jwt() ->> 'aal');
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Usuario no autenticado' USING ERRCODE = '42501';
    END IF;

    IF v_aal IS NULL OR v_aal != 'aal2' THEN
        RAISE EXCEPTION 'Verificación en dos pasos (2FA) requerida para administradores.' USING ERRCODE = '42501';
    END IF;

    IF NOT public.is_team_admin(v_uid, p_team_id) THEN
        RAISE EXCEPTION 'Team Admin authorization required.' USING ERRCODE = '42501';
    END IF;

    RETURN TRUE;
END;
$function$;

-- 4. Revoke and Grant Permissions (Rule 1 compliance)
REVOKE ALL ON FUNCTION public.is_team_staff(UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_team_staff(UUID, UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.is_team_admin(UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_team_admin(UUID, UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.assert_team_staff(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.assert_team_staff(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.assert_team_admin(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.assert_team_admin(UUID) TO authenticated, service_role;
