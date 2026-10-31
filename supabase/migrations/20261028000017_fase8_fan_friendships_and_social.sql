-- ============================================================================
-- Migration: 20261028000017_fase8_fan_friendships_and_social.sql
-- Fase 8: Red Social de Fanáticos, Amistades, Solicitudes y Ranking entre Amigos
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Tabla: public.friendships (Amistades bidireccionales y Solicitudes)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.friendships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    addressee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL CHECK (status IN ('pending', 'accepted', 'declined', 'blocked')) DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_friendships_no_self CHECK (requester_id <> addressee_id)
);

-- Índice único bidireccional: asegura que no existan registros duplicados en sentido inverso
CREATE UNIQUE INDEX IF NOT EXISTS idx_friendships_pair 
ON public.friendships (LEAST(requester_id, addressee_id), GREATEST(requester_id, addressee_id));

CREATE INDEX IF NOT EXISTS idx_friendships_requester ON public.friendships(requester_id);
CREATE INDEX IF NOT EXISTS idx_friendships_addressee ON public.friendships(addressee_id);
CREATE INDEX IF NOT EXISTS idx_friendships_status ON public.friendships(status);

ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "friendships_select_involved" ON public.friendships;
CREATE POLICY "friendships_select_involved" ON public.friendships
FOR SELECT TO authenticated
USING (requester_id = auth.uid() OR addressee_id = auth.uid());

DROP POLICY IF EXISTS "friendships_insert_own" ON public.friendships;
CREATE POLICY "friendships_insert_own" ON public.friendships
FOR INSERT TO authenticated
WITH CHECK (requester_id = auth.uid());

DROP POLICY IF EXISTS "friendships_update_involved" ON public.friendships;
CREATE POLICY "friendships_update_involved" ON public.friendships
FOR UPDATE TO authenticated
USING (requester_id = auth.uid() OR addressee_id = auth.uid())
WITH CHECK (requester_id = auth.uid() OR addressee_id = auth.uid());

DROP POLICY IF EXISTS "friendships_delete_involved" ON public.friendships;
CREATE POLICY "friendships_delete_involved" ON public.friendships
FOR DELETE TO authenticated
USING (requester_id = auth.uid() OR addressee_id = auth.uid());

-- ----------------------------------------------------------------------------
-- 2. Insignia Nueva: amigo_fiel
-- ----------------------------------------------------------------------------
INSERT INTO public.badges (slug, name, description, icon, category, tier, criteria_summary)
VALUES (
    'amigo_fiel',
    'Amigo Fiel',
    'Conecta con la comunidad guaiquerí y ten al menos 1 amigo en la Fan Zone',
    'bi-people-fill',
    'social',
    'bronze',
    'Tener al menos 1 amistad confirmada'
)
ON CONFLICT (slug) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    category = EXCLUDED.category,
    tier = EXCLUDED.tier,
    criteria_summary = EXCLUDED.criteria_summary;

-- ----------------------------------------------------------------------------
-- 3. Actualización de check_and_award_fan_badges (con amigo_fiel)
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
    v_has_friends BOOLEAN;
    v_trivia_pearls INT := 0;
    v_streak_days INT := 0;
    v_ads_blocks INT := 0;
