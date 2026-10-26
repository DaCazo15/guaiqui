-- Migration: 20261026000002_create_guess_player_challenges.sql
-- Description: Creates guess_player_challenges and guess_player_votes tables with secure RPC functions for "¿Quién es?" game mode.

CREATE TABLE IF NOT EXISTS public.guess_player_challenges (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    player_id UUID NOT NULL REFERENCES public.players(id) ON DELETE CASCADE,
    challenge_type TEXT DEFAULT 'silhouette'::text NOT NULL,
    title TEXT DEFAULT '¿Quién es este jugador?'::text NOT NULL,
    clue TEXT,
    custom_image_url TEXT,
    dorsal_number INT,
    reward_pearls INT DEFAULT 50 NOT NULL,
    status TEXT DEFAULT 'published'::text NOT NULL,
    starts_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    ends_at TIMESTAMPTZ DEFAULT (now() + INTERVAL '7 days') NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT guess_player_challenges_pkey PRIMARY KEY (id),
    CONSTRAINT guess_player_challenges_type_check CHECK (challenge_type IN ('silhouette', 'dorsal')),
    CONSTRAINT guess_player_challenges_status_check CHECK (status IN ('draft', 'published', 'archived')),
    CONSTRAINT guess_player_challenges_reward_check CHECK (reward_pearls >= 0)
);

