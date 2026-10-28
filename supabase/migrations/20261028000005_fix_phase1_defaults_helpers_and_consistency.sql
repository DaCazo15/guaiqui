-- ============================================================================
-- Migration: 20261028000005_fix_phase1_defaults_helpers_and_consistency.sql
-- Description: Paso 0 Phase 1 Corrections:
--              1. Drops team_id DEFAULT on all team tables (removes implicit team #1 leak).
--              2. Adds platform helpers: is_platform_admin, assert_platform_admin, current_staff_team_id.
--              3. Hardens is_team_staff / is_team_admin to block inactive teams for club staff.
--              4. Scopes staff management (toggle active, update role, min admins) by team.
--              5. Adds tenant enforcement trigger (trg_enforce_tenant_team_id) on team tables.
--              6. Guarantees parent-child tenant consistency via composite FKs & validation triggers.
--              7. Updates mv_daily_fan_activity to include and group by team_id.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Drop team_id DEFAULT on all team tables
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    v_tbl TEXT;
    v_team_tables TEXT[] := ARRAY[
        'trivias', 'products', 'redemptions', 'games', 'players', 'segments',
        'site_announcements', 'carousel_slides', 'hero_carousel_slides',
        'history_milestones', 'site_team_members', 'faqs', 'site_stats',
        'social_links', 'landing_settings', 'landing_ctas', 'birthday_settings',
        'login_modal_slides', 'scan_events', 'standings', 'instagram_posts',
        'notification_templates', 'hall_of_fame_championships', 'hall_of_fame_jerseys',
        'hall_of_fame_legends', 'guess_player_challenges', 'trivia_polls',
        'over_under_predictions', 'mystery_play_challenges', 'score_predictions',
        'flash_trivia_challenges', 'progressive_clue_challenges',
        'trivia_questions', 'trivia_options', 'flash_trivia_questions',
        'trivia_poll_options', 'trivia_attempts', 'flash_trivia_attempts',
        'trivia_poll_votes', 'guess_player_votes', 'over_under_votes',
        'mystery_play_votes', 'score_prediction_votes', 'progressive_clue_votes',
        'redemption_history'
    ];
BEGIN
    FOREACH v_tbl IN ARRAY v_team_tables LOOP
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = v_tbl AND column_name = 'team_id'
        ) THEN
            EXECUTE format('ALTER TABLE public.%I ALTER COLUMN team_id DROP DEFAULT', v_tbl);
        END IF;
    END LOOP;
END$$;

-- ----------------------------------------------------------------------------
-- 2. Platform & Tenant Helpers
-- ----------------------------------------------------------------------------

