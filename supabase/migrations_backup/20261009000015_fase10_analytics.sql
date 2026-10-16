-- Migration: 20261009000015_fase10_analytics.sql
-- Description: Analytics Dashboard Materialized Views, RPC Functions, Privacy Safeguards and Performance Benchmarking (Fase 10)

-- ==========================================
-- 1. MATERIALIZED VIEWS & INDEXES
-- ==========================================

-- A. Materialized View for Daily Fan Activity
CREATE MATERIALIZED VIEW IF NOT EXISTS public.mv_daily_fan_activity AS
SELECT
    (ta.started_at AT TIME ZONE 'America/Caracas')::DATE AS activity_date,
    ta.fan_id,
    COUNT(DISTINCT ta.id) AS trivias_count,
    COALESCE(SUM(ta.pearls_awarded), 0) AS pearls_earned
FROM public.trivia_attempts ta
WHERE ta.submitted_at IS NOT NULL
GROUP BY 1, 2;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_daily_fan_activity_pk ON public.mv_daily_fan_activity (activity_date, fan_id);
CREATE INDEX IF NOT EXISTS idx_mv_daily_fan_activity_date ON public.mv_daily_fan_activity (activity_date);

-- B. Materialized View for Daily Economy Stats
CREATE MATERIALIZED VIEW IF NOT EXISTS public.mv_daily_economy_stats AS
SELECT
    (le.created_at AT TIME ZONE 'America/Caracas')::DATE AS entry_date,
    COALESCE(SUM(CASE WHEN le.status = 'confirmed' AND le.amount > 0 THEN le.amount ELSE 0 END), 0) AS pearls_issued,
    COALESCE(SUM(CASE WHEN le.status = 'confirmed' AND le.amount < 0 THEN ABS(le.amount) ELSE 0 END), 0) AS pearls_spent,
    COALESCE(SUM(CASE WHEN le.status = 'held' THEN le.amount ELSE 0 END), 0) AS pearls_held
FROM public.ledger_entries le
GROUP BY 1;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_daily_economy_stats_pk ON public.mv_daily_economy_stats (entry_date);

-- C. Materialized View for Demographics (k-anonymity preparation)
CREATE MATERIALIZED VIEW IF NOT EXISTS public.mv_demographics AS
SELECT
    COALESCE(NULLIF(TRIM(p.municipality), ''), 'Sin especificar') AS municipality,
    COALESCE(NULLIF(TRIM(p.gender), ''), 'Sin especificar') AS gender,
    CASE
        WHEN p.birth_date IS NULL THEN 'Sin especificar'
        WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, p.birth_date)) BETWEEN 18 AND 24 THEN '18-24'
        WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, p.birth_date)) BETWEEN 25 AND 34 THEN '25-34'
        WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, p.birth_date)) BETWEEN 35 AND 44 THEN '35-44'
        WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, p.birth_date)) >= 45 THEN '45+'
        ELSE 'Menor de 18'
    END AS age_group,
    COUNT(p.id) AS fan_count
FROM public.profiles p
WHERE p.status = 'active'
GROUP BY 1, 2, 3;

CREATE INDEX IF NOT EXISTS idx_mv_demographics_muni ON public.mv_demographics (municipality);

-- REVOKE direct access from PUBLIC, anon, and authenticated for security
REVOKE ALL ON public.mv_daily_fan_activity FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.mv_daily_economy_stats FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.mv_demographics FROM PUBLIC, anon, authenticated;

-- Refresh RPC Function for pg_cron / Admin trigger
CREATE OR REPLACE FUNCTION public.refresh_analytics_materialized_views()
RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_daily_fan_activity;
    REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_daily_economy_stats;
    REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_demographics;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.refresh_analytics_materialized_views() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.refresh_analytics_materialized_views() TO authenticated, service_role;


-- ==========================================
-- 2. ANALYTICS RPC FUNCTIONS (10 RPCs)
-- ==========================================

