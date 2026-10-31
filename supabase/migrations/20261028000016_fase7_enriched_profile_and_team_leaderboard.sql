-- ============================================================================
-- Migration: 20261028000016_fase7_enriched_profile_and_team_leaderboard.sql
-- Description: FASE 7 — Perfil enriquecido, insignias reales, vinculación de referente
--              y ranking multi-equipo con cálculo de posición personal (my_rank).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Tablas de Insignias y Logros Reales
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.badges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    icon_name TEXT NOT NULL DEFAULT 'bi-award-fill',
    category TEXT NOT NULL DEFAULT 'general' CHECK (category IN ('canjes', 'racha', 'trivias', 'fidelidad', 'comunidad', 'general')),
    tier TEXT NOT NULL DEFAULT 'bronce' CHECK (tier IN ('bronce', 'plata', 'oro', 'platino')),
    criteria_summary TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_badges_slug ON public.badges(slug);
CREATE INDEX IF NOT EXISTS idx_badges_category ON public.badges(category);

ALTER TABLE public.badges ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "badges_read_all" ON public.badges;
CREATE POLICY "badges_read_all" ON public.badges
    FOR SELECT TO anon, authenticated
    USING (true);

REVOKE ALL ON TABLE public.badges FROM PUBLIC;
GRANT SELECT ON TABLE public.badges TO anon, authenticated, service_role;

CREATE TABLE IF NOT EXISTS public.fan_badges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fan_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    badge_id UUID NOT NULL REFERENCES public.badges(id) ON DELETE CASCADE,
    team_id UUID NULL REFERENCES public.teams(id) ON DELETE SET NULL,
    awarded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_fan_badge UNIQUE (fan_id, badge_id)
);

CREATE INDEX IF NOT EXISTS idx_fan_badges_fan_id ON public.fan_badges(fan_id);
CREATE INDEX IF NOT EXISTS idx_fan_badges_badge_id ON public.fan_badges(badge_id);

ALTER TABLE public.fan_badges ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "fan_badges_read" ON public.fan_badges;
CREATE POLICY "fan_badges_read" ON public.fan_badges
    FOR SELECT TO anon, authenticated
    USING (true);

REVOKE ALL ON TABLE public.fan_badges FROM PUBLIC;
GRANT SELECT ON TABLE public.fan_badges TO anon, authenticated, service_role;

-- Semillero de Insignias Oficiales del Sistema (Logros Reales)
INSERT INTO public.badges (slug, name, description, icon_name, category, tier, criteria_summary)
VALUES
    ('fan_fiel', 'Corazón de la Tribu', 'Sigue a su equipo oficial de baloncesto en la plataforma.', 'bi-shield-fill-check', 'fidelidad', 'bronce', 'Sigue al menos a un equipo oficial'),
    ('primer_canje', 'Primer Canje', 'Realizó exitosamente su primer canje de producto en la tienda.', 'bi-bag-check-fill', 'canjes', 'bronce', 'Canjea tu primer premio en la tienda'),
    ('embajador', 'Embajador Insular', 'Invitó a amigos que se registraron con su código de referido.', 'bi-people-fill', 'comunidad', 'plata', 'Ten al menos 1 amigo referido registrado'),
    ('experto_trivia', 'Sabio del Tabloncillo', 'Acumuló más de 50 perlitas respondiendo trivias oficiales.', 'bi-mortarboard-fill', 'trivias', 'oro', 'Gana más de 50 perlitas en trivias'),
    ('racha_fuego', 'Racha Imparable', 'Mantuvo una racha de lealtad de al menos 7 días consecutivos.', 'bi-fire', 'racha', 'plata', 'Alcanza una racha de 7 días'),
    ('anuncios_vip', 'Apoyo Incondicional', 'Completó al menos 3 bloques de anuncios de marcas patrocinadoras.', 'bi-play-circle-fill', 'comunidad', 'bronce', 'Completa 3 bloques de videos patrocinados')
ON CONFLICT (slug) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    icon_name = EXCLUDED.icon_name,
    category = EXCLUDED.category,
    tier = EXCLUDED.tier,
    criteria_summary = EXCLUDED.criteria_summary;