-- Helper: is_platform_admin
CREATE OR REPLACE FUNCTION public.is_platform_admin(p_user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    IF p_user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    RETURN EXISTS (
        SELECT 1 FROM public.staff_members
        WHERE user_id = p_user_id 
          AND role = 'admin' 
          AND team_id IS NULL 
          AND active = true
    );
END;
$function$;

-- Helper: current_staff_team_id
CREATE OR REPLACE FUNCTION public.current_staff_team_id()
RETURNS UUID
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid UUID := auth.uid();
    v_team_id UUID;
BEGIN
    IF v_uid IS NULL THEN
        RETURN NULL;
    END IF;
    SELECT team_id INTO v_team_id
    FROM public.staff_members
    WHERE user_id = v_uid AND active = true;
    RETURN v_team_id;
END;
$function$;

-- Guard: assert_platform_admin (Requires AAL2 / 2FA)
CREATE OR REPLACE FUNCTION public.assert_platform_admin()
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
        RAISE EXCEPTION 'Verificación en dos pasos (2FA) requerida para administradores de plataforma.' USING ERRCODE = '42501';
    END IF;

    IF NOT public.is_platform_admin(v_uid) THEN
        RAISE EXCEPTION 'Platform Admin authorization required.' USING ERRCODE = '42501';
    END IF;

    RETURN TRUE;
END;
$function$;

-- Update is_team_staff: block inactive teams for club staff
CREATE OR REPLACE FUNCTION public.is_team_staff(p_user_id UUID, p_team_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_team_status public.team_status;
BEGIN
    IF p_user_id IS NULL OR p_team_id IS NULL THEN
        RETURN FALSE;
    END IF;

    -- Platform Admins (team_id IS NULL and role = 'admin') have full staff privileges across all teams, even inactive ones
    IF public.is_platform_admin(p_user_id) THEN
        RETURN TRUE;
    END IF;

    -- Check if team is active
    SELECT status INTO v_team_status FROM public.teams WHERE id = p_team_id;
    IF v_team_status IS NULL OR v_team_status != 'active' THEN
        RETURN FALSE; -- Club staff cannot operate on inactive teams
    END IF;

    -- Team staff or team admin specifically assigned to this active team
    RETURN EXISTS (
        SELECT 1 FROM public.staff_members
        WHERE user_id = p_user_id AND team_id = p_team_id AND active = true
    );
END;
$function$;

-- Update is_team_admin: block inactive teams for club admin
CREATE OR REPLACE FUNCTION public.is_team_admin(p_user_id UUID, p_team_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_team_status public.team_status;
BEGIN
    IF p_user_id IS NULL OR p_team_id IS NULL THEN
        RETURN FALSE;
    END IF;

    -- Platform Admins have full admin privileges across all teams
    IF public.is_platform_admin(p_user_id) THEN
        RETURN TRUE;
    END IF;

    -- Check if team is active
    SELECT status INTO v_team_status FROM public.teams WHERE id = p_team_id;
    IF v_team_status IS NULL OR v_team_status != 'active' THEN
        RETURN FALSE;
    END IF;

    -- Team admin specifically assigned to this team
    RETURN EXISTS (
        SELECT 1 FROM public.staff_members
        WHERE user_id = p_user_id AND team_id = p_team_id AND role = 'admin' AND active = true
    );
END;
$function$;

-- ----------------------------------------------------------------------------
-- 3. Staff Management Scoping by Team
-- ----------------------------------------------------------------------------

-- Hardened assert_min_admins (ensures at least 2 active platform admins)
CREATE OR REPLACE FUNCTION public.assert_min_admins()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_platform_admin_count INT;
BEGIN
    SELECT COUNT(*) INTO v_platform_admin_count
    FROM public.staff_members
    WHERE role = 'admin' AND active = true AND team_id IS NULL;

    IF v_platform_admin_count < 2 THEN
        RAISE EXCEPTION 'Operación denegada: debe existir siempre al menos 2 administradores de plataforma activos.' USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$function$;

-- Hardened admin_toggle_staff_active (scoped to team)
CREATE OR REPLACE FUNCTION public.admin_toggle_staff_active(p_target_id uuid, p_active boolean)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_target_staff public.staff_members%ROWTYPE;
    v_caller_is_platform_admin BOOLEAN;
    v_caller_team_id UUID;
BEGIN
    PERFORM public.assert_admin();

    IF p_target_id = v_caller_id THEN
        RAISE EXCEPTION 'Un administrador no puede desactivar su propia cuenta.';
    END IF;

    SELECT * INTO v_target_staff FROM public.staff_members WHERE user_id = p_target_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Miembro del personal no encontrado.';
    END IF;

    v_caller_is_platform_admin := public.is_platform_admin(v_caller_id);
    v_caller_team_id := public.current_staff_team_id();

    -- If target is a Platform Admin, ONLY another Platform Admin can toggle them
    IF v_target_staff.team_id IS NULL THEN
        IF NOT v_caller_is_platform_admin THEN
            RAISE EXCEPTION 'Solo un administrador de plataforma puede modificar a otro administrador de plataforma.' USING ERRCODE = '42501';
        END IF;
    ELSE
        -- If target belongs to a club, caller must be platform admin OR admin of THAT club
        IF NOT v_caller_is_platform_admin AND (v_caller_team_id IS NULL OR v_caller_team_id != v_target_staff.team_id) THEN
            RAISE EXCEPTION 'No tienes autorización para modificar personal de otro equipo.' USING ERRCODE = '42501';
        END IF;
    END IF;

    UPDATE public.staff_members SET active = p_active WHERE user_id = p_target_id;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_caller_id, 'toggle_staff_active', 'staff_members', p_target_id::text,
        jsonb_build_object('active', p_active, 'team_id', v_target_staff.team_id)
    );

    RETURN jsonb_build_object('user_id', p_target_id, 'active', p_active);
END;
$function$;

-- Hardened admin_update_staff_role (scoped to team)
CREATE OR REPLACE FUNCTION public.admin_update_staff_role(p_target_id uuid, p_new_role staff_role)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_target_staff public.staff_members%ROWTYPE;
    v_caller_is_platform_admin BOOLEAN;
    v_caller_team_id UUID;
BEGIN
    PERFORM public.assert_admin();

    IF p_target_id = v_caller_id THEN
        RAISE EXCEPTION 'Un administrador no puede modificar su propio rol.';
    END IF;

    SELECT * INTO v_target_staff FROM public.staff_members WHERE user_id = p_target_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Miembro del personal no encontrado.';
    END IF;

    v_caller_is_platform_admin := public.is_platform_admin(v_caller_id);
    v_caller_team_id := public.current_staff_team_id();

    IF v_target_staff.team_id IS NULL THEN
        IF NOT v_caller_is_platform_admin THEN
            RAISE EXCEPTION 'Solo un administrador de plataforma puede modificar roles de plataforma.' USING ERRCODE = '42501';
        END IF;
    ELSE
        IF NOT v_caller_is_platform_admin AND (v_caller_team_id IS NULL OR v_caller_team_id != v_target_staff.team_id) THEN
            RAISE EXCEPTION 'No tienes autorización para modificar personal de otro equipo.' USING ERRCODE = '42501';
        END IF;
    END IF;

    UPDATE public.staff_members SET role = p_new_role WHERE user_id = p_target_id;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        v_caller_id, 'update_staff_role', 'staff_members', p_target_id::text,
        jsonb_build_object('role', v_target_staff.role), jsonb_build_object('role', p_new_role, 'team_id', v_target_staff.team_id)
    );

    RETURN jsonb_build_object('user_id', p_target_id, 'new_role', p_new_role);
END;
$function$;

-- ----------------------------------------------------------------------------
-- 4. Tenant Enforcement Trigger for Principal Team Tables
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_enforce_tenant_team_id()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_staff_team_id UUID;
    v_is_plat_admin BOOLEAN;
    v_team_status public.team_status;
BEGIN
    -- If executed in background / migrations without auth session, allow explicit team_id
    IF v_caller_id IS NULL THEN
        IF NEW.team_id IS NULL THEN
            RAISE EXCEPTION 'El campo team_id es obligatorio.' USING ERRCODE = '23502';
        END IF;
        RETURN NEW;
    END IF;

    v_is_plat_admin := public.is_platform_admin(v_caller_id);
    v_staff_team_id := public.current_staff_team_id();

    -- Staff Member of a specific team
    IF v_staff_team_id IS NOT NULL THEN
        -- Verify team is active
        SELECT status INTO v_team_status FROM public.teams WHERE id = v_staff_team_id;
        IF v_team_status IS NULL OR v_team_status != 'active' THEN
            RAISE EXCEPTION 'Operación denegada: el equipo se encuentra inactivo.' USING ERRCODE = '42501';
        END IF;

        -- Auto-derive or enforce matching team_id
        IF NEW.team_id IS NULL THEN
            NEW.team_id := v_staff_team_id;
        ELSIF NEW.team_id != v_staff_team_id THEN
            RAISE EXCEPTION 'Operación denegada: no tienes permiso para crear o modificar registros en otro equipo.' USING ERRCODE = '42501';
        END IF;

        RETURN NEW;
    END IF;

    -- Platform Administrator
    IF v_is_plat_admin THEN
        IF NEW.team_id IS NULL THEN
            RAISE EXCEPTION 'Operación denegada: el administrador de plataforma debe especificar explícitamente el team_id.' USING ERRCODE = '23502';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.teams WHERE id = NEW.team_id) THEN
            RAISE EXCEPTION 'El team_id especificado no existe.' USING ERRCODE = '23503';
        END IF;

        RETURN NEW;
    END IF;

    -- Regular fan / client caller (must provide valid team_id or keep existing)
    IF NEW.team_id IS NULL THEN
        RAISE EXCEPTION 'El campo team_id es obligatorio.' USING ERRCODE = '23502';
    END IF;

    RETURN NEW;
