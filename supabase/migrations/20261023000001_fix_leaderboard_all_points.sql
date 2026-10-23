-- Migration: 20261023000001_fix_leaderboard_all_points.sql
-- Description: Update get_leaderboard to count all points regardless of source (no type filtering) and support all_time, monthly, weekly

CREATE OR REPLACE FUNCTION public.get_leaderboard(p_period text DEFAULT 'all_time'::text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid UUID := auth.uid();
    v_start_date TIMESTAMPTZ;
    v_leaderboard JSONB;
BEGIN
    IF p_period = 'weekly' THEN
        v_start_date := date_trunc('week', NOW() AT TIME ZONE 'America/Caracas');
    ELSIF p_period = 'monthly' THEN
        v_start_date := date_trunc('month', NOW() AT TIME ZONE 'America/Caracas');
    ELSE
        -- 'all_time' or default: sin restricción de fecha para puntaje total acumulado
        v_start_date := NULL;
    END IF;

    SELECT jsonb_agg(
        jsonb_build_object(
            'rank', r.rank_number,
            'user_id', r.fan_id,
            'display_name', r.display_name,
            'avatar_url', r.avatar_url,
            'pearls_earned', r.total_pearls,
            'is_current_user', (r.fan_id = v_uid)
        )
    ) INTO v_leaderboard
    FROM (
        SELECT 
            p.id AS fan_id,
            p.display_name,
            p.avatar_url,
            COALESCE(SUM(l.amount), 0)::int AS total_pearls,
            ROW_NUMBER() OVER (ORDER BY COALESCE(SUM(l.amount), 0) DESC, p.created_at ASC) AS rank_number
        FROM profiles p
        JOIN ledger_entries l ON l.fan_id = p.id
        WHERE p.status = 'active'
          AND p.deleted_at IS NULL
          AND l.status = 'confirmed'
          AND l.amount > 0
          AND (v_start_date IS NULL OR l.created_at >= v_start_date)
        GROUP BY p.id, p.display_name, p.avatar_url, p.created_at
        HAVING COALESCE(SUM(l.amount), 0) > 0
        ORDER BY total_pearls DESC
        LIMIT 50
    ) r;

    RETURN jsonb_build_object(
        'period', p_period,
        'leaderboard', COALESCE(v_leaderboard, '[]'::jsonb)
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.get_leaderboard(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_leaderboard(text) TO authenticated, service_role, anon;