-- ----------------------------------------------------------------------------
-- 2. Función Evaluadora de Insignias (Automática e Idempotente)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_and_award_fan_badges(p_fan_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_has_follow BOOLEAN;
    v_has_redemption BOOLEAN;
    v_has_referrals BOOLEAN;
    v_trivia_pearls INT := 0;
    v_streak_days INT := 0;
    v_ads_blocks INT := 0;
BEGIN
    IF p_fan_id IS NULL THEN
        RETURN;
    END IF;

    -- 1. Insignia: fan_fiel (sigue a un equipo)
    SELECT EXISTS (
        SELECT 1 FROM public.team_follows WHERE user_id = p_fan_id
    ) INTO v_has_follow;

    IF v_has_follow THEN
        INSERT INTO public.fan_badges (fan_id, badge_id)
        SELECT p_fan_id, b.id FROM public.badges b WHERE b.slug = 'fan_fiel'
        ON CONFLICT (fan_id, badge_id) DO NOTHING;
    END IF;

    -- 2. Insignia: primer_canje (tiene al menos 1 canje aprobado o entregado)
    SELECT EXISTS (
        SELECT 1 FROM public.redemptions
        WHERE fan_id = p_fan_id AND status IN ('approved', 'delivered', 'pending')
    ) INTO v_has_redemption;

    IF v_has_redemption THEN
        INSERT INTO public.fan_badges (fan_id, badge_id)
        SELECT p_fan_id, b.id FROM public.badges b WHERE b.slug = 'primer_canje'
        ON CONFLICT (fan_id, badge_id) DO NOTHING;
    END IF;

    -- 3. Insignia: embajador (tiene al menos 1 referido registrado)
    SELECT EXISTS (
        SELECT 1 FROM public.referrals WHERE referrer_id = p_fan_id
    ) INTO v_has_referrals;

    IF v_has_referrals THEN
        INSERT INTO public.fan_badges (fan_id, badge_id)
        SELECT p_fan_id, b.id FROM public.badges b WHERE b.slug = 'embajador'
        ON CONFLICT (fan_id, badge_id) DO NOTHING;
    END IF;

    -- 4. Insignia: experto_trivia (más de 50 perlitas ganadas en trivias)
    SELECT COALESCE(SUM(amount), 0) INTO v_trivia_pearls
    FROM public.ledger_entries
    WHERE fan_id = p_fan_id AND type = 'trivia_reward' AND status = 'confirmed';

    IF v_trivia_pearls >= 50 THEN
        INSERT INTO public.fan_badges (fan_id, badge_id)
        SELECT p_fan_id, b.id FROM public.badges b WHERE b.slug = 'experto_trivia'
        ON CONFLICT (fan_id, badge_id) DO NOTHING;
    END IF;

    -- 5. Insignia: racha_fuego (racha de al menos 7 días)
    SELECT COALESCE(current_streak, 0) INTO v_streak_days
    FROM public.fan_streaks
    WHERE fan_id = p_fan_id;

    IF v_streak_days >= 7 THEN
        INSERT INTO public.fan_badges (fan_id, badge_id)
        SELECT p_fan_id, b.id FROM public.badges b WHERE b.slug = 'racha_fuego'
        ON CONFLICT (fan_id, badge_id) DO NOTHING;
    END IF;

    -- 6. Insignia: anuncios_vip (al menos 3 bloques de anuncios)
    SELECT COUNT(*) INTO v_ads_blocks
    FROM public.pending_pearl_grants
    WHERE fan_id = p_fan_id AND source = 'ads_block';

    IF v_ads_blocks >= 3 THEN
        INSERT INTO public.fan_badges (fan_id, badge_id)
        SELECT p_fan_id, b.id FROM public.badges b WHERE b.slug = 'anuncios_vip'
        ON CONFLICT (fan_id, badge_id) DO NOTHING;
    END IF;
END;
$$;

-- ----------------------------------------------------------------------------
-- 3. RPC: public.claim_referral_code (Vincular referente en billetera/perfil)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.claim_referral_code(
    p_code TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_fan_id UUID := auth.uid();
    v_clean_code TEXT;
    v_referrer_id UUID;
    v_referrer_name TEXT;
    v_referral_id UUID;
    v_grant_id UUID;
    v_has_followed_teams BOOLEAN;
    v_notif_url TEXT;
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    -- Validar que el usuario no tenga ya un referente registrado
    IF EXISTS (SELECT 1 FROM public.referrals WHERE referred_id = v_fan_id) THEN
        RAISE EXCEPTION 'Ya tienes un referente vinculado a tu cuenta.' USING ERRCODE = '42501';
    END IF;

    v_clean_code := UPPER(trim(COALESCE(p_code, '')));
    IF v_clean_code = '' OR length(v_clean_code) < 4 THEN
        RAISE EXCEPTION 'Código de referido no válido.' USING ERRCODE = 'P0001';
    END IF;

    -- Buscar al dueño del código
    SELECT rc.user_id, COALESCE(p.display_name, 'Fanático')
    INTO v_referrer_id, v_referrer_name
    FROM public.referral_codes rc
    JOIN public.profiles p ON p.id = rc.user_id
    WHERE rc.code = v_clean_code;

    IF v_referrer_id IS NULL THEN
        RAISE EXCEPTION 'El código de referido no existe.' USING ERRCODE = 'P0002';
    END IF;

    -- Prohibir auto-referencia
    IF v_referrer_id = v_fan_id THEN
        RAISE EXCEPTION 'No puedes utilizar tu propio código de referido.' USING ERRCODE = 'P0003';
    END IF;

    -- Registrar la relación de referido
    INSERT INTO public.referrals (referrer_id, referred_id, status)
    VALUES (v_referrer_id, v_fan_id, 'registered')
    RETURNING id INTO v_referral_id;

    -- Generar concesión pendiente de 5 perlitas al referidor (expira en 90 días)
    INSERT INTO public.pending_pearl_grants (
        fan_id, source, amount, referral_id, status, expires_at
    ) VALUES (
        v_referrer_id, 'referral_signup', 5, v_referral_id, 'pending', NOW() + INTERVAL '90 days'
    )
    RETURNING id INTO v_grant_id;

    -- Notificar al referidor
    SELECT EXISTS (
        SELECT 1 FROM public.team_follows tf
        JOIN public.teams t ON t.id = tf.team_id AND t.status = 'active'
        WHERE tf.user_id = v_referrer_id
    ) INTO v_has_followed_teams;

    IF v_has_followed_teams THEN
        v_notif_url := '/app/perlitas-pendientes';
    ELSE
        v_notif_url := '/app/equipos';
    END IF;

    PERFORM public.create_notification(
        v_referrer_id,
        'pending_grant',
        'Tienes 5 perlitas por asignar',
        'Tienes 5 perlitas por asignar porque un amigo vinculó tu código de referido (vence en 90 días).',
        jsonb_build_object(
            'url', v_notif_url,
            'grant_id', v_grant_id,
            'amount', 5,
            'source', 'referral_signup'
        ),
        'grant_ref_' || v_grant_id::text
    );

    -- Evaluar insignia de embajador para el referidor
    PERFORM public.check_and_award_fan_badges(v_referrer_id);

    RETURN jsonb_build_object(
        'success', true,
        'referrer_id', v_referrer_id,
        'referrer_name', v_referrer_name,
        'message', '¡Código vinculado con éxito! Eres referido de ' || v_referrer_name
    );
END;
$$;

REVOKE ALL ON FUNCTION public.claim_referral_code(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.claim_referral_code(TEXT) TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 4. Actualizar get_my_referral_summary() para proyectar referred_by
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_my_referral_summary()
RETURNS JSONB
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_fan_id UUID := auth.uid();
    v_code TEXT;
    v_total_referred INT := 0;
    v_qualified_count INT := 0;
    v_points_earned INT := 0;
    v_referrals_list JSONB;
    v_referred_by JSONB;
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    SELECT code INTO v_code FROM public.referral_codes WHERE user_id = v_fan_id;
    IF v_code IS NULL THEN
        v_code := public.get_or_create_referral_code(v_fan_id);
    END IF;

    -- Conteo de amigos referidos
    SELECT COUNT(*) INTO v_total_referred
    FROM public.referrals
    WHERE referrer_id = v_fan_id;

    SELECT COUNT(*) INTO v_qualified_count
    FROM public.referrals
    WHERE referrer_id = v_fan_id AND status = 'qualified';

    -- Puntos ganados por referidos (signup grants reclamados + trivias)
    SELECT COALESCE(SUM(amount), 0) INTO v_points_earned
    FROM public.pending_pearl_grants
    WHERE fan_id = v_fan_id AND source = 'referral_signup' AND status = 'claimed';

    SELECT v_points_earned + COALESCE(SUM(points_awarded), 0) INTO v_points_earned
    FROM public.referral_trivia_rewards
    WHERE referrer_id = v_fan_id;

    -- Lista de referidos
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', r.id,
            'referred_name', COALESCE(p.display_name, 'Fanático'),
            'avatar_url', p.avatar_url,
            'status', r.status,
            'created_at', r.created_at
        ) ORDER BY r.created_at DESC
    ), '[]'::jsonb)
    INTO v_referrals_list
    FROM public.referrals r
    JOIN public.profiles p ON p.id = r.referred_id
    WHERE r.referrer_id = v_fan_id;

    -- Información de quién te refirió (si existe)
    SELECT jsonb_build_object(
        'has_referrer', true,
        'referrer_id', r.referrer_id,
        'referrer_name', COALESCE(p.display_name, 'Fanático'),
        'referrer_avatar', p.avatar_url,
        'referred_at', r.created_at
    )
    INTO v_referred_by
    FROM public.referrals r
    JOIN public.profiles p ON p.id = r.referrer_id
    WHERE r.referred_id = v_fan_id
    LIMIT 1;

    IF v_referred_by IS NULL THEN
        v_referred_by := jsonb_build_object('has_referrer', false);
    END IF;

    RETURN jsonb_build_object(
        'code', v_code,
        'total_referred', v_total_referred,
        'qualified_count', v_qualified_count,
        'points_earned', v_points_earned,
        'referrals', v_referrals_list,
        'referred_by', v_referred_by
    );
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_referral_summary() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_my_referral_summary() TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 5. RPC: public.get_fan_profile_enriched (Perfil enriquecido, nivel e insignias)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_fan_profile_enriched(
    p_fan_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_target_id UUID;
    v_profile RECORD;
    v_total_pearls INT := 0;
    v_trivias_count INT := 0;
    v_redemptions_count INT := 0;
    v_streak_days INT := 0;
    v_tier_name TEXT;
    v_tier_icon TEXT;
    v_next_threshold INT;
    v_progress_pct NUMERIC(5,2);
    v_badges JSONB;
    v_teams JSONB;
BEGIN
    v_target_id := COALESCE(p_fan_id, v_caller_id);
    IF v_target_id IS NULL THEN
        RAISE EXCEPTION 'User not specified and caller not authenticated.' USING ERRCODE = '42501';
    END IF;

    -- Obtener perfil
    SELECT id, display_name, avatar_url, cover_url, municipality, shirt_size, birth_date, gender, favorite_player_id, created_at
    INTO v_profile
    FROM public.profiles
    WHERE id = v_target_id AND status = 'active' AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('found', false, 'error', 'Perfil no encontrado o inactivo.');
    END IF;

    -- Evaluar insignias en tiempo real para el fanático
    PERFORM public.check_and_award_fan_badges(v_target_id);

    -- Estadísticas acumuladas
    SELECT COALESCE(SUM(amount), 0) INTO v_total_pearls
    FROM public.ledger_entries
    WHERE fan_id = v_target_id AND status = 'confirmed' AND amount > 0;

    SELECT COUNT(DISTINCT trivia_id) INTO v_trivias_count
    FROM public.trivia_attempts
    WHERE fan_id = v_target_id AND score > 0;

    SELECT COUNT(*) INTO v_redemptions_count
    FROM public.redemptions
    WHERE fan_id = v_target_id AND status IN ('approved', 'delivered', 'pending');

    SELECT COALESCE(current_streak, 0) INTO v_streak_days
    FROM public.fan_streaks
    WHERE fan_id = v_target_id;

    -- Cálculo del nivel de fanático (XP = total_pearls)
    IF v_total_pearls < 500 THEN
        v_tier_name := 'Fan Novato';
        v_tier_icon := 'bi-star-fill';
        v_next_threshold := 500;
        v_progress_pct := ROUND((v_total_pearls::numeric / 500.0) * 100, 1);
    ELSIF v_total_pearls < 2000 THEN
        v_tier_name := 'Fan Devoto';
        v_tier_icon := 'bi-shield-fill-check';
        v_next_threshold := 2000;
        v_progress_pct := ROUND(((v_total_pearls - 500)::numeric / 1500.0) * 100, 1);
    ELSIF v_total_pearls < 5000 THEN
        v_tier_name := 'Fan Insular';
        v_tier_icon := 'bi-trophy-fill';
        v_next_threshold := 5000;
        v_progress_pct := ROUND(((v_total_pearls - 2000)::numeric / 3000.0) * 100, 1);
    ELSE
        v_tier_name := 'Leyenda de la Tribu';
        v_tier_icon := 'bi-award-fill';
        v_next_threshold := NULL;
        v_progress_pct := 100.0;
    END IF;

    -- Lista completa de insignias con estado desbloqueado/bloqueado
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', b.id,
            'slug', b.slug,
            'name', b.name,
            'description', b.description,
            'icon_name', b.icon_name,
            'category', b.category,
            'tier', b.tier,
            'criteria_summary', b.criteria_summary,
            'is_unlocked', (fb.id IS NOT NULL),
            'awarded_at', fb.awarded_at
        ) ORDER BY (fb.id IS NOT NULL) DESC, b.created_at ASC
    ), '[]'::jsonb)
    INTO v_badges
    FROM public.badges b
    LEFT JOIN public.fan_badges fb ON fb.badge_id = b.id AND fb.fan_id = v_target_id;

    -- Equipos seguidos y saldo por equipo
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'team_id', t.id,
            'name', t.name,
            'slug', t.slug,
            'short_name', t.short_name,
            'logo_url', t.logo_url,
            'primary_color', t.primary_color,
            'followed_at', tf.created_at,
            'balance_cache', COALESCE(w.balance_cache, 0)
        ) ORDER BY tf.created_at ASC
    ), '[]'::jsonb)
    INTO v_teams
    FROM public.team_follows tf
    JOIN public.teams t ON t.id = tf.team_id AND t.status = 'active'
    LEFT JOIN public.wallets w ON w.team_id = t.id AND w.fan_id = v_target_id
    WHERE tf.user_id = v_target_id;

    RETURN jsonb_build_object(
        'found', true,
        'profile', jsonb_build_object(
            'id', v_profile.id,
            'display_name', v_profile.display_name,
            'avatar_url', v_profile.avatar_url,
            'cover_url', v_profile.cover_url,
            'municipality', v_profile.municipality,
            'shirt_size', v_profile.shirt_size,
            'birth_date', v_profile.birth_date,
            'gender', v_profile.gender,
            'favorite_player_id', v_profile.favorite_player_id,
            'created_at', v_profile.created_at
        ),
        'stats', jsonb_build_object(
            'total_pearls', v_total_pearls,
            'trivias_count', v_trivias_count,
            'redemptions_count', v_redemptions_count,
            'streak_days', v_streak_days
        ),
        'level', jsonb_build_object(
            'tier_name', v_tier_name,
            'tier_icon', v_tier_icon,
            'current_xp', v_total_pearls,
            'next_threshold', v_next_threshold,
            'progress_percent', v_progress_pct
        ),
        'badges', v_badges,
        'teams', v_teams
    );