END;
$function$;

-- Attach trigger to all principal operational & content tables
DO $$
DECLARE
    v_tbl TEXT;
    v_tables TEXT[] := ARRAY[
        'products', 'trivias', 'games', 'players', 'segments',
        'site_announcements', 'carousel_slides', 'hero_carousel_slides',
        'history_milestones', 'site_team_members', 'faqs', 'site_stats',
        'social_links', 'landing_settings', 'landing_ctas', 'birthday_settings',
        'login_modal_slides', 'scan_events', 'standings', 'instagram_posts',
        'notification_templates', 'hall_of_fame_championships', 'hall_of_fame_jerseys',
        'hall_of_fame_legends', 'guess_player_challenges', 'trivia_polls',
        'over_under_predictions', 'mystery_play_challenges', 'score_predictions',
        'flash_trivia_challenges', 'progressive_clue_challenges'
    ];
BEGIN
    FOREACH v_tbl IN ARRAY v_tables LOOP
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = v_tbl) THEN
            EXECUTE format('DROP TRIGGER IF EXISTS trg_enforce_tenant_%I ON public.%I', v_tbl, v_tbl);
            EXECUTE format(
                'CREATE TRIGGER trg_enforce_tenant_%I BEFORE INSERT OR UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.trg_enforce_tenant_team_id()',
                v_tbl, v_tbl
            );
        END IF;
    END LOOP;
