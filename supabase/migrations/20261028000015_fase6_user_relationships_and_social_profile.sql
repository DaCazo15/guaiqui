-- ============================================================================
-- Migration: 20261028000015_fase6_user_relationships_and_social_profile.sql
-- Description: FASE 6 — Relaciones entre usuarios y perfil social tipo Instagram privado
--              1. Tabla user_follows (solicitudes pendientes / aceptadas)
--              2. Tabla user_blocks (bloqueo bidireccional)
--              3. Columna profiles.favorite_sport y ajuste de GRANT UPDATE de columnas
--              4. RPCs: send_follow_request, respond_follow_request, cancel_follow_request,
--                 unfollow_user, block_user, unblock_user, search_users, get_public_profile,
--                 get_my_follow_requests, get_blocked_users, get_user_followers, get_user_following
--              5. Notificaciones de solicitud recibida y aceptada
--              6. Seguridad y revocaciones estrictas
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Tabla user_follows (Relación Seguidor -> Seguido)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_follows (
    follower_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    followed_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL CHECK (status IN ('pending', 'accepted')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    responded_at TIMESTAMPTZ NULL,
    PRIMARY KEY (follower_id, followed_id),
    CONSTRAINT chk_user_follows_no_self CHECK (follower_id <> followed_id)
);

CREATE INDEX IF NOT EXISTS idx_user_follows_follower_status ON public.user_follows (follower_id, status);
CREATE INDEX IF NOT EXISTS idx_user_follows_followed_status ON public.user_follows (followed_id, status);

ALTER TABLE public.user_follows ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_follows_select_parties" ON public.user_follows;
CREATE POLICY "user_follows_select_parties" ON public.user_follows
    FOR SELECT TO authenticated
    USING (follower_id = auth.uid() OR followed_id = auth.uid());

-- Sin INSERT / UPDATE / DELETE para authenticated directo (solo vía RPCs)

-- ----------------------------------------------------------------------------
-- 2. Tabla user_blocks (Bloqueos de usuarios)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_blocks (
    blocker_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (blocker_id, blocked_id),
    CONSTRAINT chk_user_blocks_no_self CHECK (blocker_id <> blocked_id)
);

CREATE INDEX IF NOT EXISTS idx_user_blocks_blocked ON public.user_blocks (blocked_id);

ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_blocks_select_blocker" ON public.user_blocks;
CREATE POLICY "user_blocks_select_blocker" ON public.user_blocks
    FOR SELECT TO authenticated
    USING (blocker_id = auth.uid());

-- Sin INSERT / UPDATE / DELETE para authenticated directo (solo vía RPCs)

-- ----------------------------------------------------------------------------
-- 3. Extensión de profiles y permisos de actualización
-- ----------------------------------------------------------------------------
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS favorite_sport TEXT NULL;

-- Ajustar GRANT UPDATE manteniendo fuera columnas sensibles (email, phone, birth_date, role, status, etc.)
GRANT UPDATE (display_name, avatar_url, cover_url, municipality, gender, favorite_player_id, shirt_size, referral_source, notification_prefs, favorite_sport) ON TABLE public.profiles TO authenticated;

-- ----------------------------------------------------------------------------
-- 4. Notificaciones: soporte de tipos transaccionales sociales
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_notification(
    p_user_id UUID,
    p_type TEXT,
    p_title TEXT,
    p_body TEXT,
    p_data JSONB DEFAULT '{}'::jsonb,
    p_dedup_key TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_prefs JSONB;
    v_is_transactional BOOLEAN;
    v_daily_non_trans_count INT;
    v_dedup_key TEXT;
    v_cur_hour INT;
    v_next_attempt_at TIMESTAMPTZ := NOW();
    v_target_date DATE;
    v_notif_id UUID;
    v_has_active_push BOOLEAN := false;
BEGIN
    IF p_user_id IS NULL OR p_type IS NULL OR p_title IS NULL OR p_body IS NULL THEN
        RETURN NULL;
    END IF;

    v_dedup_key := COALESCE(p_dedup_key, gen_random_uuid()::text);

    -- Clasificación transaccional vs no transaccional
    v_is_transactional := (p_type IN (
        'redemption_approved',
        'redemption_delivered',
        'redemption_rejected',
        'redemption_cancelled',
        'redemption_issue',
        'redemption_expiring',
        'pearls_released',
        'pending_grant',
        'grant_expiring_soon',
        'referral_trivia',
        'follow_request_received',
        'follow_request_accepted'
    ));

    -- Obtener preferencias del usuario
    SELECT notification_prefs INTO v_prefs FROM public.profiles WHERE id = p_user_id;
    IF v_prefs IS NULL THEN
        v_prefs := '{"redemptions": true, "trivias_matches": true, "news": true, "push": true, "email": true}'::jsonb;
    END IF;

    IF NOT v_is_transactional THEN
        IF p_type IN ('new_trivia', 'match_day') THEN
            IF COALESCE((v_prefs->>'trivias_matches')::boolean, true) IS FALSE THEN
                RETURN NULL;
            END IF;
        ELSIF p_type IN ('team_news') THEN
            IF COALESCE((v_prefs->>'news')::boolean, true) IS FALSE THEN
                RETURN NULL;
            END IF;
        END IF;

        -- Tope de 1 notificación no transaccional al día
        SELECT COUNT(*) INTO v_daily_non_trans_count
        FROM public.notifications
        WHERE user_id = p_user_id
          AND type NOT IN (
              'redemption_approved', 'redemption_delivered', 'redemption_rejected',
              'redemption_cancelled', 'redemption_issue', 'redemption_expiring',
              'pearls_released', 'pending_grant', 'grant_expiring_soon', 'referral_trivia',
              'follow_request_received', 'follow_request_accepted'
          )
          AND created_at >= (NOW() AT TIME ZONE 'America/Caracas')::date;

        IF v_daily_non_trans_count >= 1 THEN
            RETURN NULL;
        END IF;

        -- Ventana de silencio: 22:00 a 08:00
        v_cur_hour := EXTRACT(HOUR FROM (NOW() AT TIME ZONE 'America/Caracas'))::int;
        IF v_cur_hour >= 22 OR v_cur_hour < 8 THEN
            IF v_cur_hour >= 22 THEN
                v_target_date := ((NOW() AT TIME ZONE 'America/Caracas') + INTERVAL '1 day')::date;
            ELSE
                v_target_date := (NOW() AT TIME ZONE 'America/Caracas')::date;
            END IF;
            v_next_attempt_at := (v_target_date || ' 08:00:00')::timestamp AT TIME ZONE 'America/Caracas';
        END IF;
    END IF;

    -- Inserción idempotente en notifications
    INSERT INTO public.notifications (user_id, type, title, body, data, dedup_key)
    VALUES (p_user_id, p_type, p_title, p_body, COALESCE(p_data, '{}'::jsonb), v_dedup_key)
    ON CONFLICT (user_id, dedup_key) DO NOTHING
    RETURNING id INTO v_notif_id;

    IF v_notif_id IS NULL THEN
        RETURN NULL;
    END IF;

    IF COALESCE((v_prefs->>'push')::boolean, true) IS NOT FALSE THEN
        SELECT EXISTS (
            SELECT 1 FROM public.push_subscriptions
            WHERE user_id = p_user_id AND disabled_at IS NULL
        ) INTO v_has_active_push;

        IF v_has_active_push THEN
            INSERT INTO public.notification_outbox (notification_id, channel, status, next_attempt_at)
            VALUES (v_notif_id, 'push', 'pending', v_next_attempt_at);
        END IF;
    END IF;

    IF COALESCE((v_prefs->>'email')::boolean, true) IS NOT FALSE THEN
        INSERT INTO public.notification_outbox (notification_id, channel, status, next_attempt_at)
        VALUES (v_notif_id, 'email', 'pending', v_next_attempt_at);
    END IF;

    RETURN v_notif_id;
END;
$$;

-- ----------------------------------------------------------------------------
-- 5. RPC send_follow_request (Enviar solicitud de seguimiento con anti-spam)
-- ----------------------------------------------------------------------------
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
BEGIN
    v_uid := public.assert_active_verified_fan();

    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'p_user_id es requerido.' USING ERRCODE = 'P0002';
    END IF;

    IF v_uid = p_user_id THEN
        RAISE EXCEPTION 'No puedes seguirte a ti mismo.' USING ERRCODE = 'P0001';
    END IF;

    -- Validar que el usuario objetivo exista y esté activo
    SELECT id, display_name, status INTO v_target
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

    -- Insertar solicitud pendiente
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
END;
$$;

-- ----------------------------------------------------------------------------
-- 6. RPC respond_follow_request (Aceptar o rechazar solicitud recibida)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.respond_follow_request(
    p_follower_id UUID,
    p_accept BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_uid UUID;
    v_req RECORD;
    v_caller_name TEXT;
BEGIN
    v_uid := public.assert_active_verified_fan();

    IF p_follower_id IS NULL OR p_accept IS NULL THEN
        RAISE EXCEPTION 'p_follower_id y p_accept son requeridos.' USING ERRCODE = 'P0002';
    END IF;

    SELECT * INTO v_req
    FROM public.user_follows
    WHERE follower_id = p_follower_id AND followed_id = v_uid
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Solicitud de seguimiento no encontrada.' USING ERRCODE = 'P0002';
    END IF;

    IF v_req.status = 'accepted' THEN
        RAISE EXCEPTION 'Esta solicitud ya había sido aceptada.' USING ERRCODE = 'P0001';
    END IF;

    IF p_accept IS TRUE THEN
        UPDATE public.user_follows
        SET status = 'accepted',
            responded_at = NOW()
        WHERE follower_id = p_follower_id AND followed_id = v_uid;

        SELECT display_name INTO v_caller_name FROM public.profiles WHERE id = v_uid;
        PERFORM public.create_notification(
            p_follower_id,
            'follow_request_accepted',
            'Solicitud aceptada',
            COALESCE(v_caller_name, 'Un fanático') || ' aceptó tu solicitud de seguimiento.',
            jsonb_build_object('followed_id', v_uid, 'url', '/u/' || v_uid::text)
        );

        RETURN jsonb_build_object(
            'success', true,
            'status', 'accepted',
            'follower_id', p_follower_id
        );
    ELSE
        DELETE FROM public.user_follows
        WHERE follower_id = p_follower_id AND followed_id = v_uid;

        RETURN jsonb_build_object(
            'success', true,
            'status', 'rejected',
            'follower_id', p_follower_id
        );
    END IF;
END;
$$;

-- ----------------------------------------------------------------------------
-- 7. RPC cancel_follow_request (Cancelar solicitud enviada)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cancel_follow_request(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_uid UUID;
BEGIN
    v_uid := public.assert_active_verified_fan();

    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'p_user_id es requerido.' USING ERRCODE = 'P0002';
    END IF;

    DELETE FROM public.user_follows
    WHERE follower_id = v_uid AND followed_id = p_user_id AND status = 'pending';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No hay solicitud pendiente para cancelar.' USING ERRCODE = 'P0002';
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'cancelled_user_id', p_user_id
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 8. RPC unfollow_user (Dejar de seguir a un usuario)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.unfollow_user(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_uid UUID;
BEGIN
    v_uid := public.assert_active_verified_fan();

    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'p_user_id es requerido.' USING ERRCODE = 'P0002';
    END IF;

    DELETE FROM public.user_follows
    WHERE follower_id = v_uid AND followed_id = p_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No sigues a este usuario.' USING ERRCODE = 'P0002';
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'unfollowed_user_id', p_user_id
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 9. RPC block_user (Bloquear y borrar relaciones de seguimiento en ambos sentidos)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.block_user(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_uid UUID;
BEGIN
    v_uid := public.assert_active_verified_fan();

    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'p_user_id es requerido.' USING ERRCODE = 'P0002';
    END IF;

    IF v_uid = p_user_id THEN
        RAISE EXCEPTION 'No puedes bloquearte a ti mismo.' USING ERRCODE = 'P0001';
    END IF;

    -- Registrar bloqueo
    INSERT INTO public.user_blocks (blocker_id, blocked_id, created_at)
    VALUES (v_uid, p_user_id, NOW())
    ON CONFLICT (blocker_id, blocked_id) DO NOTHING;

    -- Eliminar relaciones de seguimiento en ambos sentidos
    DELETE FROM public.user_follows
    WHERE (follower_id = v_uid AND followed_id = p_user_id)
       OR (follower_id = p_user_id AND followed_id = v_uid);

    RETURN jsonb_build_object(
        'success', true,
        'blocked_user_id', p_user_id
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 10. RPC unblock_user (Desbloquear usuario)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.unblock_user(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_uid UUID;
BEGIN
    v_uid := public.assert_active_verified_fan();

    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'p_user_id es requerido.' USING ERRCODE = 'P0002';
    END IF;

    DELETE FROM public.user_blocks
    WHERE blocker_id = v_uid AND blocked_id = p_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El usuario no se encuentra bloqueado.' USING ERRCODE = 'P0002';
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'unblocked_user_id', p_user_id
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 11. RPC search_users (Buscador con ILIKE, mínimo 2 caracteres, anti-bloqueo)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.search_users(
    p_query TEXT,
    p_limit INT DEFAULT 20,
    p_offset INT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_clean_q TEXT;
    v_users JSONB;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'No autenticado.' USING ERRCODE = '42501';
    END IF;

    v_clean_q := trim(COALESCE(p_query, ''));
    IF length(v_clean_q) < 2 THEN
        RETURN '[]'::jsonb;
    END IF;

    p_limit := LEAST(GREATEST(COALESCE(p_limit, 20), 1), 50);
    p_offset := GREATEST(COALESCE(p_offset, 0), 0);

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', p.id,
            'display_name', p.display_name,
            'avatar_url', p.avatar_url,
            'favorite_sport', p.favorite_sport,
            'relation_status', CASE
                WHEN uf.status = 'accepted' THEN 'accepted'
                WHEN uf.status = 'pending' THEN 'pending'
                WHEN ufi.status = 'pending' THEN 'incoming_pending'
                ELSE 'none'
            END
        ) ORDER BY p.display_name ASC
    ), '[]'::jsonb) INTO v_users
    FROM public.profiles p
    LEFT JOIN public.user_follows uf ON uf.follower_id = v_uid AND uf.followed_id = p.id
    LEFT JOIN public.user_follows ufi ON ufi.follower_id = p.id AND ufi.followed_id = v_uid AND ufi.status = 'pending'
    WHERE p.id <> v_uid
      AND p.status = 'active'
      AND p.deleted_at IS NULL
      AND p.display_name ILIKE ('%' || v_clean_q || '%')
      AND NOT EXISTS (
          SELECT 1 FROM public.user_blocks ub
          WHERE (ub.blocker_id = v_uid AND ub.blocked_id = p.id)
             OR (ub.blocker_id = p.id AND ub.blocked_id = v_uid)
      )
    LIMIT p_limit OFFSET p_offset;

    RETURN v_users;
END;
$$;

-- ----------------------------------------------------------------------------
-- 12. RPC get_public_profile (Perfil público tipo Instagram privado)
-- ----------------------------------------------------------------------------
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
        FROM public.rewards_redemptions
        WHERE fan_id = p_user_id AND status IN ('approved', 'delivered', 'confirmed');

        -- 3. Último premio canjeado
        SELECT jsonb_build_object(
            'product_name', COALESCE(p.name, 'Premio'),
            'image_url', p.image_url,
            'redeemed_at', r.created_at
        ) INTO v_last_reward
        FROM public.rewards_redemptions r
        LEFT JOIN public.products p ON p.id = r.product_id
        WHERE r.fan_id = p_user_id AND r.status IN ('approved', 'delivered', 'confirmed')
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

-- ----------------------------------------------------------------------------
-- 13. RPCs auxiliares: get_my_follow_requests, get_blocked_users, get_user_followers, get_user_following
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_my_follow_requests()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_requests JSONB;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'No autenticado.' USING ERRCODE = '42501';
    END IF;

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'follower_id', p.id,
            'display_name', p.display_name,
            'avatar_url', p.avatar_url,
            'favorite_sport', p.favorite_sport,
            'created_at', uf.created_at
        ) ORDER BY uf.created_at DESC
    ), '[]'::jsonb) INTO v_requests
    FROM public.user_follows uf
    JOIN public.profiles p ON p.id = uf.follower_id
    WHERE uf.followed_id = v_uid
      AND uf.status = 'pending'
      AND p.status = 'active'
      AND p.deleted_at IS NULL
      AND NOT EXISTS (
          SELECT 1 FROM public.user_blocks ub
          WHERE (ub.blocker_id = v_uid AND ub.blocked_id = p.id)
             OR (ub.blocker_id = p.id AND ub.blocked_id = v_uid)
      );

    RETURN v_requests;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_blocked_users()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_blocked JSONB;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'No autenticado.' USING ERRCODE = '42501';
    END IF;

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', p.id,
            'display_name', p.display_name,
            'avatar_url', p.avatar_url,
            'blocked_at', ub.created_at
        ) ORDER BY ub.created_at DESC
    ), '[]'::jsonb) INTO v_blocked
    FROM public.user_blocks ub
    JOIN public.profiles p ON p.id = ub.blocked_id
    WHERE ub.blocker_id = v_uid;

    RETURN v_blocked;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_user_followers(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_can_view BOOLEAN := false;
    v_followers JSONB;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'No autenticado.' USING ERRCODE = '42501';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.user_blocks ub
        WHERE (ub.blocker_id = v_uid AND ub.blocked_id = p_user_id)
           OR (ub.blocker_id = p_user_id AND ub.blocked_id = v_uid)
    ) THEN
        RAISE EXCEPTION 'Usuario no encontrado.' USING ERRCODE = 'P0002';
    END IF;

    IF v_uid = p_user_id OR EXISTS (
        SELECT 1 FROM public.user_follows
        WHERE follower_id = v_uid AND followed_id = p_user_id AND status = 'accepted'
    ) THEN
        v_can_view := true;
    END IF;

    IF NOT v_can_view THEN
        RETURN '[]'::jsonb;
    END IF;

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', p.id,
            'display_name', p.display_name,
            'avatar_url', p.avatar_url,
            'favorite_sport', p.favorite_sport
        ) ORDER BY p.display_name ASC
    ), '[]'::jsonb) INTO v_followers
    FROM public.user_follows uf
    JOIN public.profiles p ON p.id = uf.follower_id
    WHERE uf.followed_id = p_user_id
      AND uf.status = 'accepted'
      AND p.status = 'active'
      AND p.deleted_at IS NULL
      AND NOT EXISTS (
          SELECT 1 FROM public.user_blocks ub
          WHERE (ub.blocker_id = v_uid AND ub.blocked_id = p.id)
             OR (ub.blocker_id = p.id AND ub.blocked_id = v_uid)
      );

    RETURN v_followers;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_user_following(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_can_view BOOLEAN := false;
    v_following JSONB;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'No autenticado.' USING ERRCODE = '42501';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.user_blocks ub
        WHERE (ub.blocker_id = v_uid AND ub.blocked_id = p_user_id)
           OR (ub.blocker_id = p_user_id AND ub.blocked_id = v_uid)
    ) THEN
        RAISE EXCEPTION 'Usuario no encontrado.' USING ERRCODE = 'P0002';
    END IF;

    IF v_uid = p_user_id OR EXISTS (
        SELECT 1 FROM public.user_follows
        WHERE follower_id = v_uid AND followed_id = p_user_id AND status = 'accepted'
    ) THEN
        v_can_view := true;
    END IF;

    IF NOT v_can_view THEN
        RETURN '[]'::jsonb;
    END IF;

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', p.id,
            'display_name', p.display_name,
            'avatar_url', p.avatar_url,
            'favorite_sport', p.favorite_sport
        ) ORDER BY p.display_name ASC
    ), '[]'::jsonb) INTO v_following
    FROM public.user_follows uf
    JOIN public.profiles p ON p.id = uf.followed_id
    WHERE uf.follower_id = p_user_id
      AND uf.status = 'accepted'
      AND p.status = 'active'
      AND p.deleted_at IS NULL
      AND NOT EXISTS (
          SELECT 1 FROM public.user_blocks ub
          WHERE (ub.blocker_id = v_uid AND ub.blocked_id = p.id)
             OR (ub.blocker_id = p.id AND ub.blocked_id = v_uid)
      );

    RETURN v_following;