BEGIN
    IF p_fan_id IS NULL THEN
        RETURN;
    END IF;

    -- 1. fan_fiel (sigue a un equipo)
    SELECT EXISTS (
        SELECT 1 FROM public.team_follows WHERE user_id = p_fan_id
    ) INTO v_has_follow;

    IF v_has_follow THEN
        INSERT INTO public.fan_badges (fan_id, badge_id)
        SELECT p_fan_id, b.id FROM public.badges b WHERE b.slug = 'fan_fiel'
        ON CONFLICT (fan_id, badge_id) DO NOTHING;
    END IF;

    -- 2. primer_canje
    SELECT EXISTS (
        SELECT 1 FROM public.redemptions
        WHERE fan_id = p_fan_id AND status IN ('approved', 'delivered', 'pending')
    ) INTO v_has_redemption;

    IF v_has_redemption THEN
        INSERT INTO public.fan_badges (fan_id, badge_id)
        SELECT p_fan_id, b.id FROM public.badges b WHERE b.slug = 'primer_canje'
        ON CONFLICT (fan_id, badge_id) DO NOTHING;
    END IF;

    -- 3. embajador (referidos)
    SELECT EXISTS (
        SELECT 1 FROM public.referrals WHERE referrer_id = p_fan_id
    ) INTO v_has_referrals;

    IF v_has_referrals THEN
        INSERT INTO public.fan_badges (fan_id, badge_id)
        SELECT p_fan_id, b.id FROM public.badges b WHERE b.slug = 'embajador'
        ON CONFLICT (fan_id, badge_id) DO NOTHING;
    END IF;

    -- 4. amigo_fiel (tiene al menos 1 amistad aceptada)
    SELECT EXISTS (
        SELECT 1 FROM public.friendships
        WHERE (requester_id = p_fan_id OR addressee_id = p_fan_id)
          AND status = 'accepted'
    ) INTO v_has_friends;

    IF v_has_friends THEN
        INSERT INTO public.fan_badges (fan_id, badge_id)
        SELECT p_fan_id, b.id FROM public.badges b WHERE b.slug = 'amigo_fiel'
        ON CONFLICT (fan_id, badge_id) DO NOTHING;
    END IF;

    -- 5. experto_trivia (más de 50 perlitas ganadas en trivias)
    SELECT COALESCE(SUM(amount), 0) INTO v_trivia_pearls
    FROM public.ledger_entries
    WHERE fan_id = p_fan_id AND type = 'trivia_reward' AND status = 'confirmed';

    IF v_trivia_pearls >= 50 THEN
        INSERT INTO public.fan_badges (fan_id, badge_id)
        SELECT p_fan_id, b.id FROM public.badges b WHERE b.slug = 'experto_trivia'
        ON CONFLICT (fan_id, badge_id) DO NOTHING;
    END IF;

    -- 6. racha_fuego (racha de al menos 7 días)
    SELECT COALESCE(MAX(current_streak), 0) INTO v_streak_days
    FROM public.streaks
    WHERE user_id = p_fan_id;

    IF v_streak_days >= 7 THEN
        INSERT INTO public.fan_badges (fan_id, badge_id)
        SELECT p_fan_id, b.id FROM public.badges b WHERE b.slug = 'racha_fuego'
        ON CONFLICT (fan_id, badge_id) DO NOTHING;
    END IF;

    -- 7. anuncios_vip (al menos 3 bloques de 10 anuncios completados)
    SELECT COALESCE(COUNT(*), 0) INTO v_ads_blocks
    FROM public.pending_pearl_grants
    WHERE fan_id = p_fan_id AND source = 'ads_block';

    IF v_ads_blocks >= 3 THEN
        INSERT INTO public.fan_badges (fan_id, badge_id)
        SELECT p_fan_id, b.id FROM public.badges b WHERE b.slug = 'anuncios_vip'
        ON CONFLICT (fan_id, badge_id) DO NOTHING;
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.check_and_award_fan_badges(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_and_award_fan_badges(UUID) TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 4. RPC: public.send_friend_request (Enviar solicitud de amistad)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.send_friend_request(p_target TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $$
DECLARE
    v_fan_id UUID := auth.uid();
    v_clean_target TEXT;
    v_target_id UUID;
    v_target_name TEXT;
    v_existing_id UUID;
    v_existing_status TEXT;
    v_existing_requester UUID;
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'NOT_AUTHENTICATED';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE id = v_fan_id AND status = 'active' AND deleted_at IS NULL
    ) THEN
        RAISE EXCEPTION 'USER_SUSPENDED_OR_INACTIVE';
    END IF;

    v_clean_target := TRIM(p_target);
    IF v_clean_target IS NULL OR v_clean_target = '' THEN
        RAISE EXCEPTION 'TARGET_REQUIRED';
    END IF;

    -- 1. Intentar resolver por código de referido / código de fan
    SELECT rc.fan_id, p.display_name
    INTO v_target_id, v_target_name
    FROM public.referral_codes rc
    JOIN public.profiles p ON p.id = rc.fan_id
    WHERE UPPER(rc.code) = UPPER(v_clean_target)
      AND p.status = 'active'
      AND p.deleted_at IS NULL
    LIMIT 1;

    -- 2. Si no se halló por código y parece UUID, intentar por ID directo
    IF v_target_id IS NULL AND v_clean_target ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        SELECT p.id, p.display_name
        INTO v_target_id, v_target_name
        FROM public.profiles p
        WHERE p.id = v_clean_target::UUID
          AND p.status = 'active'
          AND p.deleted_at IS NULL;
    END IF;

    -- 3. Si aún no se halla, intentar por display_name exacto
    IF v_target_id IS NULL THEN
        SELECT p.id, p.display_name
        INTO v_target_id, v_target_name
        FROM public.profiles p
        WHERE LOWER(p.display_name) = LOWER(v_clean_target)
          AND p.status = 'active'
          AND p.deleted_at IS NULL
        LIMIT 1;
    END IF;

    IF v_target_id IS NULL THEN
        RAISE EXCEPTION 'USER_NOT_FOUND';
    END IF;

    IF v_target_id = v_fan_id THEN
        RAISE EXCEPTION 'CANNOT_FRIEND_SELF';
    END IF;

    -- Verificar estado de amistad previo
    SELECT id, status, requester_id
    INTO v_existing_id, v_existing_status, v_existing_requester
    FROM public.friendships
    WHERE (requester_id = v_fan_id AND addressee_id = v_target_id)
       OR (requester_id = v_target_id AND addressee_id = v_fan_id)
    LIMIT 1;

    IF v_existing_id IS NOT NULL THEN
        IF v_existing_status = 'accepted' THEN
            RAISE EXCEPTION 'ALREADY_FRIENDS';
        ELSIF v_existing_status = 'blocked' THEN
            RAISE EXCEPTION 'CANNOT_SEND_REQUEST';
        ELSIF v_existing_status = 'pending' THEN
            IF v_existing_requester = v_fan_id THEN
                RAISE EXCEPTION 'REQUEST_ALREADY_SENT';
            ELSE
                -- Solicitud mutua: aceptar automáticamente
                UPDATE public.friendships
                SET status = 'accepted', updated_at = NOW()
                WHERE id = v_existing_id;

                PERFORM public.check_and_award_fan_badges(v_fan_id);
                PERFORM public.check_and_award_fan_badges(v_target_id);

                RETURN jsonb_build_object(
                    'success', true,
                    'status', 'accepted',
                    'message', '¡Solicitud mutua aceptada! Ahora son amigos.',
                    'target_name', v_target_name
                );
            END IF;
        ELSIF v_existing_status = 'declined' THEN
            -- Reactivar solicitud previamente rechazada
            UPDATE public.friendships
            SET requester_id = v_fan_id,
                addressee_id = v_target_id,
                status = 'pending',
                updated_at = NOW()
            WHERE id = v_existing_id;

            RETURN jsonb_build_object(
                'success', true,
                'status', 'pending',
                'message', 'Solicitud de amistad reenviada.',
                'target_name', v_target_name
            );
        END IF;
    END IF;

    -- Inserción de nueva solicitud
    INSERT INTO public.friendships (requester_id, addressee_id, status)
    VALUES (v_fan_id, v_target_id, 'pending');

    RETURN jsonb_build_object(
        'success', true,
        'status', 'pending',
        'message', 'Solicitud de amistad enviada exitosamente.',
        'target_name', v_target_name
    );
END;
$$;

REVOKE ALL ON FUNCTION public.send_friend_request(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.send_friend_request(TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 5. RPC: public.respond_friend_request (Aceptar o rechazar solicitud)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.respond_friend_request(
    p_friendship_id UUID,
    p_action TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $$
DECLARE
    v_fan_id UUID := auth.uid();
    v_requester_id UUID;
    v_status TEXT;
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'NOT_AUTHENTICATED';
    END IF;

    IF p_action NOT IN ('accepted', 'declined', 'blocked') THEN
        RAISE EXCEPTION 'INVALID_ACTION';
    END IF;

    SELECT requester_id, status
    INTO v_requester_id, v_status
    FROM public.friendships
    WHERE id = p_friendship_id AND addressee_id = v_fan_id;

    IF v_requester_id IS NULL THEN
        RAISE EXCEPTION 'REQUEST_NOT_FOUND_OR_FORBIDDEN';
    END IF;

    IF v_status <> 'pending' AND p_action = 'accepted' THEN
        RAISE EXCEPTION 'REQUEST_ALREADY_PROCESSED';
    END IF;

    UPDATE public.friendships
    SET status = p_action,
        updated_at = NOW()
    WHERE id = p_friendship_id;

    IF p_action = 'accepted' THEN
        PERFORM public.check_and_award_fan_badges(v_fan_id);
        PERFORM public.check_and_award_fan_badges(v_requester_id);
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'friendship_id', p_friendship_id,
        'status', p_action
    );
END;
$$;

REVOKE ALL ON FUNCTION public.respond_friend_request(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.respond_friend_request(UUID, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 6. RPC: public.remove_friend (Eliminar o cancelar amistad)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.remove_friend(p_friendship_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $$
DECLARE
    v_fan_id UUID := auth.uid();
    v_deleted_count INT;
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'NOT_AUTHENTICATED';
    END IF;

    DELETE FROM public.friendships
    WHERE id = p_friendship_id
      AND (requester_id = v_fan_id OR addressee_id = v_fan_id);

    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

    IF v_deleted_count = 0 THEN
        RAISE EXCEPTION 'FRIENDSHIP_NOT_FOUND';
    END IF;

    RETURN jsonb_build_object('success', true);
END;
$$;

REVOKE ALL ON FUNCTION public.remove_friend(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.remove_friend(UUID) TO authenticated;

-- ----------------------------------------------------------------------------
-- 7. RPC: public.get_my_friends_and_requests (Listar amigos y solicitudes)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_my_friends_and_requests()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $$
DECLARE
    v_fan_id UUID := auth.uid();
    v_friends JSONB;
    v_incoming JSONB;
    v_outgoing JSONB;
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'NOT_AUTHENTICATED';
    END IF;

    -- 1. Amigos confirmados (status = 'accepted')
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'friendship_id', f.id,
            'friend_id', p.id,
            'display_name', p.display_name,
            'avatar_url', p.avatar_url,
            'since', f.updated_at,
            'total_pearls', COALESCE(pearls.total, 0),
            'tier_name', CASE 
                WHEN COALESCE(pearls.total, 0) < 500 THEN 'Novato'
                WHEN COALESCE(pearls.total, 0) < 2000 THEN 'Devoto'
                WHEN COALESCE(pearls.total, 0) < 5000 THEN 'Insular'
                ELSE 'Leyenda'
            END,
            'badges_count', COALESCE(badges_stat.cnt, 0),
            'favorite_player', p.favorite_player_id
        ) ORDER BY p.display_name ASC
    ), '[]'::jsonb)
    INTO v_friends
    FROM public.friendships f
    JOIN public.profiles p ON p.id = (CASE WHEN f.requester_id = v_fan_id THEN f.addressee_id ELSE f.requester_id END)
    LEFT JOIN (
        SELECT fan_id, SUM(amount)::INT AS total 
        FROM public.ledger_entries 
        WHERE status = 'confirmed' AND amount > 0 
        GROUP BY fan_id
    ) pearls ON pearls.fan_id = p.id
    LEFT JOIN (
        SELECT fan_id, COUNT(*)::INT AS cnt 
        FROM public.fan_badges 
        GROUP BY fan_id
    ) badges_stat ON badges_stat.fan_id = p.id
    WHERE (f.requester_id = v_fan_id OR f.addressee_id = v_fan_id)
      AND f.status = 'accepted'
      AND p.status = 'active'
      AND p.deleted_at IS NULL;

    -- 2. Solicitudes entrantes (status = 'pending' y addressee_id = v_fan_id)
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'friendship_id', f.id,
            'sender_id', p.id,
            'display_name', p.display_name,
            'avatar_url', p.avatar_url,
            'created_at', f.created_at,
            'tier_name', CASE 
                WHEN COALESCE(pearls.total, 0) < 500 THEN 'Novato'
                WHEN COALESCE(pearls.total, 0) < 2000 THEN 'Devoto'
                WHEN COALESCE(pearls.total, 0) < 5000 THEN 'Insular'
                ELSE 'Leyenda'
            END
        ) ORDER BY f.created_at DESC
    ), '[]'::jsonb)
    INTO v_incoming
    FROM public.friendships f
    JOIN public.profiles p ON p.id = f.requester_id
    LEFT JOIN (
        SELECT fan_id, SUM(amount)::INT AS total 
        FROM public.ledger_entries 
        WHERE status = 'confirmed' AND amount > 0 
        GROUP BY fan_id
    ) pearls ON pearls.fan_id = p.id
    WHERE f.addressee_id = v_fan_id
      AND f.status = 'pending'
      AND p.status = 'active'
      AND p.deleted_at IS NULL;

    -- 3. Solicitudes enviadas (status = 'pending' y requester_id = v_fan_id)
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'friendship_id', f.id,
            'target_id', p.id,
            'display_name', p.display_name,
            'avatar_url', p.avatar_url,
            'created_at', f.created_at
        ) ORDER BY f.created_at DESC
    ), '[]'::jsonb)
    INTO v_outgoing
    FROM public.friendships f
    JOIN public.profiles p ON p.id = f.addressee_id
    WHERE f.requester_id = v_fan_id
      AND f.status = 'pending'
      AND p.status = 'active'
      AND p.deleted_at IS NULL;

    RETURN jsonb_build_object(
        'friends', v_friends,
        'incoming_requests', v_incoming,
        'outgoing_requests', v_outgoing,
        'total_friends', jsonb_array_length(v_friends)
    );
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_friends_and_requests() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_my_friends_and_requests() TO authenticated;

