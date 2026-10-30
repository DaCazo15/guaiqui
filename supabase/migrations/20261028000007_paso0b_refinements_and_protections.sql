-- ============================================================================
-- Migration: 20261028000007_paso0b_refinements_and_protections.sql
-- Description: Paso 0b Refinements:
--              1. assert_min_admins: >= 1 active platform admin AND >= 1 active admin per active team.
--              2. risk_flags: add team_id column; scope admin_risk_queue & admin_resolve_risk_flag.
--              3. Temporary multi-team guard on fan/analytics queries for club admins.
--              4. Classify & correct admin_publish_policy, reconcile_wallets,
--                 seed_analytics_performance_data, get_redemption_qr,
--                 ensure_profile, register_email_send_attempt, purge_auth_identities.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Invariante assert_min_admins (1 platform admin + 1 admin per active team)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.assert_min_admins()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_platform_admin_count INT;
    v_orphan_team_name TEXT;
BEGIN
    -- 1. Al menos 1 administrador de plataforma activo
    SELECT COUNT(*) INTO v_platform_admin_count
    FROM public.staff_members
    WHERE role = 'admin' AND active = true AND team_id IS NULL;

    IF v_platform_admin_count < 1 THEN
        RAISE EXCEPTION 'Operación denegada: debe existir siempre al menos 1 administrador de plataforma activo.' USING ERRCODE = '23514';
    END IF;

    -- 2. Al menos 1 administrador activo por cada equipo activo
    SELECT t.name INTO v_orphan_team_name
    FROM public.teams t
    WHERE t.status = 'active'
      AND NOT EXISTS (
          SELECT 1 FROM public.staff_members s
          WHERE s.team_id = t.id AND s.role = 'admin' AND s.active = true
      )
    LIMIT 1;

    IF v_orphan_team_name IS NOT NULL THEN
        RAISE EXCEPTION 'Operación denegada: el equipo activo "%" debe contar con al menos 1 administrador de equipo activo.', v_orphan_team_name USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$function$;

-- ----------------------------------------------------------------------------
-- 2. risk_flags: add team_id and scope queue/resolution
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'risk_flags' AND column_name = 'team_id'
    ) THEN
        ALTER TABLE public.risk_flags 
        ADD COLUMN team_id UUID REFERENCES public.teams(id) ON DELETE SET NULL;

        CREATE INDEX IF NOT EXISTS idx_risk_flags_team_id ON public.risk_flags(team_id);
    END IF;
END$$;

-- Scoped admin_risk_queue
CREATE OR REPLACE FUNCTION public.admin_risk_queue(p_resolved BOOLEAN DEFAULT false)
RETURNS JSONB
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_is_platform_admin BOOLEAN := public.is_platform_admin(v_caller_id);
    v_staff_team_id UUID := public.current_staff_team_id();
    v_res JSONB;
BEGIN
    PERFORM public.assert_admin();

    IF NOT v_is_platform_admin AND v_staff_team_id IS NULL THEN
        RAISE EXCEPTION 'Club admin must belong to an active team.' USING ERRCODE = '42501';
    END IF;

    SELECT jsonb_agg(
        jsonb_build_object(
            'flag_id', rf.id,
            'fan_id', rf.fan_id,
            'team_id', rf.team_id,
            'display_name', p.display_name,
            'reason', rf.reason,
            'severity', rf.severity,
            'resolved', rf.resolved,
            'created_at', rf.created_at,
            'held_pearls', (
                SELECT COALESCE(SUM(le.amount), 0)
                FROM public.ledger_entries le
                WHERE le.fan_id = rf.fan_id
                  AND le.status = 'held'
                  AND NOT EXISTS (
                      SELECT 1 FROM public.ledger_hold_resolutions lhr
                      WHERE lhr.ledger_id = le.id
                  )
            )
        ) ORDER BY rf.created_at DESC
    ) INTO v_res
    FROM public.risk_flags rf
    JOIN public.profiles p ON p.id = rf.fan_id
    WHERE rf.resolved = p_resolved
      AND (v_is_platform_admin OR rf.team_id = v_staff_team_id);

    RETURN COALESCE(v_res, '[]'::jsonb);