END;
$$;

REVOKE ALL ON FUNCTION public.get_fan_profile_enriched(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_fan_profile_enriched(UUID) TO anon, authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 6. RPC: public.get_leaderboard (Multi-equipo con filtro y posición personal)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_leaderboard(
    p_period TEXT DEFAULT 'all_time'::TEXT,
    p_team_id UUID DEFAULT NULL::UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_start_date TIMESTAMPTZ;
    v_leaderboard JSONB;
    v_my_rank JSONB := NULL;
    v_team_info JSONB := NULL;
BEGIN
    -- Determinar rango de fecha según período
    IF p_period = 'weekly' THEN
        v_start_date := date_trunc('week', NOW() AT TIME ZONE 'America/Caracas');
    ELSIF p_period = 'monthly' THEN
        v_start_date := date_trunc('month', NOW() AT TIME ZONE 'America/Caracas');
    ELSE
        v_start_date := NULL;
    END IF;

    -- Obtener información del equipo si se especificó filtro
    IF p_team_id IS NOT NULL THEN
        SELECT jsonb_build_object(
            'id', t.id,
            'name', t.name,
            'slug', t.slug,
            'short_name', t.short_name,
            'logo_url', t.logo_url,
            'primary_color', t.primary_color
        )
        INTO v_team_info
        FROM public.teams t
        WHERE t.id = p_team_id AND t.status = 'active';
    END IF;

    -- Top 50 del ranking
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'rank', r.rank_number,
            'user_id', r.fan_id,
            'display_name', r.display_name,
            'avatar_url', r.avatar_url,
            'pearls_earned', r.total_pearls,
            'tier_name', CASE 
                WHEN r.total_pearls < 500 THEN 'Novato'
                WHEN r.total_pearls < 2000 THEN 'Devoto'
                WHEN r.total_pearls < 5000 THEN 'Insular'
                ELSE 'Leyenda'
            END,
            'is_current_user', (r.fan_id = v_uid)
        )
    ), '[]'::jsonb)
    INTO v_leaderboard
    FROM (
        SELECT 
            p.id AS fan_id,
            p.display_name,
            p.avatar_url,
            COALESCE(SUM(l.amount), 0)::INT AS total_pearls,
            ROW_NUMBER() OVER (ORDER BY COALESCE(SUM(l.amount), 0) DESC, p.created_at ASC) AS rank_number
        FROM public.profiles p
        JOIN public.ledger_entries l ON l.fan_id = p.id
        WHERE p.status = 'active'
          AND p.deleted_at IS NULL
          AND l.status = 'confirmed'
          AND l.amount > 0
          AND (p_team_id IS NULL OR l.team_id = p_team_id)
          AND (v_start_date IS NULL OR l.created_at >= v_start_date)
        GROUP BY p.id, p.display_name, p.avatar_url, p.created_at
        HAVING COALESCE(SUM(l.amount), 0) > 0
        ORDER BY total_pearls DESC, p.created_at ASC
        LIMIT 50
    ) r;

    -- Calcular posición del usuario actual si está autenticado
    IF v_uid IS NOT NULL THEN
        SELECT jsonb_build_object(
            'rank', my_pos.rank_number,
            'pearls_earned', my_pos.total_pearls,
            'tier_name', CASE 
                WHEN my_pos.total_pearls < 500 THEN 'Novato'
                WHEN my_pos.total_pearls < 2000 THEN 'Devoto'
                WHEN my_pos.total_pearls < 5000 THEN 'Insular'
                ELSE 'Leyenda'
            END
        )
        INTO v_my_rank
        FROM (
            SELECT 
                p.id AS fan_id,
                COALESCE(SUM(l.amount), 0)::INT AS total_pearls,
                ROW_NUMBER() OVER (ORDER BY COALESCE(SUM(l.amount), 0) DESC, p.created_at ASC) AS rank_number
            FROM public.profiles p
            JOIN public.ledger_entries l ON l.fan_id = p.id
            WHERE p.status = 'active'
              AND p.deleted_at IS NULL
              AND l.status = 'confirmed'
              AND l.amount > 0
              AND (p_team_id IS NULL OR l.team_id = p_team_id)
              AND (v_start_date IS NULL OR l.created_at >= v_start_date)
            GROUP BY p.id, p.created_at
            HAVING COALESCE(SUM(l.amount), 0) > 0
        ) my_pos
        WHERE my_pos.fan_id = v_uid;
    END IF;

    RETURN jsonb_build_object(
        'period', p_period,
        'team_id', p_team_id,
        'team', v_team_info,
        'leaderboard', COALESCE(v_leaderboard, '[]'::jsonb),
        'my_rank', v_my_rank
    );
END;
$$;

REVOKE ALL ON FUNCTION public.get_leaderboard(TEXT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_leaderboard(TEXT, UUID) TO anon, authenticated, service_role;
