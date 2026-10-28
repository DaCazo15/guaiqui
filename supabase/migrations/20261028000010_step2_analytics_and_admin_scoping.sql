-- Migration 20261028000010_step2_analytics_and_admin_scoping.sql
-- Paso 2 / Paso 0D: Completar acotamiento por equipo para analytics_top_fans y analytics_demographics

CREATE OR REPLACE FUNCTION public.analytics_top_fans(
    p_limit INTEGER DEFAULT 10,
    p_start_date TIMESTAMPTZ DEFAULT NULL::TIMESTAMPTZ,
    p_end_date TIMESTAMPTZ DEFAULT NULL::TIMESTAMPTZ,
    p_team_id UUID DEFAULT NULL::UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_is_platform_admin BOOLEAN := public.is_platform_admin(v_caller_id);
    v_staff_team_id UUID := public.current_staff_team_id();
    v_team_id UUID;
    v_start TIMESTAMPTZ := COALESCE(p_start_date, NOW() - INTERVAL '30 days');
    v_end TIMESTAMPTZ := COALESCE(p_end_date, NOW());
    v_result JSONB;
BEGIN
    PERFORM public.assert_admin();

    IF v_is_platform_admin THEN
        v_team_id := p_team_id;
    ELSE
        IF v_staff_team_id IS NULL THEN
            RAISE EXCEPTION 'Club admin must belong to an active team.' USING ERRCODE = '42501';
        END IF;
        IF p_team_id IS NOT NULL AND p_team_id != v_staff_team_id THEN
            RAISE EXCEPTION 'No tienes autorización para consultar analítica de otro equipo.' USING ERRCODE = '42501';
        END IF;
        v_team_id := v_staff_team_id;
    END IF;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'fan_id', fan_id,
                'display_name', display_name,
                'avatar_url', avatar_url,
                'trivias_played', trivias_played,
                'pearls_earned', pearls_earned
            ) ORDER BY pearls_earned DESC
        ),
        '[]'::jsonb
    ) INTO v_result
    FROM (
        SELECT
            p.id AS fan_id,
            p.display_name,
            p.avatar_url,
            COUNT(DISTINCT ta.id) AS trivias_played,
            COALESCE(SUM(ta.pearls_awarded), 0) AS pearls_earned
        FROM public.profiles p
        JOIN public.trivia_attempts ta ON ta.fan_id = p.id
        WHERE ta.submitted_at IS NOT NULL
          AND ta.submitted_at >= v_start
          AND ta.submitted_at <= v_end
          AND (v_team_id IS NULL OR ta.team_id = v_team_id)
        GROUP BY p.id, p.display_name, p.avatar_url
        ORDER BY pearls_earned DESC
        LIMIT LEAST(GREATEST(p_limit, 1), 50)
    ) sub;

    RETURN v_result;
END;
$function$;