END;
$function$;

-- Scoped admin_resolve_risk_flag
CREATE OR REPLACE FUNCTION public.admin_resolve_risk_flag(p_flag_id UUID, p_note TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_is_platform_admin BOOLEAN := public.is_platform_admin(v_admin_id);
    v_staff_team_id UUID := public.current_staff_team_id();
    v_flag public.risk_flags%ROWTYPE;
BEGIN
    PERFORM public.assert_admin();

    IF p_note IS NULL OR trim(p_note) = '' THEN
        RAISE EXCEPTION 'La justificación es obligatoria para resolver una alerta de riesgo.';
    END IF;

    SELECT * INTO v_flag FROM public.risk_flags WHERE id = p_flag_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Alerta de riesgo no encontrada.';
    END IF;

    IF NOT v_is_platform_admin THEN
        IF v_staff_team_id IS NULL OR v_flag.team_id IS NULL OR v_flag.team_id != v_staff_team_id THEN
            RAISE EXCEPTION 'No tienes autorización para resolver alertas de riesgo de otro equipo o de plataforma.' USING ERRCODE = '42501';
        END IF;
    END IF;

    UPDATE public.risk_flags
    SET resolved = true
    WHERE id = p_flag_id;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'resolve_risk_flag', 'risk_flags', p_flag_id::text,
        jsonb_build_object('note', p_note, 'team_id', v_flag.team_id)
    );

    RETURN jsonb_build_object('status', 'resolved', 'flag_id', p_flag_id);
END;
$function$;

-- ----------------------------------------------------------------------------
-- 3. Protección temporal multi-equipo en fans y analítica
-- ----------------------------------------------------------------------------

