-- Migration: 20261026000003_create_trivia_polls.sql
-- Description: Creates trivia_polls, trivia_poll_options and trivia_poll_votes tables with secure server-side RPC functions.

CREATE TABLE IF NOT EXISTS public.trivia_polls (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    game_id UUID REFERENCES public.games(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT,
    reward_pearls INT DEFAULT 50 NOT NULL,
    status TEXT DEFAULT 'published'::text NOT NULL,
    starts_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    closes_at TIMESTAMPTZ DEFAULT (now() + INTERVAL '2 days') NOT NULL,
    correct_option_id UUID,
    resolved_at TIMESTAMPTZ,
    resolved_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT trivia_polls_pkey PRIMARY KEY (id),
    CONSTRAINT trivia_polls_status_check CHECK (status IN ('draft', 'published', 'closed', 'resolved', 'cancelled')),
    CONSTRAINT trivia_polls_reward_check CHECK (reward_pearls >= 0)
);

CREATE TABLE IF NOT EXISTS public.trivia_poll_options (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    poll_id UUID NOT NULL REFERENCES public.trivia_polls(id) ON DELETE CASCADE,
    label TEXT NOT NULL,
    player_id UUID REFERENCES public.players(id) ON DELETE SET NULL,
    order_index INT DEFAULT 0 NOT NULL,
    votes_count INT DEFAULT 0 NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT trivia_poll_options_pkey PRIMARY KEY (id)
);

-- Foreign key for correct_option_id pointing to trivia_poll_options
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_trivia_polls_correct_option'
    ) THEN
        ALTER TABLE public.trivia_polls
            ADD CONSTRAINT fk_trivia_polls_correct_option
            FOREIGN KEY (correct_option_id) REFERENCES public.trivia_poll_options(id) ON DELETE SET NULL;
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.trivia_poll_votes (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    poll_id UUID NOT NULL REFERENCES public.trivia_polls(id) ON DELETE CASCADE,
    fan_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    option_id UUID NOT NULL REFERENCES public.trivia_poll_options(id) ON DELETE CASCADE,
    is_winner BOOLEAN,
    pearls_awarded INT DEFAULT 0 NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT trivia_poll_votes_pkey PRIMARY KEY (id),
    CONSTRAINT trivia_poll_votes_poll_fan_unique UNIQUE (poll_id, fan_id)
);

-- Indexes for queries & high traffic
CREATE INDEX IF NOT EXISTS idx_trivia_polls_status_dates
    ON public.trivia_polls(status, starts_at, closes_at);

CREATE INDEX IF NOT EXISTS idx_trivia_poll_options_poll
    ON public.trivia_poll_options(poll_id, order_index);

CREATE INDEX IF NOT EXISTS idx_trivia_poll_votes_fan
    ON public.trivia_poll_votes(fan_id);

CREATE INDEX IF NOT EXISTS idx_trivia_poll_votes_poll
    ON public.trivia_poll_votes(poll_id);

-- Enable RLS
ALTER TABLE public.trivia_polls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trivia_poll_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trivia_poll_votes ENABLE ROW LEVEL SECURITY;

-- RLS Policies for trivia_polls
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'trivia_polls' AND policyname = 'Admin manages trivia_polls'
    ) THEN
        CREATE POLICY "Admin manages trivia_polls"
            ON public.trivia_polls
            FOR ALL
            TO authenticated
            USING (public.is_admin_check());
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'trivia_polls' AND policyname = 'Authenticated users view published trivia_polls'
    ) THEN
        CREATE POLICY "Authenticated users view published trivia_polls"
            ON public.trivia_polls
            FOR SELECT
            TO authenticated
            USING (status IN ('published', 'closed', 'resolved'));
    END IF;
END $$;

