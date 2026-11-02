-- ============================================================================
-- Migration: 20261028000018_fix_get_public_profile_redemptions.sql
-- Description: Fix get_public_profile to query public.redemptions with valid
--              redemption_status enum values ('approved', 'delivered', 'completed')
--              instead of nonexistent rewards_redemptions and 'confirmed'.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_public_profile(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_viewer_id UUID := auth.uid();
    v_profile RECORD;
    v_relation_status TEXT := 'none';
    v_is_full_profile BOOLEAN := false;
    v_followers_count INT := 0;
    v_following_count INT := 0;
    v_followed_teams JSONB := '[]'::jsonb;
    v_ranking JSONB := NULL;
    v_redemptions_count INT := NULL;
    v_last_reward JSONB := NULL;
    v_total_pearls INT := NULL;
    v_is_blocked BOOLEAN := false;
BEGIN
    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'p_user_id es requerido.' USING ERRCODE = 'P0002';
    END IF;

    -- Obtener perfil base
    SELECT id, display_name, avatar_url, cover_url, favorite_sport, status, deleted_at
    INTO v_profile
    FROM public.profiles
    WHERE id = p_user_id;

    IF NOT FOUND OR v_profile.status != 'active' OR v_profile.deleted_at IS NOT NULL THEN
        RAISE EXCEPTION 'Usuario no encontrado.' USING ERRCODE = 'P0002';
    END IF;

    -- Si hay usuario autenticado, comprobar bloqueos mutuos
    IF v_viewer_id IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1 FROM public.user_blocks
            WHERE (blocker_id = v_viewer_id AND blocked_id = p_user_id)
               OR (blocker_id = p_user_id AND blocked_id = v_viewer_id)
        ) INTO v_is_blocked;

        IF v_is_blocked THEN
            RAISE EXCEPTION 'Usuario no encontrado.' USING ERRCODE = 'P0002';
        END IF;

        -- Determinar relación
        IF v_viewer_id = p_user_id THEN
            v_relation_status := 'self';
            v_is_full_profile := true;
        ELSE
            SELECT status INTO v_relation_status
            FROM public.user_follows
            WHERE follower_id = v_viewer_id AND followed_id = p_user_id;

            IF v_relation_status IS NOT NULL THEN
                IF v_relation_status = 'accepted' THEN
                    v_is_full_profile := true;
                END IF;
            ELSE
                -- Comprobar si hay solicitud entrante
                IF EXISTS (
                    SELECT 1 FROM public.user_follows
                    WHERE follower_id = p_user_id AND followed_id = v_viewer_id AND status = 'pending'
                ) THEN
                    v_relation_status := 'incoming_pending';
                ELSE
                    v_relation_status := 'none';
                END IF;
            END IF;
        END IF;
    END IF;

    -- Conteos públicos de seguidores y seguidos aceptados
    SELECT COUNT(*)::int INTO v_followers_count
    FROM public.user_follows uf
    JOIN public.profiles p ON p.id = uf.follower_id
    WHERE uf.followed_id = p_user_id 
      AND uf.status = 'accepted'
      AND p.status = 'active'
      AND p.deleted_at IS NULL;

    SELECT COUNT(*)::int INTO v_following_count
    FROM public.user_follows uf
    JOIN public.profiles p ON p.id = uf.followed_id
    WHERE uf.follower_id = p_user_id 
      AND uf.status = 'accepted'
      AND p.status = 'active'
      AND p.deleted_at IS NULL;

    -- Equipos que sigue (público)
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', t.id,
            'name', t.name,
            'slug', t.slug,
            'logo_url', t.logo_url
        ) ORDER BY t.name ASC
    ), '[]'::jsonb) INTO v_followed_teams
    FROM public.team_follows tf
    JOIN public.teams t ON t.id = tf.team_id
    WHERE tf.user_id = p_user_id AND t.status = 'active';

    -- Si es perfil completo (seguidor aceptado o el mismo usuario), calcular métricas privadas
    IF v_is_full_profile THEN
        -- 1. Posición y puntos en ranking
        SELECT jsonb_build_object(
            'rank', sub.rank_number,
            'points', sub.total_points
        ) INTO v_ranking
        FROM (
            SELECT 
                p.id,
                COALESCE(SUM(l.amount), 0)::int AS total_points,
                ROW_NUMBER() OVER (ORDER BY COALESCE(SUM(l.amount), 0) DESC, p.created_at ASC) AS rank_number
            FROM public.profiles p
            LEFT JOIN public.ledger_entries l ON l.fan_id = p.id AND l.status = 'confirmed' AND l.amount > 0
            WHERE p.status = 'active' AND p.deleted_at IS NULL
            GROUP BY p.id, p.created_at
        ) sub
        WHERE sub.id = p_user_id;

        -- 2. Conteo de canjes realizados
        SELECT COUNT(*)::int INTO v_redemptions_count
        FROM public.redemptions
        WHERE fan_id = p_user_id AND status IN ('approved', 'delivered', 'completed');

        -- 3. Último premio canjeado
        SELECT jsonb_build_object(
            'product_name', COALESCE(p.name, 'Premio'),
            'image_url', p.image_url,
            'redeemed_at', r.created_at
        ) INTO v_last_reward
        FROM public.redemptions r
        LEFT JOIN public.products p ON p.id = r.product_id
        WHERE r.fan_id = p_user_id AND r.status IN ('approved', 'delivered', 'completed')
        ORDER BY r.created_at DESC
        LIMIT 1;

        -- 4. Perlitas totales calculadas en tiempo real (inmutable)
        SELECT COALESCE(SUM(balance_cache), 0)::int INTO v_total_pearls
        FROM public.wallets
        WHERE fan_id = p_user_id;
    END IF;

    -- Retornar payload sin JAMÁS incluir email, teléfono, birth_date, municipio ni talla
    RETURN jsonb_build_object(
        'id', v_profile.id,
        'display_name', v_profile.display_name,
        'avatar_url', v_profile.avatar_url,
        'cover_url', v_profile.cover_url,
        'favorite_sport', v_profile.favorite_sport,
        'followed_teams', v_followed_teams,
        'followers_count', v_followers_count,
        'following_count', v_following_count,
        'relation_status', v_relation_status,
        'is_full_profile', v_is_full_profile,
        'ranking', v_ranking,
        'redemptions_count', v_redemptions_count,
        'last_reward', v_last_reward,
        'total_pearls', v_total_pearls
    );
END;
$$;

REVOKE ALL ON FUNCTION public.get_public_profile(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_public_profile(UUID) TO authenticated;