REVOKE ALL ON FUNCTION public.analytics_top_fans(INTEGER, TIMESTAMPTZ, TIMESTAMPTZ, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.analytics_top_fans(INTEGER, TIMESTAMPTZ, TIMESTAMPTZ, UUID) TO authenticated, service_role;

-- analytics_demographics con parámetro opcional de equipo
CREATE OR REPLACE FUNCTION public.analytics_demographics(
    p_team_id UUID DEFAULT NULL::UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_is_platform_admin BOOLEAN := public.is_platform_admin(v_caller_id);
    v_staff_team_id UUID := public.current_staff_team_id();
    v_team_id UUID;
    v_municipality JSONB;
    v_gender JSONB;
    v_age_groups JSONB;
BEGIN
    PERFORM public.assert_admin();

    IF v_is_platform_admin THEN
        v_team_id := p_team_id;
    ELSE
        IF v_staff_team_id IS NULL THEN
            RAISE EXCEPTION 'Club admin must belong to an active team.' USING ERRCODE = '42501';
        END IF;
        IF p_team_id IS NOT NULL AND p_team_id != v_staff_team_id THEN
            RAISE EXCEPTION 'No tienes autorización para consultar analítica de otro equipo.' USING ERRCODE = '42501';
        END IF;
        v_team_id := v_staff_team_id;
    END IF;

    -- Si v_team_id IS NULL y es platform admin, usa mv_demographics global si existe, o calcula directamente
    IF v_team_id IS NULL THEN
        SELECT COALESCE(jsonb_agg(jsonb_build_object('name', group_name, 'count', total_count) ORDER BY total_count DESC), '[]'::jsonb)
        INTO v_municipality
        FROM (
            SELECT
                CASE WHEN COUNT(*) >= 5 THEN COALESCE(p.municipality, 'No especificado') ELSE 'Otros (< 5)' END AS group_name,
                COUNT(*) AS total_count
            FROM public.profiles p
            WHERE p.status = 'active'
            GROUP BY 1
        ) sub;

        SELECT COALESCE(jsonb_agg(jsonb_build_object('name', group_name, 'count', total_count) ORDER BY total_count DESC), '[]'::jsonb)
        INTO v_gender
        FROM (
            SELECT
                CASE WHEN COUNT(*) >= 5 THEN COALESCE(p.gender, 'No especificado') ELSE 'Otros (< 5)' END AS group_name,
                COUNT(*) AS total_count
            FROM public.profiles p
            WHERE p.status = 'active'
            GROUP BY 1
        ) sub;

        SELECT COALESCE(jsonb_agg(jsonb_build_object('name', group_name, 'count', total_count) ORDER BY total_count DESC), '[]'::jsonb)
        INTO v_age_groups
        FROM (
            SELECT
                CASE
                    WHEN p.birth_date IS NULL THEN 'No especificado'
                    WHEN EXTRACT(YEAR FROM age(CURRENT_DATE, p.birth_date)) < 18 THEN '< 18'
                    WHEN EXTRACT(YEAR FROM age(CURRENT_DATE, p.birth_date)) BETWEEN 18 AND 24 THEN '18-24'
                    WHEN EXTRACT(YEAR FROM age(CURRENT_DATE, p.birth_date)) BETWEEN 25 AND 34 THEN '25-34'
                    WHEN EXTRACT(YEAR FROM age(CURRENT_DATE, p.birth_date)) BETWEEN 35 AND 44 THEN '35-44'
                    WHEN EXTRACT(YEAR FROM age(CURRENT_DATE, p.birth_date)) BETWEEN 45 AND 54 THEN '45-54'
                    ELSE '55+'
                END AS group_name,
                COUNT(*) AS total_count
            FROM public.profiles p
            WHERE p.status = 'active'
            GROUP BY 1
        ) sub;
    ELSE
        -- Acotado a los fans que siguen al equipo v_team_id
        SELECT COALESCE(jsonb_agg(jsonb_build_object('name', group_name, 'count', total_count) ORDER BY total_count DESC), '[]'::jsonb)
        INTO v_municipality
        FROM (
            SELECT
                CASE WHEN COUNT(*) >= 5 THEN COALESCE(p.municipality, 'No especificado') ELSE 'Otros (< 5)' END AS group_name,
                COUNT(*) AS total_count
            FROM public.profiles p
            JOIN public.team_follows tf ON tf.user_id = p.id
            WHERE p.status = 'active'
              AND tf.team_id = v_team_id
            GROUP BY 1
        ) sub;

        SELECT COALESCE(jsonb_agg(jsonb_build_object('name', group_name, 'count', total_count) ORDER BY total_count DESC), '[]'::jsonb)
        INTO v_gender
        FROM (
            SELECT
                CASE WHEN COUNT(*) >= 5 THEN COALESCE(p.gender, 'No especificado') ELSE 'Otros (< 5)' END AS group_name,
                COUNT(*) AS total_count
            FROM public.profiles p
            JOIN public.team_follows tf ON tf.user_id = p.id
            WHERE p.status = 'active'
              AND tf.team_id = v_team_id
            GROUP BY 1
        ) sub;

        SELECT COALESCE(jsonb_agg(jsonb_build_object('name', group_name, 'count', total_count) ORDER BY total_count DESC), '[]'::jsonb)
        INTO v_age_groups
        FROM (
            SELECT
                CASE
                    WHEN p.birth_date IS NULL THEN 'No especificado'
                    WHEN EXTRACT(YEAR FROM age(CURRENT_DATE, p.birth_date)) < 18 THEN '< 18'
                    WHEN EXTRACT(YEAR FROM age(CURRENT_DATE, p.birth_date)) BETWEEN 18 AND 24 THEN '18-24'
                    WHEN EXTRACT(YEAR FROM age(CURRENT_DATE, p.birth_date)) BETWEEN 25 AND 34 THEN '25-34'
                    WHEN EXTRACT(YEAR FROM age(CURRENT_DATE, p.birth_date)) BETWEEN 35 AND 44 THEN '35-44'
                    WHEN EXTRACT(YEAR FROM age(CURRENT_DATE, p.birth_date)) BETWEEN 45 AND 54 THEN '45-54'
                    ELSE '55+'
                END AS group_name,
                COUNT(*) AS total_count
            FROM public.profiles p
            JOIN public.team_follows tf ON tf.user_id = p.id
            WHERE p.status = 'active'
              AND tf.team_id = v_team_id
            GROUP BY 1
        ) sub;
    END IF;

    RETURN jsonb_build_object(
        'municipality', COALESCE(v_municipality, '[]'::jsonb),
        'gender', COALESCE(v_gender, '[]'::jsonb),
        'age_groups', COALESCE(v_age_groups, '[]'::jsonb)
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.analytics_demographics(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.analytics_demographics(UUID) TO authenticated, service_role;