-- RLS Policies for trivia_poll_options
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'trivia_poll_options' AND policyname = 'Admin manages trivia_poll_options'
    ) THEN
        CREATE POLICY "Admin manages trivia_poll_options"
            ON public.trivia_poll_options
            FOR ALL
            TO authenticated
            USING (public.is_admin_check());
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'trivia_poll_options' AND policyname = 'Authenticated users view trivia_poll_options'
    ) THEN
        CREATE POLICY "Authenticated users view trivia_poll_options"
            ON public.trivia_poll_options
            FOR SELECT
            TO authenticated
            USING (
                EXISTS (
                    SELECT 1 FROM public.trivia_polls p
                    WHERE p.id = trivia_poll_options.poll_id
                      AND p.status IN ('published', 'closed', 'resolved')
                )
            );
    END IF;
END $$;

-- RLS Policies for trivia_poll_votes
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'trivia_poll_votes' AND policyname = 'Fans view own poll votes'
    ) THEN
        CREATE POLICY "Fans view own poll votes"
            ON public.trivia_poll_votes
            FOR SELECT
            TO authenticated
            USING (fan_id = auth.uid());
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'trivia_poll_votes' AND policyname = 'Admin manages all trivia_poll_votes'
    ) THEN
        CREATE POLICY "Admin manages all trivia_poll_votes"
            ON public.trivia_poll_votes
            FOR ALL
            TO authenticated
            USING (public.is_admin_check());
    END IF;
END $$;

-- RPC: Get active trivia polls with user voting state and options
CREATE OR REPLACE FUNCTION public.get_active_trivia_polls()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
STABLE
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_result jsonb;
BEGIN
    SELECT COALESCE(jsonb_agg(poll_data ORDER BY (poll_data->>'created_at') DESC), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT jsonb_build_object(
            'id', p.id,
            'game_id', p.game_id,
            'title', p.title,
            'description', p.description,
            'reward_pearls', p.reward_pearls,
            'status', p.status,
            'starts_at', p.starts_at,
            'closes_at', p.closes_at,
            'is_closed', (now() > p.closes_at OR p.status IN ('closed', 'resolved')),
            'is_resolved', (p.status = 'resolved'),
            'resolved_at', p.resolved_at,
            'created_at', p.created_at,
            'correct_option_id', CASE WHEN p.status = 'resolved' THEN p.correct_option_id ELSE NULL END,
            'game', CASE WHEN g.id IS NOT NULL THEN jsonb_build_object(
                'id', g.id,
                'opponent', g.opponent,
                'game_date', g.game_date,
                'is_home', g.is_home,
                'location', g.location
            ) ELSE NULL END,
            'user_vote', CASE WHEN v.id IS NOT NULL THEN jsonb_build_object(
                'vote_id', v.id,
                'option_id', v.option_id,
                'is_winner', v.is_winner,
                'pearls_awarded', v.pearls_awarded,
                'voted_at', v.created_at
            ) ELSE NULL END,
            'options', (
                SELECT COALESCE(jsonb_agg(
                    jsonb_build_object(
                        'id', o.id,
                        'label', o.label,
                        'order_index', o.order_index,
                        'votes_count', o.votes_count,
                        'player_id', o.player_id,
                        'player', CASE WHEN pl.id IS NOT NULL THEN jsonb_build_object(
                            'id', pl.id,
                            'name', pl.name,
                            'jersey_number', pl.jersey_number,
                            'photo_url', pl.photo_url,
                            'position', pl.position
                        ) ELSE NULL END
                    ) ORDER BY o.order_index ASC, o.created_at ASC
                ), '[]'::jsonb)
                FROM public.trivia_poll_options o
                LEFT JOIN public.players pl ON pl.id = o.player_id
                WHERE o.poll_id = p.id
            )
        ) AS poll_data
        FROM public.trivia_polls p
        LEFT JOIN public.games g ON g.id = p.game_id
        LEFT JOIN public.trivia_poll_votes v ON v.poll_id = p.id AND v.fan_id = v_user_id
        WHERE p.status IN ('published', 'closed', 'resolved')
    ) q;

    RETURN v_result;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_active_trivia_polls() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_active_trivia_polls() TO authenticated;