END;
$$;

-- ----------------------------------------------------------------------------
-- 14. Permisos de Seguridad (REVOKE FROM PUBLIC / anon; GRANT TO authenticated)
-- ----------------------------------------------------------------------------
REVOKE ALL ON TABLE public.user_follows FROM PUBLIC, anon;
GRANT SELECT ON TABLE public.user_follows TO authenticated;

REVOKE ALL ON TABLE public.user_blocks FROM PUBLIC, anon;
GRANT SELECT ON TABLE public.user_blocks TO authenticated;

REVOKE ALL ON FUNCTION public.send_follow_request(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.send_follow_request(UUID) TO authenticated;

REVOKE ALL ON FUNCTION public.respond_follow_request(UUID, BOOLEAN) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.respond_follow_request(UUID, BOOLEAN) TO authenticated;

REVOKE ALL ON FUNCTION public.cancel_follow_request(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_follow_request(UUID) TO authenticated;

REVOKE ALL ON FUNCTION public.unfollow_user(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.unfollow_user(UUID) TO authenticated;

REVOKE ALL ON FUNCTION public.block_user(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.block_user(UUID) TO authenticated;

REVOKE ALL ON FUNCTION public.unblock_user(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.unblock_user(UUID) TO authenticated;

REVOKE ALL ON FUNCTION public.search_users(TEXT, INT, INT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.search_users(TEXT, INT, INT) TO authenticated;

REVOKE ALL ON FUNCTION public.get_public_profile(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_public_profile(UUID) TO authenticated;

REVOKE ALL ON FUNCTION public.get_my_follow_requests() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_follow_requests() TO authenticated;

REVOKE ALL ON FUNCTION public.get_blocked_users() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_blocked_users() TO authenticated;

REVOKE ALL ON FUNCTION public.get_user_followers(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_user_followers(UUID) TO authenticated;

REVOKE ALL ON FUNCTION public.get_user_following(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_user_following(UUID) TO authenticated;