-- ----------------------------------------------------------------------------
-- 8. Actualización de get_leaderboard (con soporte para p_friends_only)
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.get_leaderboard(TEXT, UUID);
DROP FUNCTION IF EXISTS public.get_leaderboard(TEXT, UUID, BOOLEAN);

CREATE OR REPLACE FUNCTION public.get_leaderboard(
    p_period TEXT DEFAULT 'all_time'::TEXT,
    p_team_id UUID DEFAULT NULL::UUID,
    p_friends_only BOOLEAN DEFAULT FALSE
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
    v_friends_count INT := 0;
BEGIN
    -- Rango de fecha según período
    IF p_period = 'weekly' THEN
        v_start_date := date_trunc('week', NOW() AT TIME ZONE 'America/Caracas');
    ELSIF p_period = 'monthly' THEN
        v_start_date := date_trunc('month', NOW() AT TIME ZONE 'America/Caracas');
    ELSE
        v_start_date := NULL;
    END IF;

    -- Información de equipo
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

    -- Conteo de amigos si se solicitó amigos_only
    IF p_friends_only AND v_uid IS NOT NULL THEN
        SELECT COUNT(*) INTO v_friends_count
        FROM public.friendships
        WHERE (requester_id = v_uid OR addressee_id = v_uid)
          AND status = 'accepted';
    END IF;

    -- Top 50 del ranking (Global, por equipo y/o acotado al círculo de amigos)
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
          AND (
              NOT p_friends_only 
              OR v_uid IS NULL
              OR p.id = v_uid
              OR p.id IN (
                  SELECT CASE WHEN f.requester_id = v_uid THEN f.addressee_id ELSE f.requester_id END
                  FROM public.friendships f
                  WHERE (f.requester_id = v_uid OR f.addressee_id = v_uid)
                    AND f.status = 'accepted'
              )
          )
        GROUP BY p.id, p.display_name, p.avatar_url, p.created_at
        HAVING COALESCE(SUM(l.amount), 0) > 0
        ORDER BY total_pearls DESC, p.created_at ASC
        LIMIT 50
    ) r;

    -- Calcular posición del usuario actual
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
              AND (
                  NOT p_friends_only 
                  OR p.id = v_uid
                  OR p.id IN (
                      SELECT CASE WHEN f.requester_id = v_uid THEN f.addressee_id ELSE f.requester_id END
                      FROM public.friendships f
                      WHERE (f.requester_id = v_uid OR f.addressee_id = v_uid)
                        AND f.status = 'accepted'
                  )
              )
            GROUP BY p.id, p.created_at
            HAVING COALESCE(SUM(l.amount), 0) > 0
        ) my_pos
        WHERE my_pos.fan_id = v_uid;
    END IF;

    RETURN jsonb_build_object(
        'period', p_period,
        'team_id', p_team_id,
        'team', v_team_info,
        'friends_only', p_friends_only,
        'friends_count', v_friends_count,
        'leaderboard', COALESCE(v_leaderboard, '[]'::jsonb),
        'my_rank', v_my_rank
    );
END;
$$;

REVOKE ALL ON FUNCTION public.get_leaderboard(TEXT, UUID, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_leaderboard(TEXT, UUID, BOOLEAN) TO anon, authenticated, service_role;