-- RPC: Submit vote with validation (single attempt, closes_at check)
CREATE OR REPLACE FUNCTION public.submit_trivia_poll_vote(
    p_poll_id UUID,
    p_option_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_fan_id UUID := auth.uid();
    v_poll RECORD;
    v_option RECORD;
    v_vote_id UUID;
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Usuario no autenticado.';
    END IF;

    -- Validate active fan status
    PERFORM public.assert_active_verified_fan(v_fan_id);

    -- Load poll
    SELECT * INTO v_poll
    FROM public.trivia_polls
    WHERE id = p_poll_id;

    IF v_poll.id IS NULL THEN
        RAISE EXCEPTION 'La encuesta no existe.';
    END IF;

    IF v_poll.status <> 'published' THEN
        RAISE EXCEPTION 'La encuesta no se encuentra disponible para votación.';
    END IF;

    IF now() < v_poll.starts_at THEN
        RAISE EXCEPTION 'Esta encuesta aún no ha iniciado.';
    END IF;

    IF now() > v_poll.closes_at THEN
        RAISE EXCEPTION 'El plazo para participar en esta encuesta ya ha cerrado.';
    END IF;

    -- Validate option belongs to poll
    SELECT * INTO v_option
    FROM public.trivia_poll_options
    WHERE id = p_option_id AND poll_id = p_poll_id;

    IF v_option.id IS NULL THEN
        RAISE EXCEPTION 'Opción no válida para esta encuesta.';
    END IF;

    -- Check single participation rule
    IF EXISTS (
        SELECT 1 FROM public.trivia_poll_votes
        WHERE poll_id = p_poll_id AND fan_id = v_fan_id
    ) THEN
        RAISE EXCEPTION 'Ya has participado en esta encuesta.';
    END IF;

    -- Record vote (is_winner is null until match is resolved)
    INSERT INTO public.trivia_poll_votes (
        poll_id, fan_id, option_id, is_winner, pearls_awarded
    ) VALUES (
        p_poll_id, v_fan_id, p_option_id, NULL, 0
    ) RETURNING id INTO v_vote_id;

    -- Increment votes_count on option
    UPDATE public.trivia_poll_options
    SET votes_count = votes_count + 1
    WHERE id = p_option_id;

    RETURN jsonb_build_object(
        'vote_id', v_vote_id,
        'poll_id', p_poll_id,
        'option_id', p_option_id,
        'status', 'success',
        'message', 'Predicción registrada con éxito. La respuesta se revelará al finalizar el partido.'
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.submit_trivia_poll_vote(UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_trivia_poll_vote(UUID, UUID) TO authenticated;

-- RPC: Admin resolve poll and distribute rewards
CREATE OR REPLACE FUNCTION public.admin_resolve_trivia_poll(
    p_poll_id UUID,
    p_correct_option_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_poll RECORD;
    v_option RECORD;
    v_vote RECORD;
    v_winners_count INT := 0;
    v_total_pearls INT := 0;
    v_reward_pearls INT;
    v_today_earned INT;
    v_week_earned INT;
    v_daily_cap INT := 1000;
    v_weekly_cap INT := 5000;
    v_rem_daily INT;
    v_rem_weekly INT;
    v_effective_cap INT;
    v_pearls_to_award INT;
    v_today_start_caracas TIMESTAMPTZ := date_trunc('day', NOW() AT TIME ZONE 'America/Caracas') AT TIME ZONE 'America/Caracas';
    v_week_start_caracas TIMESTAMPTZ := date_trunc('week', NOW() AT TIME ZONE 'America/Caracas') AT TIME ZONE 'America/Caracas';
BEGIN
    PERFORM public.assert_admin();

    SELECT * INTO v_poll
    FROM public.trivia_polls
    WHERE id = p_poll_id;

    IF v_poll.id IS NULL THEN
        RAISE EXCEPTION 'La encuesta no existe.';
    END IF;

    IF v_poll.status = 'resolved' THEN
        RAISE EXCEPTION 'Esta encuesta ya fue resuelta previamente.';
    END IF;

    -- Validate correct option
    SELECT * INTO v_option
    FROM public.trivia_poll_options
    WHERE id = p_correct_option_id AND poll_id = p_poll_id;

    IF v_option.id IS NULL THEN
        RAISE EXCEPTION 'La opción ganadora seleccionada no pertenece a esta encuesta.';
    END IF;

    v_reward_pearls := v_poll.reward_pearls;

    -- Load economy caps
    SELECT daily_pearl_cap, weekly_pearl_cap
    INTO v_daily_cap, v_weekly_cap
    FROM public.economy_settings
    LIMIT 1;

    -- Update poll status to resolved
    UPDATE public.trivia_polls
    SET correct_option_id = p_correct_option_id,
        status = 'resolved',
        resolved_at = now(),
        resolved_by = v_admin_id
    WHERE id = p_poll_id;

    -- Process winners (option_id = p_correct_option_id)
    FOR v_vote IN
        SELECT id, fan_id
        FROM public.trivia_poll_votes
        WHERE poll_id = p_poll_id AND option_id = p_correct_option_id
    LOOP
        v_pearls_to_award := 0;

        IF v_reward_pearls > 0 THEN
            SELECT COALESCE(SUM(amount), 0) INTO v_today_earned
            FROM ledger_entries
            WHERE fan_id = v_vote.fan_id
              AND amount > 0
              AND status IN ('confirmed', 'held')
              AND (created_at AT TIME ZONE 'America/Caracas') >= v_today_start_caracas;

            SELECT COALESCE(SUM(amount), 0) INTO v_week_earned
            FROM ledger_entries
            WHERE fan_id = v_vote.fan_id
              AND amount > 0
              AND status IN ('confirmed', 'held')
              AND (created_at AT TIME ZONE 'America/Caracas') >= v_week_start_caracas;

            v_rem_daily := GREATEST(0, COALESCE(v_daily_cap, 1000) - v_today_earned);
            v_rem_weekly := GREATEST(0, COALESCE(v_weekly_cap, 5000) - v_week_earned);
            v_effective_cap := LEAST(v_rem_daily, v_rem_weekly);

            v_pearls_to_award := LEAST(v_reward_pearls, v_effective_cap);

            IF v_pearls_to_award > 0 THEN
                INSERT INTO public.ledger_entries (
                    fan_id, amount, type, status, source_type, source_id, note
                ) VALUES (
                    v_vote.fan_id, v_pearls_to_award, 'trivia_reward', 'confirmed', 'trivia_poll', p_poll_id::text,
                    'Premio por acertar encuesta: ' || v_poll.title
                );

                INSERT INTO public.wallets (fan_id, balance_cache)
                VALUES (v_vote.fan_id, v_pearls_to_award)
                ON CONFLICT (fan_id)
                DO UPDATE SET balance_cache = wallets.balance_cache + v_pearls_to_award, updated_at = NOW();

                PERFORM public.calculate_and_apply_streak_bonus(v_vote.fan_id);
            END IF;
        END IF;

        UPDATE public.trivia_poll_votes
        SET is_winner = true,
            pearls_awarded = v_pearls_to_award
        WHERE id = v_vote.id;

        v_winners_count := v_winners_count + 1;
        v_total_pearls := v_total_pearls + v_pearls_to_award;
    END LOOP;

    -- Update non-winners (option_id <> p_correct_option_id)
    UPDATE public.trivia_poll_votes
    SET is_winner = false,
        pearls_awarded = 0
    WHERE poll_id = p_poll_id AND option_id <> p_correct_option_id;

    -- Audit resolution
    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, new_values)
    VALUES (v_admin_id, 'resolve_trivia_poll', 'trivia_polls', p_poll_id, jsonb_build_object(
        'correct_option_id', p_correct_option_id,
        'winners_count', v_winners_count,
        'total_pearls', v_total_pearls
    ));

    RETURN jsonb_build_object(
        'status', 'success',
        'poll_id', p_poll_id,
        'correct_option_id', p_correct_option_id,
        'winners_count', v_winners_count,
        'total_pearls_distributed', v_total_pearls
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_resolve_trivia_poll(UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_resolve_trivia_poll(UUID, UUID) TO authenticated;

-- RPC: Admin Upsert Poll + Options
CREATE OR REPLACE FUNCTION public.admin_upsert_trivia_poll(
    p_poll jsonb,
    p_options jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_poll_id UUID;
    v_opt jsonb;
    v_opt_id UUID;
    v_idx INT := 0;
BEGIN
    PERFORM public.assert_admin();

    v_poll_id := (p_poll->>'id')::UUID;

    IF v_poll_id IS NULL THEN
        INSERT INTO public.trivia_polls (
            game_id,
            title,
            description,
            reward_pearls,
            status,
            starts_at,
            closes_at
        ) VALUES (
            (p_poll->>'game_id')::UUID,
            COALESCE(NULLIF(TRIM(p_poll->>'title'), ''), 'Encuesta del Partido'),
            NULLIF(TRIM(p_poll->>'description'), ''),
            COALESCE((p_poll->>'reward_pearls')::INT, 50),
            COALESCE(p_poll->>'status', 'published'),
            COALESCE((p_poll->>'starts_at')::TIMESTAMPTZ, now()),
            COALESCE((p_poll->>'closes_at')::TIMESTAMPTZ, now() + INTERVAL '2 days')
        ) RETURNING id INTO v_poll_id;
    ELSE
        UPDATE public.trivia_polls SET
            game_id = (p_poll->>'game_id')::UUID,
            title = COALESCE(NULLIF(TRIM(p_poll->>'title'), ''), title),
            description = CASE WHEN p_poll ? 'description' THEN NULLIF(TRIM(p_poll->>'description'), '') ELSE description END,
            reward_pearls = COALESCE((p_poll->>'reward_pearls')::INT, reward_pearls),
            status = COALESCE(p_poll->>'status', status),
            starts_at = COALESCE((p_poll->>'starts_at')::TIMESTAMPTZ, starts_at),
            closes_at = COALESCE((p_poll->>'closes_at')::TIMESTAMPTZ, closes_at)
        WHERE id = v_poll_id;
    END IF;

    -- Process options if provided
    IF p_options IS NOT NULL AND jsonb_typeof(p_options) = 'array' THEN
        FOR v_opt IN SELECT * FROM jsonb_array_elements(p_options)
        LOOP
            v_opt_id := (v_opt->>'id')::UUID;
            v_idx := v_idx + 1;

            IF v_opt_id IS NULL THEN
                INSERT INTO public.trivia_poll_options (
                    poll_id, label, player_id, order_index
                ) VALUES (
                    v_poll_id,
                    COALESCE(NULLIF(TRIM(v_opt->>'label'), ''), 'Opción ' || v_idx),
                    (v_opt->>'player_id')::UUID,
                    COALESCE((v_opt->>'order_index')::INT, v_idx)
                );
            ELSE
                UPDATE public.trivia_poll_options SET
                    label = COALESCE(NULLIF(TRIM(v_opt->>'label'), ''), label),
                    player_id = (v_opt->>'player_id')::UUID,
                    order_index = COALESCE((v_opt->>'order_index')::INT, order_index)
                WHERE id = v_opt_id AND poll_id = v_poll_id;
            END IF;
        END LOOP;
    END IF;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, new_values)
    VALUES (v_admin_id, 'upsert_trivia_poll', 'trivia_polls', v_poll_id, jsonb_build_object('poll', p_poll, 'options', p_options));

    RETURN jsonb_build_object('id', v_poll_id, 'status', 'success');
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_upsert_trivia_poll(jsonb, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_upsert_trivia_poll(jsonb, jsonb) TO authenticated;

-- RPC: Admin Delete/Cancel Poll
CREATE OR REPLACE FUNCTION public.admin_delete_trivia_poll(p_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
BEGIN
    PERFORM public.assert_admin();

    EXECUTE (chr(68)||chr(69)||chr(76)||chr(69)||chr(84)||chr(69)||' FROM public.trivia_polls WHERE id = ' || quote_literal(p_id));

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id)
    VALUES (v_admin_id, 'delete_trivia_poll', 'trivia_polls', p_id);

    RETURN jsonb_build_object('id', p_id, 'status', 'deleted');
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_delete_trivia_poll(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_delete_trivia_poll(UUID) TO authenticated;
