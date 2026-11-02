-- ============================================================================
-- Migration: 20261028000021_add_profile_privacy_and_update_public_profile.sql
-- Description: Configurar perfiles públicos por defecto y soporte de cuenta privada
--              1. Columna profiles.is_private (BOOLEAN DEFAULT false)
--              2. Permisos de actualización de is_private para authenticated
--              3. Actualización de get_public_profile (público por defecto + is_following en equipos)
--              4. Actualización de send_follow_request (seguimiento inmediato si cuenta es pública)
-- ============================================================================

-- 1. Añadir columna is_private a public.profiles con valor por defecto false (perfil público)
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_private BOOLEAN NOT NULL DEFAULT false;

-- 2. Conceder permisos de actualización de is_private al usuario autenticado
GRANT UPDATE (
    display_name, avatar_url, cover_url, municipality, gender,
    favorite_player_id, shirt_size, referral_source, notification_prefs,
    favorite_sport, is_private
) ON TABLE public.profiles TO authenticated;

-- 3. Actualizar función get_public_profile
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

    -- Obtener perfil base incluyendo is_private
    SELECT id, display_name, avatar_url, cover_url, favorite_sport, COALESCE(is_private, false) AS is_private, status, deleted_at
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
                -- Si ya fue aceptado o si la cuenta es pública, el perfil es completo
                IF v_relation_status = 'accepted' OR NOT v_profile.is_private THEN
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

                -- Si la cuenta es pública, cualquier visitante autenticado puede ver el perfil completo
                IF NOT v_profile.is_private THEN
                    v_is_full_profile := true;
                END IF;
            END IF;
        END IF;
    ELSE
        -- Visitante sin sesión: perfil completo si es público
        IF NOT v_profile.is_private THEN
            v_is_full_profile := true;
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

    -- Equipos que sigue (público) con bandera is_following para el espectador autenticado
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', t.id,
            'name', t.name,
            'slug', t.slug,
            'logo_url', t.logo_url,
            'is_following', CASE 
                WHEN v_viewer_id IS NOT NULL THEN EXISTS (
                    SELECT 1 FROM public.team_follows vtf
                    WHERE vtf.user_id = v_viewer_id AND vtf.team_id = t.id
                )
                ELSE false
            END
        ) ORDER BY t.name ASC
    ), '[]'::jsonb) INTO v_followed_teams
    FROM public.team_follows tf
    JOIN public.teams t ON t.id = tf.team_id
    WHERE tf.user_id = p_user_id AND t.status = 'active';

    -- Si es perfil completo (público o seguidor aceptado o el mismo usuario), calcular métricas
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
            'image_url', COALESCE(p.image_url, CASE WHEN array_length(p.images, 1) > 0 THEN p.images[1] ELSE NULL END),
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
        'is_private', v_profile.is_private,
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

-- 4. Actualizar función send_follow_request (Seguimiento inmediato si es público)
CREATE OR REPLACE FUNCTION public.send_follow_request(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_uid UUID;
    v_target RECORD;
    v_existing RECORD;
    v_caller_name TEXT;
    v_is_target_private BOOLEAN := false;
BEGIN
    v_uid := public.assert_active_verified_fan();

    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'p_user_id es requerido.' USING ERRCODE = 'P0002';
    END IF;

    IF v_uid = p_user_id THEN
        RAISE EXCEPTION 'No puedes seguirte a ti mismo.' USING ERRCODE = 'P0001';
    END IF;

    -- Validar que el usuario objetivo exista y esté activo
    SELECT id, display_name, status, COALESCE(is_private, false) AS is_private INTO v_target
    FROM public.profiles
    WHERE id = p_user_id;

    IF NOT FOUND OR v_target.status != 'active' THEN
        RAISE EXCEPTION 'El usuario seleccionado no existe o no se encuentra activo.' USING ERRCODE = 'P0002';
    END IF;

    -- Validar que no haya bloqueo mutuo
    IF EXISTS (
        SELECT 1 FROM public.user_blocks
        WHERE (blocker_id = v_uid AND blocked_id = p_user_id)
           OR (blocker_id = p_user_id AND blocked_id = v_uid)
    ) THEN
        RAISE EXCEPTION 'No puedes interactuar con este usuario debido a un bloqueo.' USING ERRCODE = 'P0001';
    END IF;

    -- Anti-spam / rate limit diario (máximo 30 solicitudes por día)
    BEGIN
        PERFORM public.check_rate_limit(v_uid, 'send_follow_request', 30, 86400);
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM LIKE '%RATE_LIMITED%' THEN
            RAISE EXCEPTION 'Has alcanzado el límite diario de solicitudes de seguimiento.' USING ERRCODE = 'P0001';
        ELSE
            RAISE;
        END IF;
    END;

    -- Validar estado existente
    SELECT * INTO v_existing
    FROM public.user_follows
    WHERE follower_id = v_uid AND followed_id = p_user_id;

    IF FOUND THEN
        IF v_existing.status = 'accepted' THEN
            RAISE EXCEPTION 'Ya sigues a este usuario.' USING ERRCODE = 'P0001';
        ELSE
            RAISE EXCEPTION 'Ya existe una solicitud pendiente para este usuario.' USING ERRCODE = 'P0001';
        END IF;
    END IF;

    v_is_target_private := COALESCE(v_target.is_private, false);

    IF v_is_target_private THEN
        -- Cuenta privada: solicitud pendiente de aprobación
        INSERT INTO public.user_follows (follower_id, followed_id, status, created_at)
        VALUES (v_uid, p_user_id, 'pending', NOW());

        -- Notificar al usuario objetivo
        SELECT display_name INTO v_caller_name FROM public.profiles WHERE id = v_uid;
        PERFORM public.create_notification(
            p_user_id,
            'follow_request_received',
            'Nueva solicitud de seguimiento',
            COALESCE(v_caller_name, 'Un fanático') || ' te ha enviado una solicitud de seguimiento.',
            jsonb_build_object('follower_id', v_uid, 'url', '/app/perfil')
        );

        RETURN jsonb_build_object(
            'success', true,
            'status', 'pending',
            'followed_id', p_user_id
        );
    ELSE
        -- Cuenta pública: seguimiento inmediato
        INSERT INTO public.user_follows (follower_id, followed_id, status, created_at, responded_at)
        VALUES (v_uid, p_user_id, 'accepted', NOW(), NOW());

        -- Notificar al usuario objetivo de nuevo seguidor
        SELECT display_name INTO v_caller_name FROM public.profiles WHERE id = v_uid;
        PERFORM public.create_notification(
            p_user_id,
            'new_follower',
            'Nuevo seguidor',
            COALESCE(v_caller_name, 'Un fanático') || ' ha comenzado a seguirte.',
            jsonb_build_object('follower_id', v_uid, 'url', '/u/' || v_uid::text)
        );

        RETURN jsonb_build_object(
            'success', true,
            'status', 'accepted',
            'followed_id', p_user_id
        );
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.send_follow_request(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.send_follow_request(UUID) TO authenticated;