-- 3.1 admin_list_fans (Guarded if multiple active teams until Step 2)
CREATE OR REPLACE FUNCTION public.admin_list_fans(
    p_municipality TEXT DEFAULT NULL::TEXT,
    p_age_min INTEGER DEFAULT NULL::INTEGER,
    p_age_max INTEGER DEFAULT NULL::INTEGER,
    p_favorite_player_id UUID DEFAULT NULL::UUID,
    p_inactive_days INTEGER DEFAULT NULL::INTEGER,
    p_status public.user_status DEFAULT NULL::public.user_status,
    p_search TEXT DEFAULT NULL::TEXT,
    p_limit INTEGER DEFAULT 20,
    p_cursor UUID DEFAULT NULL::UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_is_platform_admin BOOLEAN := public.is_platform_admin(v_caller_id);
    v_res JSONB;
BEGIN
    PERFORM public.assert_admin();

    IF NOT v_is_platform_admin THEN
        IF (SELECT COUNT(*) FROM public.teams WHERE status = 'active') > 1 THEN
            RAISE EXCEPTION 'MULTI_TEAM_PENDING_STEP2: Esta función estará disponible para administradores de club una vez implementada la asignación por seguidores en el Paso 2.' USING ERRCODE = '42501';
        END IF;
    END IF;

    WITH filtered_fans AS (
        SELECT 
            p.id,
            p.display_name,
            p.municipality,
            p.birth_date,
            p.gender,
            p.favorite_player_id,
            p.shirt_size,
            p.status,
            p.created_at,
            w.balance_cache AS pearl_balance,
            COALESCE(
                (SELECT MAX(started_at) FROM public.trivia_attempts WHERE fan_id = p.id),
                p.created_at
            ) AS last_active
        FROM public.profiles p
        LEFT JOIN public.wallets w ON w.fan_id = p.id
        WHERE 
            (p_municipality IS NULL OR p.municipality = p_municipality)
            AND (p_favorite_player_id IS NULL OR p.favorite_player_id = p_favorite_player_id)
            AND (p_status IS NULL OR p.status = p_status)
            AND (
                p_search IS NULL OR p_search = '' 
                OR p.display_name ILIKE '%' || p_search || '%'
                OR p.id::text ILIKE '%' || p_search || '%'
            )
            AND (
                p_age_min IS NULL 
                OR p.birth_date <= (CURRENT_DATE - (p_age_min * INTERVAL '1 year'))
            )
            AND (
                p_age_max IS NULL 
                OR p.birth_date >= (CURRENT_DATE - ((p_age_max + 1) * INTERVAL '1 year'))
            )
            AND (p_cursor IS NULL OR p.id > p_cursor)
    )
    SELECT jsonb_build_object(
        'fans', COALESCE(jsonb_agg(to_jsonb(sub)), '[]'::jsonb),
        'next_cursor', (SELECT id FROM filtered_fans ORDER BY id ASC LIMIT 1 OFFSET LEAST(GREATEST(p_limit, 1), 100) - 1)
    ) INTO v_res
    FROM (
        SELECT * FROM filtered_fans
        WHERE (
            p_inactive_days IS NULL 
            OR last_active < (NOW() - (p_inactive_days * INTERVAL '1 day'))
        )
        ORDER BY id ASC
        LIMIT LEAST(GREATEST(p_limit, 1), 100)
    ) sub;

    RETURN v_res;
END;
$function$;

-- 3.2 admin_get_fan (Guarded if multiple active teams until Step 2)
CREATE OR REPLACE FUNCTION public.admin_get_fan(p_fan_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_is_platform_admin BOOLEAN := public.is_platform_admin(v_caller_id);
    v_staff_team_id UUID := public.current_staff_team_id();
    v_profile RECORD;
    v_balance INT := 0;
    v_trivias JSONB;
    v_redemptions JSONB;
BEGIN
    PERFORM public.assert_admin();

    IF NOT v_is_platform_admin THEN
        IF (SELECT COUNT(*) FROM public.teams WHERE status = 'active') > 1 THEN
            RAISE EXCEPTION 'MULTI_TEAM_PENDING_STEP2: Esta función estará disponible para administradores de club una vez implementada la asignación por seguidores en el Paso 2.' USING ERRCODE = '42501';
        END IF;
    END IF;

    SELECT p.*, pl.name AS favorite_player_name
    INTO v_profile
    FROM public.profiles p
    LEFT JOIN public.players pl ON pl.id = p.favorite_player_id
    WHERE p.id = p_fan_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Perfil de fanático no encontrado.';
    END IF;

    SELECT balance_cache INTO v_balance FROM public.wallets WHERE fan_id = p_fan_id;

    SELECT COALESCE(jsonb_agg(to_jsonb(ta)), '[]'::jsonb)
    INTO v_trivias
    FROM (
        SELECT ta.id, t.title AS trivia_title, ta.score, ta.pearls_awarded, ta.submitted_at
        FROM public.trivia_attempts ta
        JOIN public.trivias t ON t.id = ta.trivia_id
        WHERE ta.fan_id = p_fan_id AND ta.submitted_at IS NOT NULL
          AND (v_is_platform_admin OR t.team_id = v_staff_team_id)
        ORDER BY ta.submitted_at DESC
        LIMIT 10
    ) ta;

    SELECT COALESCE(jsonb_agg(to_jsonb(r)), '[]'::jsonb)
    INTO v_redemptions
    FROM (
        SELECT r.id, pr.name AS product_name, r.cost_pearls, r.status, r.created_at
        FROM public.redemptions r
        JOIN public.products pr ON pr.id = r.product_id
        WHERE r.fan_id = p_fan_id
          AND (v_is_platform_admin OR r.team_id = v_staff_team_id)
        ORDER BY r.created_at DESC
        LIMIT 10
    ) r;

    RETURN jsonb_build_object(
        'profile', to_jsonb(v_profile),
        'pearl_balance', COALESCE(v_balance, 0),
        'recent_trivias', v_trivias,
        'recent_redemptions', v_redemptions
    );
END;
$function$;

-- 3.3 analytics_demographics (Guarded if multiple active teams until Step 2)
CREATE OR REPLACE FUNCTION public.analytics_demographics()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_is_platform_admin BOOLEAN := public.is_platform_admin(v_caller_id);
    v_municipality JSONB;
    v_gender JSONB;
    v_age_groups JSONB;
BEGIN
    PERFORM public.assert_admin();

    IF NOT v_is_platform_admin THEN
        IF (SELECT COUNT(*) FROM public.teams WHERE status = 'active') > 1 THEN
            RAISE EXCEPTION 'MULTI_TEAM_PENDING_STEP2: Esta función estará disponible para administradores de club una vez implementada la asignación por seguidores en el Paso 2.' USING ERRCODE = '42501';
        END IF;
    END IF;

    SELECT jsonb_agg(
        jsonb_build_object(
            'name', group_name,
            'count', group_count
        ) ORDER BY group_count DESC
    ) INTO v_municipality
    FROM (
        SELECT 
            CASE WHEN count >= 5 THEN municipality ELSE 'Otros / Grupos Pequeños' END AS group_name,
            SUM(count) AS group_count
        FROM public.mv_demographics
        WHERE demographic_type = 'municipality'
        GROUP BY 1
    ) sub;

    SELECT jsonb_agg(
        jsonb_build_object(
            'name', category,
            'count', count
        ) ORDER BY count DESC
    ) INTO v_gender
    FROM public.mv_demographics
    WHERE demographic_type = 'gender';

    SELECT jsonb_agg(
        jsonb_build_object(
            'range', category,
            'count', count
        ) ORDER BY category ASC
    ) INTO v_age_groups
    FROM public.mv_demographics
    WHERE demographic_type = 'age_group';

    RETURN jsonb_build_object(
        'municipality', COALESCE(v_municipality, '[]'::jsonb),
        'gender', COALESCE(v_gender, '[]'::jsonb),
        'age_groups', COALESCE(v_age_groups, '[]'::jsonb)
    );
END;
$function$;

-- 3.4 analytics_economy (Guarded if multiple active teams until Step 2)
CREATE OR REPLACE FUNCTION public.analytics_economy()
RETURNS JSONB
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_is_platform_admin BOOLEAN := public.is_platform_admin(v_caller_id);
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

    IF NOT v_is_platform_admin THEN
        IF (SELECT COUNT(*) FROM public.teams WHERE status = 'active') > 1 THEN
            RAISE EXCEPTION 'MULTI_TEAM_PENDING_STEP2: Esta función estará disponible para administradores de club una vez implementada la asignación por seguidores en el Paso 2.' USING ERRCODE = '42501';
        END IF;
    END IF;

    SELECT 
        COALESCE(total_issued, 0),
        COALESCE(total_spent, 0),
        COALESCE(total_in_circulation, 0)
    INTO v_total_issued, v_total_spent, v_total_in_circulation
    FROM public.mv_daily_economy_stats
    ORDER BY stat_date DESC LIMIT 1;

    SELECT COALESCE(SUM(amount), 0) INTO v_total_held
    FROM public.ledger_entries
    WHERE status = 'held';

    SELECT MIN(cost_pearls), MAX(cost_pearls)
    INTO v_min_product_cost, v_max_product_cost
    FROM public.products
    WHERE active = true;

    SELECT ROUND(AVG(daily_earned)::NUMERIC, 1)
    INTO v_avg_daily_earnings_per_fan
    FROM (
        SELECT fan_id, SUM(pearls_earned) / NULLIF(COUNT(DISTINCT activity_date), 0)::NUMERIC AS daily_earned
        FROM public.mv_daily_fan_activity
        WHERE activity_date >= (NOW() - INTERVAL '30 days')::date
        GROUP BY fan_id
    ) sub;

    IF v_avg_daily_earnings_per_fan > 0 THEN
        v_days_for_cheapest := ROUND((COALESCE(v_min_product_cost, 0) / v_avg_daily_earnings_per_fan)::NUMERIC, 1);
        v_days_for_most_expensive := ROUND((COALESCE(v_max_product_cost, 0) / v_avg_daily_earnings_per_fan)::NUMERIC, 1);
    ELSE
        v_days_for_cheapest := 0;
        v_days_for_most_expensive := 0;
    END IF;

    RETURN jsonb_build_object(
        'total_issued', COALESCE(v_total_issued, 0),
        'total_spent', COALESCE(v_total_spent, 0),
        'total_in_circulation', COALESCE(v_total_in_circulation, 0),
        'total_held', COALESCE(v_total_held, 0),
        'min_product_cost', COALESCE(v_min_product_cost, 0),
        'max_product_cost', COALESCE(v_max_product_cost, 0),
        'avg_daily_earnings_per_fan', COALESCE(v_avg_daily_earnings_per_fan, 0),
        'days_for_cheapest_product', COALESCE(v_days_for_cheapest, 0),
        'days_for_most_expensive_product', COALESCE(v_days_for_most_expensive, 0)
    );
END;
$function$;

-- 3.5 analytics_top_fans (Guarded if multiple active teams until Step 2)
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
        IF (SELECT COUNT(*) FROM public.teams WHERE status = 'active') > 1 THEN
            RAISE EXCEPTION 'MULTI_TEAM_PENDING_STEP2: Esta función estará disponible para administradores de club una vez implementada la asignación por seguidores en el Paso 2.' USING ERRCODE = '42501';
        END IF;
        IF v_staff_team_id IS NULL THEN
            RAISE EXCEPTION 'Club admin must belong to an active team.' USING ERRCODE = '42501';
        END IF;
        IF p_team_id IS NOT NULL AND p_team_id != v_staff_team_id THEN
            RAISE EXCEPTION 'No tienes autorización para consultar analítica de otro equipo.' USING ERRCODE = '42501';
        END IF;
        v_team_id := v_staff_team_id;
    END IF;

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
          AND (v_team_id IS NULL OR ta.team_id = v_team_id)
        GROUP BY p.id, p.display_name, p.avatar_url
        ORDER BY pearls_earned DESC
        LIMIT LEAST(GREATEST(p_limit, 1), 100)
    ) sub;

    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$function$;

-- ----------------------------------------------------------------------------
-- 4. Clasificación y Corrección de Funciones (Item E)
-- ----------------------------------------------------------------------------

-- 4.1 admin_publish_policy: Platform Admin Only
CREATE OR REPLACE FUNCTION public.admin_publish_policy(p_slug TEXT, p_version TEXT, p_content TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_new_id UUID;
BEGIN
    PERFORM public.assert_platform_admin();

    IF p_slug NOT IN ('terminos', 'privacidad', 'perlitas', 'canjes') THEN
        RAISE EXCEPTION 'Slug de política inválido: %', p_slug;
    END IF;

    IF p_version IS NULL OR trim(p_version) = '' THEN
        RAISE EXCEPTION 'La versión de la política es obligatoria.';
    END IF;

    IF p_content IS NULL OR trim(p_content) = '' THEN
        RAISE EXCEPTION 'El contenido de la política es obligatorio.';
    END IF;

    UPDATE public.legal_versions
    SET is_active = false
    WHERE policy_type = p_slug;

    INSERT INTO public.legal_versions (policy_type, version, content, published_by, is_active)
    VALUES (p_slug, trim(p_version), trim(p_content), v_admin_id, true)
    RETURNING id INTO v_new_id;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'publish_policy', 'legal_versions', v_new_id::text,
        jsonb_build_object('slug', p_slug, 'version', p_version)
    );

    RETURN jsonb_build_object('id', v_new_id, 'slug', p_slug, 'version', p_version, 'status', 'published');
END;
$function$;

-- 4.2 reconcile_wallets: Restringido provisionalmente a Platform Admin
CREATE OR REPLACE FUNCTION public.reconcile_wallets()
RETURNS TABLE(fan_id UUID, balance_cache INTEGER, computed_balance INTEGER, difference INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_actor_id UUID := auth.uid();
BEGIN
    IF v_actor_id IS NOT NULL THEN
        PERFORM public.assert_platform_admin();
    END IF;

    RETURN QUERY
    SELECT 
        w.fan_id,
        w.balance_cache,
        COALESCE(SUM(l.amount)::INT, 0) AS computed_balance,
        (w.balance_cache - COALESCE(SUM(l.amount)::INT, 0)) AS difference
    FROM public.wallets w
    LEFT JOIN public.ledger_entries l ON l.fan_id = w.fan_id AND l.status = 'confirmed'
    GROUP BY w.fan_id, w.balance_cache
    HAVING (w.balance_cache - COALESCE(SUM(l.amount)::INT, 0)) != 0;
END;
$function$;

-- 4.3 seed_analytics_performance_data: Deshabilitado por regla no-hardcoded-data
CREATE OR REPLACE FUNCTION public.seed_analytics_performance_data(p_num_fans INTEGER DEFAULT 1000, p_num_ledger INTEGER DEFAULT 5000)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    RAISE EXCEPTION 'Operación deshabilitada: Prohibido sembrar datos ficticios conforme a la regla de integridad (.agents/rules/no-hardcoded-data.md).' USING ERRCODE = '0A000';
END;
$function$;

-- 4.4 get_redemption_qr: Valida que pertenezca al fan
CREATE OR REPLACE FUNCTION public.get_redemption_qr(p_redemption_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_fan_id UUID := auth.uid();
    v_redemption public.redemptions%ROWTYPE;
    v_code TEXT;
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_redemption 
    FROM public.redemptions 
    WHERE id = p_redemption_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Redemption not found.';
    END IF;

    IF v_redemption.fan_id != v_fan_id AND NOT public.is_staff_or_admin_check() THEN
        RAISE EXCEPTION 'Unauthorized: Can only view your own redemptions.' USING ERRCODE = '42501';
    END IF;

    IF v_redemption.status NOT IN ('approved', 'scheduled') THEN
        RAISE EXCEPTION 'QR Code is not available for redemptions in status "%". QR is only available when approved or scheduled.', v_redemption.status;
    END IF;

    IF v_redemption.expires_at IS NOT NULL AND NOW() > v_redemption.expires_at THEN
        RAISE EXCEPTION 'Redemption has expired on %.', v_redemption.expires_at;
    END IF;

    v_code := public.generate_redemption_code(v_redemption.id);

    RETURN jsonb_build_object(
        'redemption_id', v_redemption.id,
        'team_id', v_redemption.team_id,
        'code', v_code,
        'redemption_code', v_code,
        'code_hash', v_redemption.code_hash,
        'status', v_redemption.status,
        'variant', v_redemption.variant,
        'cost_pearls', v_redemption.cost_pearls,
        'expires_at', v_redemption.expires_at
    );
END;
$function$;

-- 4.5 ensure_profile: Ya no crea wallet al registrarse (wallet se crea en follow_team)
CREATE OR REPLACE FUNCTION public.ensure_profile()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_is_staff BOOLEAN := false;
    v_current_status user_status;
    v_random_suffix TEXT;
    v_meta JSONB;
    v_display_name TEXT;
    v_avatar_url TEXT;
    v_municipality TEXT;
    v_birth_date DATE;
    v_gender TEXT;
    v_created BOOLEAN := false;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    -- Validar si ya existe
    SELECT status INTO v_current_status FROM public.profiles WHERE id = v_uid;
    IF FOUND THEN
        IF v_current_status = 'deleted' THEN
            RAISE EXCEPTION 'Esta cuenta ha sido eliminada previamente.' USING ERRCODE = '42501';
        ELSIF v_current_status = 'suspended' THEN
            RAISE EXCEPTION 'Esta cuenta se encuentra suspendida.' USING ERRCODE = '42501';
        END IF;

        RETURN jsonb_build_object('success', true, 'created', false, 'user_id', v_uid);
    END IF;

    SELECT (raw_user_meta_data) INTO v_meta FROM auth.users WHERE id = v_uid;
    v_display_name := TRIM(COALESCE(v_meta->>'display_name', v_meta->>'name', ''));
    
    IF v_display_name = '' THEN
        v_random_suffix := LPAD(FLOOR(random() * 10000)::TEXT, 4, '0');
        v_display_name := 'Fanático ' || v_random_suffix;
    END IF;

    v_avatar_url := NULLIF(TRIM(COALESCE(v_meta->>'avatar_url', v_meta->>'picture', '')), '');
    v_municipality := NULLIF(TRIM(COALESCE(v_meta->>'municipality', '')), '');
    v_gender := NULLIF(TRIM(COALESCE(v_meta->>'gender', '')), '');

    BEGIN
        v_birth_date := (v_meta->>'birth_date')::DATE;
    EXCEPTION WHEN OTHERS THEN
        v_birth_date := NULL;
    END;

    INSERT INTO public.profiles (
        id, display_name, avatar_url, municipality, birth_date, gender, status, created_at, updated_at
    ) VALUES (
        v_uid, v_display_name, v_avatar_url, v_municipality, v_birth_date, v_gender, 'active', NOW(), NOW()
    ) ON CONFLICT (id) DO NOTHING;

    -- NOTA FASE 2: La creación del wallet ya no ocurre aquí.
    -- El wallet se crea automáticamente al seguir al equipo (follow_team).

    RETURN jsonb_build_object('success', true, 'created', true, 'user_id', v_uid);
END;
$$;

-- 4.6 register_email_send_attempt: Revoke from authenticated/anon, grant service_role
REVOKE ALL ON FUNCTION public.register_email_send_attempt() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.register_email_send_attempt() TO service_role;

-- 4.7 purge_auth_identities: Platform Admin Only
CREATE OR REPLACE FUNCTION public.purge_auth_identities(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
    v_deleted_count INT := 0;
BEGIN
    PERFORM public.assert_platform_admin();

    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'User ID is required.';
    END IF;

    DELETE FROM auth.identities WHERE user_id = p_user_id;
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

    RETURN jsonb_build_object(
        'success', true,
        'purged_user_id', p_user_id,
        'identities_deleted', v_deleted_count
    );
END;
$function$;

-- ----------------------------------------------------------------------------
-- 5. Permisos y Revocaciones
-- ----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.admin_risk_queue(BOOLEAN) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_risk_queue(BOOLEAN) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_resolve_risk_flag(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_resolve_risk_flag(UUID, TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_list_fans(TEXT, INTEGER, INTEGER, UUID, INTEGER, public.user_status, TEXT, INTEGER, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_fans(TEXT, INTEGER, INTEGER, UUID, INTEGER, public.user_status, TEXT, INTEGER, UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_get_fan(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_get_fan(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.analytics_demographics() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.analytics_demographics() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.analytics_economy() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.analytics_economy() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_publish_policy(TEXT, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_publish_policy(TEXT, TEXT, TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.reconcile_wallets() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reconcile_wallets() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.seed_analytics_performance_data(INTEGER, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.seed_analytics_performance_data(INTEGER, INTEGER) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.get_redemption_qr(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_redemption_qr(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.ensure_profile() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ensure_profile() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.purge_auth_identities(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.purge_auth_identities(UUID) TO authenticated, service_role;

-- Security corrections for sensitive backend functions
REVOKE ALL ON FUNCTION public.create_notification(UUID, notification_type, TEXT, TEXT, JSONB, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_notification(UUID, notification_type, TEXT, TEXT, JSONB, TEXT) TO service_role;

REVOKE ALL ON FUNCTION public.enqueue_birthday_notifications(TIMESTAMPTZ) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.enqueue_birthday_notifications(TIMESTAMPTZ) TO service_role;