CREATE TABLE IF NOT EXISTS public.guess_player_votes (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    challenge_id UUID NOT NULL REFERENCES public.guess_player_challenges(id) ON DELETE CASCADE,
    fan_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    selected_player_id UUID REFERENCES public.players(id) ON DELETE SET NULL,
    is_correct BOOLEAN NOT NULL,
    pearls_awarded INT DEFAULT 0 NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT guess_player_votes_pkey PRIMARY KEY (id),
    CONSTRAINT guess_player_votes_challenge_fan_unique UNIQUE (challenge_id, fan_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_guess_player_challenges_status_dates
    ON public.guess_player_challenges(status, starts_at, ends_at);

CREATE INDEX IF NOT EXISTS idx_guess_player_votes_fan
    ON public.guess_player_votes(fan_id);

CREATE INDEX IF NOT EXISTS idx_guess_player_votes_challenge
    ON public.guess_player_votes(challenge_id);

-- Enable RLS
ALTER TABLE public.guess_player_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guess_player_votes ENABLE ROW LEVEL SECURITY;

-- RLS Policies for guess_player_challenges
CREATE POLICY "Admin manages guess_player_challenges"
    ON public.guess_player_challenges
    FOR ALL
    TO authenticated
    USING (public.is_admin());

CREATE POLICY "Authenticated users view published guess_player_challenges"
    ON public.guess_player_challenges
    FOR SELECT
    TO authenticated
    USING (status = 'published');

-- RLS Policies for guess_player_votes
CREATE POLICY "Fans view own votes"
    ON public.guess_player_votes
    FOR SELECT
    TO authenticated
    USING (fan_id = auth.uid());

CREATE POLICY "Admin manages all guess_player_votes"
    ON public.guess_player_votes
    FOR ALL
    TO authenticated
    USING (public.is_admin());

-- RPC: Get active "¿Quién es?" challenges hiding target player until voted
CREATE OR REPLACE FUNCTION public.get_active_who_is_challenges()
RETURNS TABLE (
    id UUID,
    challenge_type TEXT,
    title TEXT,
    clue TEXT,
    custom_image_url TEXT,
    dorsal_number INT,
    reward_pearls INT,
    status TEXT,
    starts_at TIMESTAMPTZ,
    ends_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ,
    player_id UUID,
    player_name TEXT,
    player_photo_url TEXT,
    player_jersey_number INT,
    selected_player_id UUID,
    is_correct BOOLEAN,
    pearls_awarded INT,
    voted_at TIMESTAMPTZ,
    has_voted BOOLEAN
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
STABLE
AS $function$
    SELECT 
        c.id,
        c.challenge_type,
        c.title,
        c.clue,
        c.custom_image_url,
        c.dorsal_number,
        c.reward_pearls,
        c.status,
        c.starts_at,
        c.ends_at,
        c.created_at,
        CASE WHEN v.id IS NOT NULL THEN c.player_id ELSE NULL END AS player_id,
        CASE WHEN v.id IS NOT NULL THEN p.name ELSE NULL END AS player_name,
        CASE WHEN v.id IS NOT NULL THEN p.photo_url ELSE NULL END AS player_photo_url,
        CASE WHEN v.id IS NOT NULL THEN p.jersey_number ELSE NULL END AS player_jersey_number,
        v.selected_player_id,
        v.is_correct,
        v.pearls_awarded,
        v.created_at AS voted_at,
        (v.id IS NOT NULL) AS has_voted
    FROM public.guess_player_challenges c
    JOIN public.players p ON p.id = c.player_id
    LEFT JOIN public.guess_player_votes v ON v.challenge_id = c.id AND v.fan_id = auth.uid()
    WHERE c.status = 'published' AND now() BETWEEN c.starts_at AND c.ends_at
    ORDER BY c.created_at DESC;
$function$;

REVOKE ALL ON FUNCTION public.get_active_who_is_challenges() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_active_who_is_challenges() TO authenticated;

-- RPC: Submit vote with server-side validation and reward calculation
CREATE OR REPLACE FUNCTION public.submit_guess_player_vote(
    p_challenge_id UUID,
    p_selected_player_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_fan_id UUID := auth.uid();
    v_challenge RECORD;
    v_target_player RECORD;
    v_is_correct BOOLEAN;
    v_pearls INT := 0;
    v_vote_id UUID;
    v_today_earned INT;
    v_week_earned INT;
    v_daily_cap INT := 1000;
    v_weekly_cap INT := 5000;
    v_rem_daily INT;
    v_rem_weekly INT;
    v_effective_cap INT;
    v_today_start_caracas TIMESTAMPTZ := date_trunc('day', NOW() AT TIME ZONE 'America/Caracas') AT TIME ZONE 'America/Caracas';
    v_week_start_caracas TIMESTAMPTZ := date_trunc('week', NOW() AT TIME ZONE 'America/Caracas') AT TIME ZONE 'America/Caracas';
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Usuario no autenticado.';
    END IF;

    -- Validate active fan status
    PERFORM public.assert_active_verified_fan(v_fan_id);

    -- Load challenge
    SELECT * INTO v_challenge
    FROM public.guess_player_challenges
    WHERE id = p_challenge_id;

    IF v_challenge.id IS NULL THEN
        RAISE EXCEPTION 'El reto no existe.';
    END IF;

    IF v_challenge.status <> 'published' THEN
        RAISE EXCEPTION 'El reto no se encuentra disponible.';
    END IF;

    IF NOW() < v_challenge.starts_at THEN
        RAISE EXCEPTION 'Este reto aún no ha iniciado.';
    END IF;

    IF NOW() > v_challenge.ends_at THEN
        RAISE EXCEPTION 'Este reto ya ha finalizado.';
    END IF;

    -- Verify fan hasn't voted yet (Single participation rule)
    IF EXISTS (
        SELECT 1 FROM public.guess_player_votes
        WHERE challenge_id = p_challenge_id AND fan_id = v_fan_id
    ) THEN
        RAISE EXCEPTION 'Ya has participado en este reto.';
    END IF;

    -- Load target player info
    SELECT * INTO v_target_player
    FROM public.players
    WHERE id = v_challenge.player_id;

    -- Evaluate correctness
    v_is_correct := (v_challenge.player_id = p_selected_player_id);

    -- Calculate rewards within economy caps if correct
    IF v_is_correct AND v_challenge.reward_pearls > 0 THEN
        SELECT daily_pearl_cap, weekly_pearl_cap
        INTO v_daily_cap, v_weekly_cap
        FROM public.economy_settings
        LIMIT 1;

        SELECT COALESCE(SUM(amount), 0) INTO v_today_earned
        FROM ledger_entries
        WHERE fan_id = v_fan_id
          AND amount > 0
          AND status IN ('confirmed', 'held')
          AND (created_at AT TIME ZONE 'America/Caracas') >= v_today_start_caracas;

        SELECT COALESCE(SUM(amount), 0) INTO v_week_earned
        FROM ledger_entries
        WHERE fan_id = v_fan_id
          AND amount > 0
          AND status IN ('confirmed', 'held')
          AND (created_at AT TIME ZONE 'America/Caracas') >= v_week_start_caracas;

        v_rem_daily := GREATEST(0, COALESCE(v_daily_cap, 1000) - v_today_earned);
        v_rem_weekly := GREATEST(0, COALESCE(v_weekly_cap, 5000) - v_week_earned);
        v_effective_cap := LEAST(v_rem_daily, v_rem_weekly);

        v_pearls := LEAST(v_challenge.reward_pearls, v_effective_cap);

        IF v_pearls > 0 THEN
            INSERT INTO public.ledger_entries (
                fan_id, amount, type, status, source_type, source_id, note
            ) VALUES (
                v_fan_id, v_pearls, 'trivia_reward', 'confirmed', 'who_is_challenge', p_challenge_id::text,
                'Premio por acertar ¿Quién es?: ' || v_challenge.title
            );

            INSERT INTO public.wallets (fan_id, balance_cache)
            VALUES (v_fan_id, v_pearls)
            ON CONFLICT (fan_id)
            DO UPDATE SET balance_cache = wallets.balance_cache + v_pearls, updated_at = NOW();

            PERFORM public.calculate_and_apply_streak_bonus(v_fan_id);
        END IF;
    END IF;

    -- Record single participation vote
    INSERT INTO public.guess_player_votes (
        challenge_id, fan_id, selected_player_id, is_correct, pearls_awarded
    ) VALUES (
        p_challenge_id, v_fan_id, p_selected_player_id, v_is_correct, v_pearls
    ) RETURNING id INTO v_vote_id;

    RETURN jsonb_build_object(
        'vote_id', v_vote_id,
        'is_correct', v_is_correct,
        'pearls_awarded', v_pearls,
        'correct_player', jsonb_build_object(
            'id', v_target_player.id,
            'name', v_target_player.name,
            'jersey_number', v_target_player.jersey_number,
            'photo_url', v_target_player.photo_url,
            'position', v_target_player.position
        )
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.submit_guess_player_vote(UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_guess_player_vote(UUID, UUID) TO authenticated;

-- Admin RPC: Upsert challenge
CREATE OR REPLACE FUNCTION public.admin_upsert_guess_player_challenge(p_challenge jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_challenge_id UUID;
    v_player_id UUID;
    v_dorsal INT;
BEGIN
    PERFORM public.assert_admin();

    v_challenge_id := (p_challenge->>'id')::UUID;
    v_player_id := (p_challenge->>'player_id')::UUID;

    IF v_player_id IS NULL THEN
        RAISE EXCEPTION 'Debe seleccionar un jugador de la plantilla.';
    END IF;

    v_dorsal := (p_challenge->>'dorsal_number')::INT;
    IF v_dorsal IS NULL THEN
        SELECT jersey_number INTO v_dorsal FROM public.players WHERE id = v_player_id;
    END IF;

    IF v_challenge_id IS NULL THEN
        INSERT INTO public.guess_player_challenges (
            player_id,
            challenge_type,
            title,
            clue,
            custom_image_url,
            dorsal_number,
            reward_pearls,
            status,
            starts_at,
            ends_at
        ) VALUES (
            v_player_id,
            COALESCE(p_challenge->>'challenge_type', 'silhouette'),
            COALESCE(NULLIF(TRIM(p_challenge->>'title'), ''), '¿Quién es este jugador?'),
            NULLIF(TRIM(p_challenge->>'clue'), ''),
            NULLIF(TRIM(p_challenge->>'custom_image_url'), ''),
            v_dorsal,
            COALESCE((p_challenge->>'reward_pearls')::INT, 50),
            COALESCE(p_challenge->>'status', 'published'),
            COALESCE((p_challenge->>'starts_at')::TIMESTAMPTZ, NOW()),
            COALESCE((p_challenge->>'ends_at')::TIMESTAMPTZ, NOW() + INTERVAL '7 days')
        ) RETURNING id INTO v_challenge_id;
    ELSE
        UPDATE public.guess_player_challenges SET
            player_id = v_player_id,
            challenge_type = COALESCE(p_challenge->>'challenge_type', challenge_type),
            title = COALESCE(NULLIF(TRIM(p_challenge->>'title'), ''), title),
            clue = CASE WHEN p_challenge ? 'clue' THEN NULLIF(TRIM(p_challenge->>'clue'), '') ELSE clue END,
            custom_image_url = CASE WHEN p_challenge ? 'custom_image_url' THEN NULLIF(TRIM(p_challenge->>'custom_image_url'), '') ELSE custom_image_url END,
            dorsal_number = COALESCE(v_dorsal, dorsal_number),
            reward_pearls = COALESCE((p_challenge->>'reward_pearls')::INT, reward_pearls),
            status = COALESCE(p_challenge->>'status', status),
            starts_at = COALESCE((p_challenge->>'starts_at')::TIMESTAMPTZ, starts_at),
            ends_at = COALESCE((p_challenge->>'ends_at')::TIMESTAMPTZ, ends_at)
        WHERE id = v_challenge_id;
    END IF;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (v_admin_id, 'upsert_guess_player_challenge', 'guess_player_challenges', v_challenge_id::text, p_challenge);

    RETURN jsonb_build_object('id', v_challenge_id, 'status', 'success');
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_upsert_guess_player_challenge(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_upsert_guess_player_challenge(jsonb) TO authenticated;

-- Admin RPC: Delete challenge
CREATE OR REPLACE FUNCTION public.admin_delete_guess_player_challenge(p_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
BEGIN
    PERFORM public.assert_admin();

    DELETE FROM public.guess_player_challenges WHERE id = p_id;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id)
    VALUES (v_admin_id, 'delete_guess_player_challenge', 'guess_player_challenges', p_id::text);

    RETURN jsonb_build_object('id', p_id, 'status', 'deleted');
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_delete_guess_player_challenge(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_delete_guess_player_challenge(UUID) TO authenticated;