-- 1. analytics_overview
CREATE OR REPLACE FUNCTION public.analytics_overview(
    p_start_date TIMESTAMPTZ DEFAULT NULL,
    p_end_date TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_start TIMESTAMPTZ := COALESCE(p_start_date, NOW() - INTERVAL '30 days');
    v_end TIMESTAMPTZ := COALESCE(p_end_date, NOW());
    v_dau INT;
    v_wau INT;
    v_mau INT;
    v_new_registrations INT;
    v_pearls_issued BIGINT;
    v_pearls_spent BIGINT;
    v_redemptions_by_status JSONB;
    v_avg_fulfillment_hours NUMERIC;
BEGIN
    PERFORM public.assert_admin();

    -- DAU (Today in Caracas)
    SELECT COUNT(DISTINCT fan_id) INTO v_dau
    FROM public.mv_daily_fan_activity
    WHERE activity_date = (NOW() AT TIME ZONE 'America/Caracas')::DATE;

    -- WAU (Last 7 days)
    SELECT COUNT(DISTINCT fan_id) INTO v_wau
    FROM public.mv_daily_fan_activity
    WHERE activity_date >= ((NOW() AT TIME ZONE 'America/Caracas')::DATE - INTERVAL '7 days')::DATE;

    -- MAU (Last 30 days)
    SELECT COUNT(DISTINCT fan_id) INTO v_mau
    FROM public.mv_daily_fan_activity
    WHERE activity_date >= ((NOW() AT TIME ZONE 'America/Caracas')::DATE - INTERVAL '30 days')::DATE;

    -- New registrations in date range
    SELECT COUNT(*) INTO v_new_registrations
    FROM public.profiles
    WHERE created_at >= v_start AND created_at <= v_end;

    -- Pearls issued vs spent
    SELECT
        COALESCE(SUM(CASE WHEN amount > 0 AND status = 'confirmed' THEN amount ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN amount < 0 AND status = 'confirmed' THEN ABS(amount) ELSE 0 END), 0)
    INTO v_pearls_issued, v_pearls_spent
    FROM public.ledger_entries
    WHERE created_at >= v_start AND created_at <= v_end;

    -- Redemptions breakdown by status
    SELECT jsonb_object_agg(COALESCE(status::text, 'unknown'), cnt)
    INTO v_redemptions_by_status
    FROM (
        SELECT status, COUNT(*) AS cnt
        FROM public.redemptions
        WHERE created_at >= v_start AND created_at <= v_end
        GROUP BY status
    ) sub;

    -- Average fulfillment time (Approved to Delivered in hours)
    SELECT ROUND(AVG(EXTRACT(EPOCH FROM (delivered_at - approved_at)) / 3600.0)::NUMERIC, 2)
    INTO v_avg_fulfillment_hours
    FROM public.redemptions
    WHERE delivered_at IS NOT NULL AND approved_at IS NOT NULL
      AND created_at >= v_start AND created_at <= v_end;

    RETURN jsonb_build_object(
        'dau', COALESCE(v_dau, 0),
        'wau', COALESCE(v_wau, 0),
        'mau', COALESCE(v_mau, 0),
        'new_registrations', v_new_registrations,
        'pearls_issued', v_pearls_issued,
        'pearls_spent', v_pearls_spent,
        'redemptions_by_status', COALESCE(v_redemptions_by_status, '{}'::jsonb),
        'avg_fulfillment_hours', COALESCE(v_avg_fulfillment_hours, 0)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 2. analytics_active_users
CREATE OR REPLACE FUNCTION public.analytics_active_users(
    p_start_date TIMESTAMPTZ DEFAULT NULL,
    p_end_date TIMESTAMPTZ DEFAULT NULL,
    p_granularity TEXT DEFAULT 'day'
)
RETURNS JSONB AS $$
DECLARE
    v_start TIMESTAMPTZ := COALESCE(p_start_date, NOW() - INTERVAL '30 days');
    v_end TIMESTAMPTZ := COALESCE(p_end_date, NOW());
    v_result JSONB;
BEGIN
    PERFORM public.assert_admin();

    SELECT jsonb_agg(
        jsonb_build_object(
            'period', period_date,
            'active_users', active_users,
            'new_registrations', new_registrations
        ) ORDER BY period_date
    ) INTO v_result
    FROM (
        SELECT
            DATE_TRUNC(
                CASE WHEN p_granularity = 'month' THEN 'month' WHEN p_granularity = 'week' THEN 'week' ELSE 'day' END,
                (ta.started_at AT TIME ZONE 'America/Caracas')
            )::DATE AS period_date,
            COUNT(DISTINCT ta.fan_id) AS active_users,
            (
                SELECT COUNT(*)
                FROM public.profiles p
                WHERE DATE_TRUNC(
                    CASE WHEN p_granularity = 'month' THEN 'month' WHEN p_granularity = 'week' THEN 'week' ELSE 'day' END,
                    (p.created_at AT TIME ZONE 'America/Caracas')
                )::DATE = DATE_TRUNC(
                    CASE WHEN p_granularity = 'month' THEN 'month' WHEN p_granularity = 'week' THEN 'week' ELSE 'day' END,
                    (ta.started_at AT TIME ZONE 'America/Caracas')
                )::DATE
            ) AS new_registrations
        FROM public.trivia_attempts ta
        WHERE ta.started_at >= v_start AND ta.started_at <= v_end
        GROUP BY 1
    ) sub;

    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 3. analytics_top_fans (Strict Privacy: NO Email or contact details)
CREATE OR REPLACE FUNCTION public.analytics_top_fans(
    p_limit INT DEFAULT 10,
    p_start_date TIMESTAMPTZ DEFAULT NULL,
    p_end_date TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_start TIMESTAMPTZ := COALESCE(p_start_date, NOW() - INTERVAL '30 days');
    v_end TIMESTAMPTZ := COALESCE(p_end_date, NOW());
    v_result JSONB;
BEGIN
    PERFORM public.assert_admin();

    SELECT jsonb_agg(
        jsonb_build_object(
            'fan_id', fan_id,
            'display_name', display_name,
            'avatar_url', avatar_url,
            'trivias_played', trivias_played,
            'pearls_earned', pearls_earned
        ) ORDER BY pearls_earned DESC
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
          AND ta.started_at >= v_start AND ta.started_at <= v_end
          AND p.status = 'active'
        GROUP BY p.id, p.display_name, p.avatar_url
        ORDER BY pearls_earned DESC
        LIMIT LEAST(GREATEST(p_limit, 1), 100)
    ) sub;

    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 4. analytics_trivias
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

    -- Hardest questions (lowest correct rate)
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
                (COUNT(CASE WHEN (ta.answers->>(q.id::text)) IS NOT NULL THEN 1 END)::NUMERIC / NULLIF(COUNT(ta.id), 0) * 100)::NUMERIC,
                1
            ) AS correct_rate
        FROM public.trivia_questions q
        JOIN public.trivias t ON t.id = q.trivia_id
        LEFT JOIN public.trivia_attempts ta ON ta.trivia_id = t.id AND ta.submitted_at IS NOT NULL
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 5. analytics_products
CREATE OR REPLACE FUNCTION public.analytics_products(
    p_start_date TIMESTAMPTZ DEFAULT NULL,
    p_end_date TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_start TIMESTAMPTZ := COALESCE(p_start_date, NOW() - INTERVAL '30 days');
    v_end TIMESTAMPTZ := COALESCE(p_end_date, NOW());
    v_top_products JSONB;
    v_low_stock JSONB;
BEGIN
    PERFORM public.assert_admin();

    -- Top redeemed products
    SELECT jsonb_agg(
        jsonb_build_object(
            'product_id', product_id,
            'name', name,
            'cost_pearls', cost_pearls,
            'redemptions_count', redemptions_count,
            'total_pearls_spent', total_pearls_spent
        ) ORDER BY redemptions_count DESC
    ) INTO v_top_products
    FROM (
        SELECT
            p.id AS product_id,
            p.name,
            p.cost_pearls,
            COUNT(r.id) AS redemptions_count,
            COALESCE(SUM(r.cost_pearls), 0) AS total_pearls_spent
        FROM public.products p
        LEFT JOIN public.redemptions r ON r.product_id = p.id AND r.created_at >= v_start AND r.created_at <= v_end
        GROUP BY p.id, p.name, p.cost_pearls
    ) sub;

    -- Low stock alerts (stock <= 3)
    SELECT jsonb_agg(
        jsonb_build_object(
            'product_id', id,
            'name', name,
            'stock', stock,
            'active', active
        ) ORDER BY stock ASC
    ) INTO v_low_stock
    FROM public.products
    WHERE stock <= 3 AND active = true;

    RETURN jsonb_build_object(
        'top_products', COALESCE(v_top_products, '[]'::jsonb),
        'low_stock_alerts', COALESCE(v_low_stock, '[]'::jsonb)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 6. analytics_demographics (k-anonymity = 5 suppression)
CREATE OR REPLACE FUNCTION public.analytics_demographics()
RETURNS JSONB AS $$
DECLARE
    v_municipality JSONB;
    v_gender JSONB;
    v_age_groups JSONB;
BEGIN
    PERFORM public.assert_admin();

    -- Municipality (Groups with < 5 count merged into "Otros / Grupos Pequeños")
    SELECT jsonb_agg(
        jsonb_build_object(
            'name', group_name,
            'count', total_count
        ) ORDER BY total_count DESC
    ) INTO v_municipality
    FROM (
        SELECT
            CASE WHEN fan_count >= 5 THEN municipality ELSE 'Otros (< 5)' END AS group_name,
            SUM(fan_count) AS total_count
        FROM public.mv_demographics
        GROUP BY 1
    ) sub;

    -- Gender
    SELECT jsonb_agg(
        jsonb_build_object(
            'name', group_name,
            'count', total_count
        ) ORDER BY total_count DESC
    ) INTO v_gender
    FROM (
        SELECT
            CASE WHEN fan_count >= 5 THEN gender ELSE 'Otros (< 5)' END AS group_name,
            SUM(fan_count) AS total_count
        FROM public.mv_demographics
        GROUP BY 1
    ) sub;

    -- Age Groups
    SELECT jsonb_agg(
        jsonb_build_object(
            'name', group_name,
            'count', total_count
        ) ORDER BY total_count DESC
    ) INTO v_age_groups
    FROM (
        SELECT
            CASE WHEN fan_count >= 5 THEN age_group ELSE 'Otros (< 5)' END AS group_name,
            SUM(fan_count) AS total_count
        FROM public.mv_demographics
        GROUP BY 1
    ) sub;

    RETURN jsonb_build_object(
        'by_municipality', COALESCE(v_municipality, '[]'::jsonb),
        'by_gender', COALESCE(v_gender, '[]'::jsonb),
        'by_age_group', COALESCE(v_age_groups, '[]'::jsonb)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 7. analytics_engagement_hours
CREATE OR REPLACE FUNCTION public.analytics_engagement_hours(
    p_start_date TIMESTAMPTZ DEFAULT NULL,
    p_end_date TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_start TIMESTAMPTZ := COALESCE(p_start_date, NOW() - INTERVAL '30 days');
    v_end TIMESTAMPTZ := COALESCE(p_end_date, NOW());
    v_result JSONB;
BEGIN
    PERFORM public.assert_admin();

    -- Matrix 7 x 24: [day_of_week (0=Sun, 6=Sat), hour (0-23), count]
    SELECT jsonb_agg(
        jsonb_build_array(day_of_week, hour_of_day, activity_count)
    ) INTO v_result
    FROM (
        SELECT
            EXTRACT(DOW FROM (started_at AT TIME ZONE 'America/Caracas'))::INT AS day_of_week,
            EXTRACT(HOUR FROM (started_at AT TIME ZONE 'America/Caracas'))::INT AS hour_of_day,
            COUNT(*) AS activity_count
        FROM public.trivia_attempts
        WHERE started_at >= v_start AND started_at <= v_end
        GROUP BY 1, 2
        ORDER BY 1, 2
    ) sub;

    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 8. analytics_economy
CREATE OR REPLACE FUNCTION public.analytics_economy()
RETURNS JSONB AS $$
DECLARE
    v_total_issued BIGINT;
    v_total_spent BIGINT;
    v_total_in_circulation BIGINT;
    v_total_held BIGINT;
    v_min_product_cost INT;
    v_max_product_cost INT;
    v_avg_daily_earnings_per_fan NUMERIC;
    v_days_for_cheapest NUMERIC;
    v_days_for_most_expensive NUMERIC;
BEGIN
    PERFORM public.assert_admin();

    -- Issued & Spent from Ledger
    SELECT
        COALESCE(SUM(CASE WHEN amount > 0 AND status = 'confirmed' THEN amount ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN amount < 0 AND status = 'confirmed' THEN ABS(amount) ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN status = 'held' THEN amount ELSE 0 END), 0)
    INTO v_total_issued, v_total_spent, v_total_held
    FROM public.ledger_entries;

    -- In Circulation from Wallets Cache
    SELECT COALESCE(SUM(balance_cache), 0) INTO v_total_in_circulation
    FROM public.wallets;

    -- Product cost bounds
    SELECT MIN(cost_pearls), MAX(cost_pearls)
    INTO v_min_product_cost, v_max_product_cost
    FROM public.products
    WHERE active = true;

    -- Average daily earnings per active fan
    SELECT COALESCE(AVG(pearls_earned), 50.0)
    INTO v_avg_daily_earnings_per_fan
    FROM (
        SELECT fan_id, SUM(pearls_awarded) AS pearls_earned
        FROM public.trivia_attempts
        WHERE submitted_at >= NOW() - INTERVAL '30 days'
        GROUP BY fan_id
    ) sub;

    IF v_avg_daily_earnings_per_fan <= 0 THEN
        v_avg_daily_earnings_per_fan := 50.0;
    END IF;

    v_days_for_cheapest := ROUND((COALESCE(v_min_product_cost, 0)::NUMERIC / v_avg_daily_earnings_per_fan), 1);
    v_days_for_most_expensive := ROUND((COALESCE(v_max_product_cost, 0)::NUMERIC / v_avg_daily_earnings_per_fan), 1);

    RETURN jsonb_build_object(
        'total_issued', v_total_issued,
        'total_spent', v_total_spent,
        'total_in_circulation', v_total_in_circulation,
        'total_held', v_total_held,
        'cheapest_product_cost', COALESCE(v_min_product_cost, 0),
        'most_expensive_product_cost', COALESCE(v_max_product_cost, 0),
        'days_needed_for_cheapest', COALESCE(v_days_for_cheapest, 0),
        'days_needed_for_most_expensive', COALESCE(v_days_for_most_expensive, 0)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 9. analytics_funnel
CREATE OR REPLACE FUNCTION public.analytics_funnel(
    p_start_date TIMESTAMPTZ DEFAULT NULL,
    p_end_date TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_start TIMESTAMPTZ := COALESCE(p_start_date, NOW() - INTERVAL '30 days');
    v_end TIMESTAMPTZ := COALESCE(p_end_date, NOW());
    v_total_registered INT;
    v_email_verified INT;
    v_first_trivia INT;
    v_first_redemption INT;
BEGIN
    PERFORM public.assert_admin();

    -- Step 1: Registered
    SELECT COUNT(*) INTO v_total_registered
    FROM public.profiles
    WHERE created_at >= v_start AND created_at <= v_end;

    -- Step 2: Email Verified
    SELECT COUNT(p.id) INTO v_email_verified
    FROM public.profiles p
    JOIN auth.users u ON u.id = p.id
    WHERE p.created_at >= v_start AND p.created_at <= v_end
      AND (u.email_confirmed_at IS NOT NULL OR u.confirmed_at IS NOT NULL);

    -- Step 3: Played at least 1 Trivia
    SELECT COUNT(DISTINCT fan_id) INTO v_first_trivia
    FROM public.trivia_attempts
    WHERE started_at >= v_start AND started_at <= v_end
      AND submitted_at IS NOT NULL;

    -- Step 4: Performed at least 1 Redemption
    SELECT COUNT(DISTINCT fan_id) INTO v_first_redemption
    FROM public.redemptions
    WHERE created_at >= v_start AND created_at <= v_end;

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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 10. Performance Benchmarking Seed Generator
CREATE OR REPLACE FUNCTION public.seed_analytics_performance_data(
    p_num_fans INT DEFAULT 1000,
    p_num_ledger INT DEFAULT 5000
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_fan_ids UUID[];
    v_product_id UUID;
    v_trivia_id UUID;
BEGIN
    PERFORM public.assert_admin();

    -- Ensure a sample product and trivia exist
    SELECT id INTO v_product_id FROM public.products LIMIT 1;
    SELECT id INTO v_trivia_id FROM public.trivias LIMIT 1;

    -- Bulk generate synthetic profiles & wallets
    INSERT INTO public.profiles (id, display_name, municipality, gender, status, created_at)
    SELECT
        gen_random_uuid(),
        'PerfFan_' || i,
        (ARRAY['Mariño', 'Maneiro', 'Arismendi', 'García', 'Tubores'])[1 + (i % 5)],
        (ARRAY['Masculino', 'Femenino', 'Otro'])[1 + (i % 3)],
        'active',
        NOW() - (i || ' minutes')::INTERVAL
    FROM generate_series(1, LEAST(p_num_fans, 50000)) AS i
    ON CONFLICT (id) DO NOTHING;

    -- Collect inserted fan IDs
    SELECT ARRAY_AGG(id) INTO v_fan_ids FROM public.profiles WHERE display_name LIKE 'PerfFan_%';

    -- Bulk generate wallets
    INSERT INTO public.wallets (fan_id, balance_cache)
    SELECT unnest(v_fan_ids), 500
    ON CONFLICT (fan_id) DO NOTHING;

    -- Bulk generate ledger entries
    INSERT INTO public.ledger_entries (fan_id, amount, type, status, source_type, source_id, created_at)
    SELECT
        v_fan_ids[1 + (i % ARRAY_LENGTH(v_fan_ids, 1))],
        CASE WHEN i % 2 = 0 THEN 100 ELSE -50 END,
        CASE WHEN i % 2 = 0 THEN 'trivia_reward'::ledger_type ELSE 'redemption'::ledger_type END,
        'confirmed'::ledger_status,
        'benchmark_test',
        'bench_' || i,
        NOW() - (i || ' seconds')::INTERVAL
    FROM generate_series(1, LEAST(p_num_ledger, 500000)) AS i;

    -- Refresh Materialized Views
    PERFORM public.refresh_analytics_materialized_views();

    RETURN jsonb_build_object(
        'status', 'success',
        'fans_seeded', ARRAY_LENGTH(v_fan_ids, 1),
        'ledger_entries_seeded', p_num_ledger
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;


-- ==========================================
-- 3. PERMISSIONS & GRANTS
-- ==========================================
REVOKE ALL ON FUNCTION public.analytics_overview(TIMESTAMPTZ, TIMESTAMPTZ) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.analytics_overview(TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.analytics_active_users(TIMESTAMPTZ, TIMESTAMPTZ, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.analytics_active_users(TIMESTAMPTZ, TIMESTAMPTZ, TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.analytics_top_fans(INT, TIMESTAMPTZ, TIMESTAMPTZ) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.analytics_top_fans(INT, TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.analytics_trivias(TIMESTAMPTZ, TIMESTAMPTZ) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.analytics_trivias(TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.analytics_products(TIMESTAMPTZ, TIMESTAMPTZ) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.analytics_products(TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.analytics_demographics() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.analytics_demographics() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.analytics_engagement_hours(TIMESTAMPTZ, TIMESTAMPTZ) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.analytics_engagement_hours(TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.analytics_economy() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.analytics_economy() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.analytics_funnel(TIMESTAMPTZ, TIMESTAMPTZ) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.analytics_funnel(TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.seed_analytics_performance_data(INT, INT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.seed_analytics_performance_data(INT, INT) TO authenticated, service_role;