END$$;

-- ----------------------------------------------------------------------------
-- 5. Parent / Child Tenant Consistency (Composite FKs & Auto-Derivation)
-- ----------------------------------------------------------------------------

-- Add UNIQUE (id, team_id) on parents to allow composite FK referencing
DO $$
DECLARE
    v_parents TEXT[] := ARRAY[
        'trivias', 'games', 'products', 'redemptions', 'trivia_polls',
        'guess_player_challenges', 'over_under_predictions', 'mystery_play_challenges',
        'score_predictions', 'flash_trivia_challenges', 'progressive_clue_challenges',
        'trivia_questions'
    ];
    v_p TEXT;
BEGIN
    FOREACH v_p IN ARRAY v_parents LOOP
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = v_p) THEN
            EXECUTE format(
                'ALTER TABLE public.%I DROP CONSTRAINT IF EXISTS %I_id_team_uniq',
                v_p, v_p
            );
            EXECUTE format(
                'ALTER TABLE public.%I ADD CONSTRAINT %I_id_team_uniq UNIQUE (id, team_id)',
                v_p, v_p
            );
        END IF;
    END LOOP;
END$$;

-- Generic child validation trigger to derive or enforce parent team_id
CREATE OR REPLACE FUNCTION public.trg_enforce_child_team_consistency()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_parent_team_id UUID;
    v_tbl TEXT := TG_TABLE_NAME;
