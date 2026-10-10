-- Migration: 20261010000028_analytics_and_scan_location_repairs.sql
-- Description: Adds latitude/longitude to scan_events, fixes analytics_trivias correct_rate evaluation, rewrites analytics_active_users grouping, unifies analytics_funnel cohort, hardens refresh_analytics_materialized_views and schedules hourly cron.

-- 1. Add geolocation columns to scan_events
ALTER TABLE public.scan_events
ADD COLUMN IF NOT EXISTS latitude NUMERIC,
ADD COLUMN IF NOT EXISTS longitude NUMERIC;


-- 2. Fix analytics_trivias (evaluate answers against trivia_options.is_correct)
CREATE OR REPLACE FUNCTION public.analytics_trivias(
    p_start_date TIMESTAMPTZ DEFAULT NULL,
    p_end_date TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_start TIMESTAMPTZ := COALESCE(p_start_date, NOW() - INTERVAL '30 days');
    v_end TIMESTAMPTZ := COALESCE(p_end_date, NOW());
    v_popular JSONB;
    v_hardest_questions JSONB;
BEGIN
    PERFORM public.assert_admin();

    -- Trivias summary
    SELECT jsonb_agg(
        jsonb_build_object(
            'trivia_id', trivia_id,
            'title', title,
            'attempts_count', attempts_count,
            'avg_score', avg_score,
            'completion_rate', completion_rate
        ) ORDER BY attempts_count DESC
    ) INTO v_popular
    FROM (
        SELECT
            t.id AS trivia_id,
            t.title,
            COUNT(ta.id) AS attempts_count,
            ROUND(AVG(ta.score)::NUMERIC, 1) AS avg_score,
            ROUND(
                (COUNT(CASE WHEN ta.submitted_at IS NOT NULL THEN 1 END)::NUMERIC / NULLIF(COUNT(ta.id), 0) * 100)::NUMERIC,
                1
            ) AS completion_rate
        FROM public.trivias t
        LEFT JOIN public.trivia_attempts ta ON ta.trivia_id = t.id AND ta.started_at >= v_start AND ta.started_at <= v_end
        GROUP BY t.id, t.title
    ) sub;

    -- Hardest questions (lowest correct rate evaluated against trivia_options.is_correct)
    SELECT jsonb_agg(
        jsonb_build_object(
            'question_id', question_id,
            'trivia_title', trivia_title,
            'question_text', question_text,
            'total_answers', total_answers,
            'correct_rate', correct_rate
        ) ORDER BY correct_rate ASC
    ) INTO v_hardest_questions
    FROM (
        SELECT
            q.id AS question_id,
            t.title AS trivia_title,
            q.question_text,
            COUNT(ta.id) AS total_answers,
            ROUND(
                (COUNT(CASE WHEN o.is_correct IS TRUE THEN 1 END)::NUMERIC / NULLIF(COUNT(ta.id), 0) * 100)::NUMERIC,
                1
            ) AS correct_rate
        FROM public.trivia_questions q
        JOIN public.trivias t ON t.id = q.trivia_id
        JOIN public.trivia_attempts ta ON ta.trivia_id = t.id AND ta.submitted_at IS NOT NULL
        LEFT JOIN public.trivia_options o 
          ON o.id = (ta.answers->>(q.id::text))::uuid 
         AND o.question_id = q.id
        WHERE ta.started_at >= v_start AND ta.started_at <= v_end
        GROUP BY q.id, t.title, q.question_text
        HAVING COUNT(ta.id) > 0
        ORDER BY correct_rate ASC
        LIMIT 5
    ) sub;

    RETURN jsonb_build_object(
        'popular_trivias', COALESCE(v_popular, '[]'::jsonb),
        'hardest_questions', COALESCE(v_hardest_questions, '[]'::jsonb)
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.analytics_trivias(TIMESTAMPTZ, TIMESTAMPTZ) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.analytics_trivias(TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated, service_role;


-- 3. Rewrite analytics_active_users (Continuous series grouping by period in Caracas Timezone)
CREATE OR REPLACE FUNCTION public.analytics_active_users(
    p_start_date TIMESTAMPTZ DEFAULT NULL,
    p_end_date TIMESTAMPTZ DEFAULT NULL,
    p_granularity TEXT DEFAULT 'day'
)
RETURNS JSONB AS $$
DECLARE
    v_start TIMESTAMPTZ := COALESCE(p_start_date, NOW() - INTERVAL '30 days');
    v_end TIMESTAMPTZ := COALESCE(p_end_date, NOW());
    v_gran TEXT := CASE WHEN p_granularity = 'month' THEN 'month' WHEN p_granularity = 'week' THEN 'week' ELSE 'day' END;
    v_step INTERVAL := CASE WHEN p_granularity = 'month' THEN '1 month' WHEN p_granularity = 'week' THEN '1 week' ELSE '1 day' END;
    v_result JSONB;
BEGIN
    PERFORM public.assert_admin();

    SELECT jsonb_agg(
        jsonb_build_object(
            'period', p.period_date,
            'active_users', COALESCE(a.active_users, 0),
            'new_registrations', COALESCE(r.new_registrations, 0)
        ) ORDER BY p.period_date
    ) INTO v_result
    FROM (
        SELECT generate_series(
            date_trunc(v_gran, (v_start AT TIME ZONE 'America/Caracas')),
            date_trunc(v_gran, (v_end AT TIME ZONE 'America/Caracas')),
            v_step
        )::date AS period_date
    ) p
    LEFT JOIN (
        SELECT
            date_trunc(v_gran, activity_date)::date AS period_date,
            COUNT(DISTINCT fan_id) AS active_users
        FROM public.mv_daily_fan_activity
        WHERE activity_date >= (v_start AT TIME ZONE 'America/Caracas')::date 
          AND activity_date <= (v_end AT TIME ZONE 'America/Caracas')::date
        GROUP BY 1
    ) a ON a.period_date = p.period_date
    LEFT JOIN (
        SELECT
            date_trunc(v_gran, (created_at AT TIME ZONE 'America/Caracas'))::date AS period_date,
            COUNT(*) AS new_registrations
        FROM public.profiles
        WHERE created_at >= v_start AND created_at <= v_end
        GROUP BY 1
    ) r ON r.period_date = p.period_date;

    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.analytics_active_users(TIMESTAMPTZ, TIMESTAMPTZ, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.analytics_active_users(TIMESTAMPTZ, TIMESTAMPTZ, TEXT) TO authenticated, service_role;


-- 4. Rewrite analytics_funnel (Uniform cohort based on registration date)
CREATE OR REPLACE FUNCTION public.analytics_funnel(
    p_start_date TIMESTAMPTZ DEFAULT NULL,
    p_end_date TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_start TIMESTAMPTZ := COALESCE(p_start_date, NOW() - INTERVAL '30 days');
    v_end TIMESTAMPTZ := COALESCE(p_end_date, NOW());
    v_total_registered INT := 0;
    v_email_verified INT := 0;
    v_first_trivia INT := 0;
    v_first_redemption INT := 0;
BEGIN
    PERFORM public.assert_admin();

    -- Step 1: Registered in cohort (registered between v_start and v_end)
    SELECT COUNT(*) INTO v_total_registered
    FROM public.profiles
    WHERE created_at >= v_start AND created_at <= v_end;

    -- Step 2: Email Verified in cohort
    SELECT COUNT(p.id) INTO v_email_verified
    FROM public.profiles p
    JOIN auth.users u ON u.id = p.id
    WHERE p.created_at >= v_start AND p.created_at <= v_end
      AND (u.email_confirmed_at IS NOT NULL OR u.confirmed_at IS NOT NULL);

    -- Step 3: Played at least 1 Trivia in cohort
    SELECT COUNT(DISTINCT p.id) INTO v_first_trivia
    FROM public.profiles p
    JOIN public.trivia_attempts ta ON ta.fan_id = p.id AND ta.submitted_at IS NOT NULL
    WHERE p.created_at >= v_start AND p.created_at <= v_end;

    -- Step 4: Performed at least 1 Redemption in cohort
    SELECT COUNT(DISTINCT p.id) INTO v_first_redemption
    FROM public.profiles p
    JOIN public.redemptions r ON r.fan_id = p.id
    WHERE p.created_at >= v_start AND p.created_at <= v_end;

    RETURN jsonb_build_array(
        jsonb_build_object('step', 1, 'name', 'Registrados', 'count', v_total_registered, 'conversion_rate', 100.0),
        jsonb_build_object(
            'step', 2, 'name', 'Correo Verificado', 'count', v_email_verified,
            'conversion_rate', ROUND((v_email_verified::NUMERIC / NULLIF(v_total_registered, 0) * 100.0), 1)
        ),
        jsonb_build_object(
            'step', 3, 'name', 'Primera Trivia Jugada', 'count', v_first_trivia,
            'conversion_rate', ROUND((v_first_trivia::NUMERIC / NULLIF(v_total_registered, 0) * 100.0), 1)
        ),
        jsonb_build_object(
            'step', 4, 'name', 'Primer Canje Realizado', 'count', v_first_redemption,
            'conversion_rate', ROUND((v_first_redemption::NUMERIC / NULLIF(v_total_registered, 0) * 100.0), 1)
        )
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.analytics_funnel(TIMESTAMPTZ, TIMESTAMPTZ) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.analytics_funnel(TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated, service_role;


-- 5. Harden refresh_analytics_materialized_views and schedule in pg_cron
CREATE OR REPLACE FUNCTION public.refresh_analytics_materialized_views()
RETURNS VOID AS $$
BEGIN
    -- Assert admin if called by an authenticated user; allow service_role / pg_cron (auth.uid() IS NULL)
    IF auth.uid() IS NOT NULL THEN
        PERFORM public.assert_admin();
    END IF;

    REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_daily_fan_activity;
    REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_daily_economy_stats;
    REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_demographics;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.refresh_analytics_materialized_views() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.refresh_analytics_materialized_views() TO authenticated, service_role;

-- Schedule hourly refresh in pg_cron if enabled
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.schedule(
      'refresh_analytics_materialized_views_hourly',
      '0 * * * *',
      'SELECT public.refresh_analytics_materialized_views()'
    );
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'pg_cron not enabled or accessible in current environment';
END $$;