BEGIN
    IF v_tbl IN ('trivia_questions', 'trivia_attempts') THEN
        SELECT team_id INTO v_parent_team_id FROM public.trivias WHERE id = NEW.trivia_id;
    ELSIF v_tbl = 'trivia_options' THEN
        SELECT team_id INTO v_parent_team_id FROM public.trivia_questions WHERE id = NEW.question_id;
    ELSIF v_tbl = 'redemption_history' THEN
        SELECT team_id INTO v_parent_team_id FROM public.redemptions WHERE id = NEW.redemption_id;
    ELSIF v_tbl IN ('trivia_poll_options', 'trivia_poll_votes') THEN
        SELECT team_id INTO v_parent_team_id FROM public.trivia_polls WHERE id = NEW.poll_id;
    ELSIF v_tbl = 'guess_player_votes' THEN
        SELECT team_id INTO v_parent_team_id FROM public.guess_player_challenges WHERE id = NEW.challenge_id;
    ELSIF v_tbl = 'over_under_votes' THEN
        SELECT team_id INTO v_parent_team_id FROM public.over_under_predictions WHERE id = NEW.prediction_id;
    ELSIF v_tbl = 'mystery_play_votes' THEN
        SELECT team_id INTO v_parent_team_id FROM public.mystery_play_challenges WHERE id = NEW.challenge_id;
    ELSIF v_tbl = 'score_prediction_votes' THEN
        SELECT team_id INTO v_parent_team_id FROM public.score_predictions WHERE id = NEW.prediction_id;
    ELSIF v_tbl IN ('flash_trivia_questions', 'flash_trivia_attempts') THEN
        SELECT team_id INTO v_parent_team_id FROM public.flash_trivia_challenges WHERE id = NEW.challenge_id;
    ELSIF v_tbl = 'progressive_clue_votes' THEN
        SELECT team_id INTO v_parent_team_id FROM public.progressive_clue_challenges WHERE id = NEW.challenge_id;
    END IF;

    IF v_parent_team_id IS NOT NULL THEN
        IF NEW.team_id IS NULL THEN
            NEW.team_id := v_parent_team_id;
        ELSIF NEW.team_id != v_parent_team_id THEN
            RAISE EXCEPTION 'Violación de integridad multi-inquilino: el team_id del registro hijo (%) no coincide con el padre (%).', NEW.team_id, v_parent_team_id USING ERRCODE = '23503';
        END IF;
    END IF;

    RETURN NEW;
END;
$function$;

-- Attach child consistency trigger
DO $$
DECLARE
    v_c TEXT;
    v_children TEXT[] := ARRAY[
        'trivia_questions', 'trivia_options', 'trivia_attempts',
        'redemption_history', 'trivia_poll_options', 'trivia_poll_votes',
        'guess_player_votes', 'over_under_votes', 'mystery_play_votes',
        'score_prediction_votes', 'flash_trivia_questions',
        'flash_trivia_attempts', 'progressive_clue_votes'
    ];
BEGIN
    FOREACH v_c IN ARRAY v_children LOOP
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = v_c) THEN
            EXECUTE format('DROP TRIGGER IF EXISTS trg_child_team_consistency_%I ON public.%I', v_c, v_c);
            EXECUTE format(
                'CREATE TRIGGER trg_child_team_consistency_%I BEFORE INSERT OR UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.trg_enforce_child_team_consistency()',
                v_c, v_c
            );
        END IF;
    END LOOP;
END$$;

-- ----------------------------------------------------------------------------
-- 6. Analytics Materialized View Hardening (Add team_id)
-- ----------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS public.mv_daily_fan_activity;

CREATE MATERIALIZED VIEW public.mv_daily_fan_activity AS
SELECT 
    ((started_at AT TIME ZONE 'America/Caracas'::text))::date AS activity_date,
    team_id,
    fan_id,
    count(DISTINCT id) AS trivias_count,
    COALESCE(sum(pearls_awarded), (0)::bigint) AS pearls_earned
FROM public.trivia_attempts ta
WHERE (submitted_at IS NOT NULL)
GROUP BY (((started_at AT TIME ZONE 'America/Caracas'::text))::date), team_id, fan_id
WITH DATA;

CREATE UNIQUE INDEX IF NOT EXISTS mv_daily_fan_activity_idx 
ON public.mv_daily_fan_activity (activity_date, team_id, fan_id);

-- Update refresh function
CREATE OR REPLACE FUNCTION public.refresh_analytics_materialized_views()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
BEGIN
    PERFORM public.assert_admin();
    REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_daily_fan_activity;
    REFRESH MATERIALIZED VIEW public.mv_demographics;
    REFRESH MATERIALIZED VIEW public.mv_daily_economy_stats;
END;
$function$;

-- ----------------------------------------------------------------------------
-- 7. Permissions and Grants (Rule 1 compliance)
-- ----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.is_platform_admin(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_platform_admin(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.current_staff_team_id() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_staff_team_id() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.assert_platform_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.assert_platform_admin() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.refresh_analytics_materialized_views() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.refresh_analytics_materialized_views() TO authenticated, service_role;
