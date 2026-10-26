-- Migration: 20261026000004_create_extended_trivias.sql
-- Description: Creates 5 new interactive trivia modalities:
-- 1. Over/Under (Mayor o Menor de Estadísticas)
-- 2. Mystery Play («¿Qué pasó después?»)
-- 3. Exact Score Prediction (Adivina el Marcador)
-- 4. Flash Trivia 60s (Contrarreloj)
-- 5. Progressive Clues (Pistas Progresivas / Jugador Misterioso)
-- Rules: Single attempt enforced ONLY upon final submission (exiting never consumes attempts),
-- atomic reward distribution through ledger_entries + wallets, zero client answer exposure.

-- ============================================================================
-- 1. MODALIDAD 1: OVER / UNDER (MAYOR O MENOR)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.over_under_predictions (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    game_id UUID REFERENCES public.games(id) ON DELETE SET NULL,
    player_id UUID REFERENCES public.players(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT,
    stat_type TEXT DEFAULT 'points'::text NOT NULL,
    line_value NUMERIC(6, 1) NOT NULL,
    reward_pearls INT DEFAULT 40 NOT NULL,
    status TEXT DEFAULT 'published'::text NOT NULL,
    starts_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    closes_at TIMESTAMPTZ DEFAULT (now() + INTERVAL '2 days') NOT NULL,
    actual_value NUMERIC(6, 1),
    winning_choice TEXT,
    resolved_at TIMESTAMPTZ,
    resolved_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT over_under_predictions_pkey PRIMARY KEY (id),
    CONSTRAINT over_under_status_check CHECK (status IN ('draft', 'published', 'closed', 'resolved', 'cancelled')),
    CONSTRAINT over_under_winning_choice_check CHECK (winning_choice IS NULL OR winning_choice IN ('over', 'under', 'push')),
    CONSTRAINT over_under_reward_check CHECK (reward_pearls >= 0)
);

CREATE TABLE IF NOT EXISTS public.over_under_votes (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    prediction_id UUID NOT NULL REFERENCES public.over_under_predictions(id) ON DELETE CASCADE,
    fan_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    choice TEXT NOT NULL,
    is_winner BOOLEAN,
    pearls_awarded INT DEFAULT 0 NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT over_under_votes_pkey PRIMARY KEY (id),
    CONSTRAINT over_under_choice_check CHECK (choice IN ('over', 'under')),
    CONSTRAINT over_under_votes_fan_unique UNIQUE (prediction_id, fan_id)
);

CREATE INDEX IF NOT EXISTS idx_over_under_status_dates ON public.over_under_predictions(status, starts_at, closes_at);
CREATE INDEX IF NOT EXISTS idx_over_under_votes_fan ON public.over_under_votes(fan_id);
CREATE INDEX IF NOT EXISTS idx_over_under_votes_pred ON public.over_under_votes(prediction_id);

ALTER TABLE public.over_under_predictions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.over_under_votes ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'over_under_predictions' AND policyname = 'Admin manages over_under_predictions') THEN
        CREATE POLICY "Admin manages over_under_predictions" ON public.over_under_predictions FOR ALL TO authenticated USING (public.is_admin_check());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'over_under_predictions' AND policyname = 'Authenticated view published over_under') THEN
        CREATE POLICY "Authenticated view published over_under" ON public.over_under_predictions FOR SELECT TO authenticated USING (status IN ('published', 'closed', 'resolved'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'over_under_votes' AND policyname = 'Fans view own over_under votes') THEN
        CREATE POLICY "Fans view own over_under votes" ON public.over_under_votes FOR SELECT TO authenticated USING (fan_id = auth.uid());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'over_under_votes' AND policyname = 'Admin manages all over_under votes') THEN
        CREATE POLICY "Admin manages all over_under votes" ON public.over_under_votes FOR ALL TO authenticated USING (public.is_admin_check());
    END IF;
END $$;

-- ============================================================================
-- 2. MODALIDAD 2: «¿QUÉ PASÓ DESPUÉS?» (LA JUGADA MISTERIOSA)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.mystery_play_challenges (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    game_id UUID REFERENCES public.games(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT,
    video_url TEXT,
    cover_image_url TEXT,
    question TEXT NOT NULL,
    option_a TEXT NOT NULL,
    option_b TEXT NOT NULL,
    option_c TEXT NOT NULL,
    option_d TEXT NOT NULL,
    correct_option TEXT NOT NULL,
    reveal_video_url TEXT,
    reward_pearls INT DEFAULT 50 NOT NULL,
    status TEXT DEFAULT 'published'::text NOT NULL,
    starts_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    closes_at TIMESTAMPTZ DEFAULT (now() + INTERVAL '3 days') NOT NULL,
    resolved_at TIMESTAMPTZ,
    resolved_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT mystery_play_challenges_pkey PRIMARY KEY (id),
    CONSTRAINT mystery_play_status_check CHECK (status IN ('draft', 'published', 'closed', 'resolved', 'cancelled')),
    CONSTRAINT mystery_play_correct_option_check CHECK (correct_option IN ('A', 'B', 'C', 'D')),
    CONSTRAINT mystery_play_reward_check CHECK (reward_pearls >= 0)
);

CREATE TABLE IF NOT EXISTS public.mystery_play_votes (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    challenge_id UUID NOT NULL REFERENCES public.mystery_play_challenges(id) ON DELETE CASCADE,
    fan_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    selected_option TEXT NOT NULL,
    is_correct BOOLEAN NOT NULL,
    pearls_awarded INT DEFAULT 0 NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT mystery_play_votes_pkey PRIMARY KEY (id),
    CONSTRAINT mystery_play_selected_check CHECK (selected_option IN ('A', 'B', 'C', 'D')),
    CONSTRAINT mystery_play_votes_fan_unique UNIQUE (challenge_id, fan_id)
);

CREATE INDEX IF NOT EXISTS idx_mystery_play_status_dates ON public.mystery_play_challenges(status, starts_at, closes_at);
CREATE INDEX IF NOT EXISTS idx_mystery_play_votes_fan ON public.mystery_play_votes(fan_id);
CREATE INDEX IF NOT EXISTS idx_mystery_play_votes_chal ON public.mystery_play_votes(challenge_id);

ALTER TABLE public.mystery_play_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mystery_play_votes ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'mystery_play_challenges' AND policyname = 'Admin manages mystery_play_challenges') THEN
        CREATE POLICY "Admin manages mystery_play_challenges" ON public.mystery_play_challenges FOR ALL TO authenticated USING (public.is_admin_check());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'mystery_play_challenges' AND policyname = 'Authenticated view published mystery plays') THEN
        CREATE POLICY "Authenticated view published mystery plays" ON public.mystery_play_challenges FOR SELECT TO authenticated USING (status IN ('published', 'closed', 'resolved'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'mystery_play_votes' AND policyname = 'Fans view own mystery play votes') THEN
        CREATE POLICY "Fans view own mystery play votes" ON public.mystery_play_votes FOR SELECT TO authenticated USING (fan_id = auth.uid());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'mystery_play_votes' AND policyname = 'Admin manages all mystery play votes') THEN
        CREATE POLICY "Admin manages all mystery play votes" ON public.mystery_play_votes FOR ALL TO authenticated USING (public.is_admin_check());
    END IF;
END $$;

-- ============================================================================
-- 3. MODALIDAD 3: ADIVINA EL MARCADOR EXACTO
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.score_predictions (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    game_id UUID NOT NULL REFERENCES public.games(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    exact_reward_pearls INT DEFAULT 200 NOT NULL,
    closest_reward_pearls INT DEFAULT 50 NOT NULL,
    status TEXT DEFAULT 'published'::text NOT NULL,
    starts_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    closes_at TIMESTAMPTZ DEFAULT (now() + INTERVAL '2 days') NOT NULL,
    final_guaiqueries_score INT,
    final_rival_score INT,
    resolved_at TIMESTAMPTZ,
    resolved_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT score_predictions_pkey PRIMARY KEY (id),
    CONSTRAINT score_predictions_status_check CHECK (status IN ('draft', 'published', 'closed', 'resolved', 'cancelled')),
    CONSTRAINT score_predictions_reward_check CHECK (exact_reward_pearls >= 0 AND closest_reward_pearls >= 0)
);

CREATE TABLE IF NOT EXISTS public.score_prediction_votes (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    prediction_id UUID NOT NULL REFERENCES public.score_predictions(id) ON DELETE CASCADE,
    fan_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    predicted_guaiqueries_score INT NOT NULL,
    predicted_rival_score INT NOT NULL,
    is_exact_match BOOLEAN,
    is_closest_match BOOLEAN,
    pearls_awarded INT DEFAULT 0 NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT score_prediction_votes_pkey PRIMARY KEY (id),
    CONSTRAINT score_pred_scores_check CHECK (predicted_guaiqueries_score >= 0 AND predicted_rival_score >= 0),
    CONSTRAINT score_prediction_votes_fan_unique UNIQUE (prediction_id, fan_id)
);

CREATE INDEX IF NOT EXISTS idx_score_pred_status_dates ON public.score_predictions(status, starts_at, closes_at);
CREATE INDEX IF NOT EXISTS idx_score_pred_votes_fan ON public.score_prediction_votes(fan_id);
CREATE INDEX IF NOT EXISTS idx_score_pred_votes_pred ON public.score_prediction_votes(prediction_id);

ALTER TABLE public.score_predictions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.score_prediction_votes ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'score_predictions' AND policyname = 'Admin manages score_predictions') THEN
        CREATE POLICY "Admin manages score_predictions" ON public.score_predictions FOR ALL TO authenticated USING (public.is_admin_check());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'score_predictions' AND policyname = 'Authenticated view published score predictions') THEN
        CREATE POLICY "Authenticated view published score predictions" ON public.score_predictions FOR SELECT TO authenticated USING (status IN ('published', 'closed', 'resolved'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'score_prediction_votes' AND policyname = 'Fans view own score prediction votes') THEN
        CREATE POLICY "Fans view own score prediction votes" ON public.score_prediction_votes FOR SELECT TO authenticated USING (fan_id = auth.uid());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'score_prediction_votes' AND policyname = 'Admin manages all score prediction votes') THEN
        CREATE POLICY "Admin manages all score prediction votes" ON public.score_prediction_votes FOR ALL TO authenticated USING (public.is_admin_check());
    END IF;
END $$;

-- ============================================================================
-- 4. MODALIDAD 4: TRIVIA FLASH CONTRARRELOJ (60 SEGUNDOS)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.flash_trivia_challenges (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    time_limit_seconds INT DEFAULT 60 NOT NULL,
    pearls_per_correct INT DEFAULT 10 NOT NULL,
    status TEXT DEFAULT 'published'::text NOT NULL,
    starts_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    closes_at TIMESTAMPTZ DEFAULT (now() + INTERVAL '7 days') NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT flash_trivia_challenges_pkey PRIMARY KEY (id),
    CONSTRAINT flash_trivia_status_check CHECK (status IN ('draft', 'published', 'closed', 'archived')),
    CONSTRAINT flash_trivia_time_check CHECK (time_limit_seconds > 0)
);

CREATE TABLE IF NOT EXISTS public.flash_trivia_questions (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    challenge_id UUID NOT NULL REFERENCES public.flash_trivia_challenges(id) ON DELETE CASCADE,
    question TEXT NOT NULL,
    option_a TEXT NOT NULL,
    option_b TEXT NOT NULL,
    option_c TEXT,
    option_d TEXT,
    correct_option TEXT NOT NULL,
    order_index INT DEFAULT 0 NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT flash_trivia_questions_pkey PRIMARY KEY (id),
    CONSTRAINT flash_trivia_correct_option_check CHECK (correct_option IN ('A', 'B', 'C', 'D'))
);

CREATE TABLE IF NOT EXISTS public.flash_trivia_attempts (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    challenge_id UUID NOT NULL REFERENCES public.flash_trivia_challenges(id) ON DELETE CASCADE,
    fan_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    correct_count INT DEFAULT 0 NOT NULL,
    total_answered INT DEFAULT 0 NOT NULL,
    time_spent_seconds INT DEFAULT 0 NOT NULL,
    pearls_awarded INT DEFAULT 0 NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT flash_trivia_attempts_pkey PRIMARY KEY (id),
    CONSTRAINT flash_trivia_fan_unique UNIQUE (challenge_id, fan_id)
);

CREATE INDEX IF NOT EXISTS idx_flash_trivia_chal_status ON public.flash_trivia_challenges(status, starts_at, closes_at);
CREATE INDEX IF NOT EXISTS idx_flash_trivia_q_chal ON public.flash_trivia_questions(challenge_id, order_index);
CREATE INDEX IF NOT EXISTS idx_flash_trivia_attempts_fan ON public.flash_trivia_attempts(fan_id);
CREATE INDEX IF NOT EXISTS idx_flash_trivia_attempts_chal ON public.flash_trivia_attempts(challenge_id);

ALTER TABLE public.flash_trivia_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.flash_trivia_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.flash_trivia_attempts ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'flash_trivia_challenges' AND policyname = 'Admin manages flash_trivia_challenges') THEN
        CREATE POLICY "Admin manages flash_trivia_challenges" ON public.flash_trivia_challenges FOR ALL TO authenticated USING (public.is_admin_check());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'flash_trivia_challenges' AND policyname = 'Authenticated view published flash challenges') THEN
        CREATE POLICY "Authenticated view published flash challenges" ON public.flash_trivia_challenges FOR SELECT TO authenticated USING (status IN ('published', 'closed'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'flash_trivia_questions' AND policyname = 'Admin manages flash_trivia_questions') THEN
        CREATE POLICY "Admin manages flash_trivia_questions" ON public.flash_trivia_questions FOR ALL TO authenticated USING (public.is_admin_check());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'flash_trivia_questions' AND policyname = 'Authenticated view flash questions without leak') THEN
        CREATE POLICY "Authenticated view flash questions without leak" ON public.flash_trivia_questions FOR SELECT TO authenticated USING (
            EXISTS (SELECT 1 FROM public.flash_trivia_challenges c WHERE c.id = flash_trivia_questions.challenge_id AND c.status = 'published')
        );
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'flash_trivia_attempts' AND policyname = 'Fans view own flash attempts') THEN
        CREATE POLICY "Fans view own flash attempts" ON public.flash_trivia_attempts FOR SELECT TO authenticated USING (fan_id = auth.uid());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'flash_trivia_attempts' AND policyname = 'Admin manages all flash attempts') THEN
        CREATE POLICY "Admin manages all flash attempts" ON public.flash_trivia_attempts FOR ALL TO authenticated USING (public.is_admin_check());
    END IF;
END $$;

-- ============================================================================
-- 5. MODALIDAD 5: PISTAS PROGRESIVAS (EL JUGADOR MISTERIOSO)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.progressive_clue_challenges (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    player_id UUID REFERENCES public.players(id) ON DELETE SET NULL,
    target_player_name TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    clue_1 TEXT NOT NULL,
    clue_2 TEXT NOT NULL,
    clue_3 TEXT NOT NULL,
    pearls_clue_1 INT DEFAULT 60 NOT NULL,
    pearls_clue_2 INT DEFAULT 35 NOT NULL,
    pearls_clue_3 INT DEFAULT 15 NOT NULL,
    reveal_photo_url TEXT,
    status TEXT DEFAULT 'published'::text NOT NULL,
    starts_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    closes_at TIMESTAMPTZ DEFAULT (now() + INTERVAL '3 days') NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT progressive_clues_pkey PRIMARY KEY (id),
    CONSTRAINT progressive_clues_status_check CHECK (status IN ('draft', 'published', 'closed', 'resolved', 'cancelled')),
    CONSTRAINT progressive_clues_rewards_check CHECK (pearls_clue_1 >= pearls_clue_2 AND pearls_clue_2 >= pearls_clue_3)
);

CREATE TABLE IF NOT EXISTS public.progressive_clue_votes (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    challenge_id UUID NOT NULL REFERENCES public.progressive_clue_challenges(id) ON DELETE CASCADE,
    fan_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    selected_player_id UUID REFERENCES public.players(id) ON DELETE SET NULL,
    clues_revealed_count INT NOT NULL,
    is_correct BOOLEAN NOT NULL,
    pearls_awarded INT DEFAULT 0 NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT progressive_clue_votes_pkey PRIMARY KEY (id),
    CONSTRAINT progressive_clue_revealed_check CHECK (clues_revealed_count BETWEEN 1 AND 3),
    CONSTRAINT progressive_clue_votes_fan_unique UNIQUE (challenge_id, fan_id)
);

CREATE INDEX IF NOT EXISTS idx_prog_clues_status_dates ON public.progressive_clue_challenges(status, starts_at, closes_at);
CREATE INDEX IF NOT EXISTS idx_prog_clues_votes_fan ON public.progressive_clue_votes(fan_id);
CREATE INDEX IF NOT EXISTS idx_prog_clues_votes_chal ON public.progressive_clue_votes(challenge_id);

ALTER TABLE public.progressive_clue_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.progressive_clue_votes ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'progressive_clue_challenges' AND policyname = 'Admin manages progressive_clue_challenges') THEN
        CREATE POLICY "Admin manages progressive_clue_challenges" ON public.progressive_clue_challenges FOR ALL TO authenticated USING (public.is_admin_check());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'progressive_clue_challenges' AND policyname = 'Authenticated view published progressive clues') THEN
        CREATE POLICY "Authenticated view published progressive clues" ON public.progressive_clue_challenges FOR SELECT TO authenticated USING (status IN ('published', 'closed', 'resolved'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'progressive_clue_votes' AND policyname = 'Fans view own progressive clue votes') THEN
        CREATE POLICY "Fans view own progressive clue votes" ON public.progressive_clue_votes FOR SELECT TO authenticated USING (fan_id = auth.uid());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'progressive_clue_votes' AND policyname = 'Admin manages all progressive clue votes') THEN
        CREATE POLICY "Admin manages all progressive clue votes" ON public.progressive_clue_votes FOR ALL TO authenticated USING (public.is_admin_check());
    END IF;
END $$;

-- ============================================================================
-- SERVER-SIDE RPCs: OVER / UNDER
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_active_over_under_predictions()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_result jsonb;
BEGIN
    SELECT COALESCE(jsonb_agg(pred_data), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT jsonb_build_object(
            'id', p.id,
            'game_id', p.game_id,
            'title', p.title,
            'description', p.description,
            'stat_type', p.stat_type,
            'line_value', p.line_value,
            'reward_pearls', p.reward_pearls,
            'status', p.status,
            'starts_at', p.starts_at,
            'closes_at', p.closes_at,
            'winning_choice', CASE WHEN p.status = 'resolved' THEN p.winning_choice ELSE NULL END,
            'actual_value', CASE WHEN p.status = 'resolved' THEN p.actual_value ELSE NULL END,
            'player', CASE WHEN pl.id IS NOT NULL THEN jsonb_build_object(
                'id', pl.id,
                'name', pl.name,
                'jersey_number', pl.jersey_number,
                'photo_url', pl.photo_url,
                'position', pl.position
            ) ELSE NULL END,
            'game', CASE WHEN g.id IS NOT NULL THEN jsonb_build_object(
                'id', g.id,
                'opponent_name', g.opponent_name,
                'opponent_logo_url', g.opponent_logo_url,
                'game_date', g.game_date,
                'is_home', g.is_home
            ) ELSE NULL END,
            'user_vote', CASE WHEN v.id IS NOT NULL THEN jsonb_build_object(
                'id', v.id,
                'choice', v.choice,
                'is_winner', v.is_winner,
                'pearls_awarded', v.pearls_awarded,
                'created_at', v.created_at
            ) ELSE NULL END,
            'over_count', (SELECT COUNT(*) FROM public.over_under_votes ov WHERE ov.prediction_id = p.id AND ov.choice = 'over'),
            'under_count', (SELECT COUNT(*) FROM public.over_under_votes ov WHERE ov.prediction_id = p.id AND ov.choice = 'under')
        ) AS pred_data
        FROM public.over_under_predictions p
        LEFT JOIN public.games g ON g.id = p.game_id
        LEFT JOIN public.players pl ON pl.id = p.player_id
        LEFT JOIN public.over_under_votes v ON v.prediction_id = p.id AND v.fan_id = v_user_id
        WHERE p.status IN ('published', 'closed', 'resolved')
        ORDER BY p.closes_at ASC, p.created_at DESC
    ) q;

    RETURN v_result;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_active_over_under_predictions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_active_over_under_predictions() TO authenticated;

CREATE OR REPLACE FUNCTION public.submit_over_under_vote(
    p_prediction_id UUID,
    p_choice TEXT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_fan_id UUID := auth.uid();
    v_pred RECORD;
    v_vote_id UUID;
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Usuario no autenticado.';
    END IF;

    PERFORM public.assert_active_verified_fan(v_fan_id);

    IF p_choice NOT IN ('over', 'under') THEN
        RAISE EXCEPTION 'Selección inválida. Debe ser over o under.';
    END IF;

    SELECT * INTO v_pred FROM public.over_under_predictions WHERE id = p_prediction_id;
    IF v_pred.id IS NULL THEN
        RAISE EXCEPTION 'La predicción no existe.';
    END IF;

    IF v_pred.status <> 'published' THEN
        RAISE EXCEPTION 'La predicción no está abierta.';
    END IF;

    IF now() > v_pred.closes_at THEN
        RAISE EXCEPTION 'El plazo para participar ha expirado.';
    END IF;

    IF EXISTS (SELECT 1 FROM public.over_under_votes WHERE prediction_id = p_prediction_id AND fan_id = v_fan_id) THEN
        RAISE EXCEPTION 'Ya has participado en esta predicción.';
    END IF;

    INSERT INTO public.over_under_votes (
        prediction_id, fan_id, choice, is_winner, pearls_awarded
    ) VALUES (
        p_prediction_id, v_fan_id, p_choice, NULL, 0
    ) RETURNING id INTO v_vote_id;

    RETURN jsonb_build_object(
        'vote_id', v_vote_id,
        'prediction_id', p_prediction_id,
        'choice', p_choice,
        'status', 'success',
        'message', 'Pronóstico registrado con éxito. El resultado se validará al terminar el partido.'
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.submit_over_under_vote(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_over_under_vote(UUID, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_resolve_over_under(
    p_prediction_id UUID,
    p_actual_value NUMERIC(6,1)
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_pred RECORD;
    v_winning_choice TEXT;
    v_vote RECORD;
    v_winners_count INT := 0;
    v_total_pearls INT := 0;
    v_reward_pearls INT;
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

    SELECT * INTO v_pred FROM public.over_under_predictions WHERE id = p_prediction_id;
    IF v_pred.id IS NULL THEN
        RAISE EXCEPTION 'La predicción no existe.';
    END IF;

    IF v_pred.status = 'resolved' THEN
        RAISE EXCEPTION 'Esta predicción ya fue resuelta previamente.';
    END IF;

    IF p_actual_value > v_pred.line_value THEN
        v_winning_choice := 'over';
    ELSIF p_actual_value < v_pred.line_value THEN
        v_winning_choice := 'under';
    ELSE
        v_winning_choice := 'push';
    END IF;

    v_reward_pearls := v_pred.reward_pearls;

    SELECT daily_pearl_cap, weekly_pearl_cap INTO v_daily_cap, v_weekly_cap FROM public.economy_settings LIMIT 1;

    UPDATE public.over_under_predictions
    SET status = 'resolved',
        actual_value = p_actual_value,
        winning_choice = v_winning_choice,
        resolved_at = now(),
        resolved_by = v_admin_id
    WHERE id = p_prediction_id;

    UPDATE public.over_under_votes
    SET is_winner = FALSE, pearls_awarded = 0
    WHERE prediction_id = p_prediction_id AND choice <> v_winning_choice;

    FOR v_vote IN
        SELECT id, fan_id FROM public.over_under_votes
        WHERE prediction_id = p_prediction_id AND choice = v_winning_choice
    LOOP
        v_winners_count := v_winners_count + 1;

        SELECT COALESCE(SUM(amount), 0) INTO v_rem_daily
        FROM public.ledger_entries
        WHERE wallet_id = (SELECT id FROM public.wallets WHERE fan_id = v_vote.fan_id)
          AND created_at >= v_today_start_caracas AND amount > 0;
        v_rem_daily := GREATEST(0, v_daily_cap - v_rem_daily);

        SELECT COALESCE(SUM(amount), 0) INTO v_rem_weekly
        FROM public.ledger_entries
        WHERE wallet_id = (SELECT id FROM public.wallets WHERE fan_id = v_vote.fan_id)
          AND created_at >= v_week_start_caracas AND amount > 0;
        v_rem_weekly := GREATEST(0, v_weekly_cap - v_rem_weekly);

        v_effective_cap := LEAST(v_rem_daily, v_rem_weekly);
        v_pearls_to_award := LEAST(v_reward_pearls, v_effective_cap);

        IF v_pearls_to_award > 0 THEN
            INSERT INTO public.ledger_entries (
                wallet_id, amount, entry_type, description, metadata
            ) VALUES (
                (SELECT id FROM public.wallets WHERE fan_id = v_vote.fan_id),
                v_pearls_to_award,
                'earn',
                'Acierto en Over/Under: ' || v_pred.title,
                jsonb_build_object('prediction_id', p_prediction_id, 'winning_choice', v_winning_choice)
            );

            UPDATE public.wallets
            SET cached_balance = cached_balance + v_pearls_to_award,
                total_earned = total_earned + v_pearls_to_award,
                updated_at = now()
            WHERE fan_id = v_vote.fan_id;

            v_total_pearls := v_total_pearls + v_pearls_to_award;
        END IF;

        UPDATE public.over_under_votes
        SET is_winner = TRUE, pearls_awarded = v_pearls_to_award
        WHERE id = v_vote.id;

        UPDATE public.profiles
        SET current_streak = current_streak + 1,
            max_streak = GREATEST(max_streak, current_streak + 1),
            last_activity_date = CURRENT_DATE
        WHERE id = v_vote.fan_id;
    END LOOP;

    INSERT INTO public.audit_logs (admin_id, action, target_type, target_id, details)
    VALUES (
        v_admin_id,
        'RESOLVE_OVER_UNDER',
        'over_under_predictions',
        p_prediction_id,
        jsonb_build_object(
            'actual_value', p_actual_value,
            'winning_choice', v_winning_choice,
            'winners_count', v_winners_count,
            'total_pearls_awarded', v_total_pearls
        )
    );

    RETURN jsonb_build_object(
        'status', 'success',
        'winning_choice', v_winning_choice,
        'winners_count', v_winners_count,
        'total_pearls_awarded', v_total_pearls
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_resolve_over_under(UUID, NUMERIC) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_resolve_over_under(UUID, NUMERIC) TO authenticated;

-- ============================================================================
-- SERVER-SIDE RPCs: MYSTERY PLAY («¿QUÉ PASÓ DESPUÉS?»)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_active_mystery_plays()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_result jsonb;
BEGIN
    SELECT COALESCE(jsonb_agg(m_data), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT jsonb_build_object(
            'id', m.id,
            'title', m.title,
            'description', m.description,
            'video_url', m.video_url,
            'cover_image_url', m.cover_image_url,
            'question', m.question,
            'option_a', m.option_a,
            'option_b', m.option_b,
            'option_c', m.option_c,
            'option_d', m.option_d,
            'reward_pearls', m.reward_pearls,
            'status', m.status,
            'starts_at', m.starts_at,
            'closes_at', m.closes_at,
            'correct_option', CASE WHEN v.id IS NOT NULL OR m.status = 'resolved' THEN m.correct_option ELSE NULL END,
            'reveal_video_url', CASE WHEN v.id IS NOT NULL OR m.status = 'resolved' THEN m.reveal_video_url ELSE NULL END,
            'game', CASE WHEN g.id IS NOT NULL THEN jsonb_build_object(
                'id', g.id,
                'opponent_name', g.opponent_name,
                'opponent_logo_url', g.opponent_logo_url,
                'game_date', g.game_date
            ) ELSE NULL END,
            'user_vote', CASE WHEN v.id IS NOT NULL THEN jsonb_build_object(
                'id', v.id,
                'selected_option', v.selected_option,
                'is_correct', v.is_correct,
                'pearls_awarded', v.pearls_awarded,
                'created_at', v.created_at
            ) ELSE NULL END
        ) AS m_data
        FROM public.mystery_play_challenges m
        LEFT JOIN public.games g ON g.id = m.game_id
        LEFT JOIN public.mystery_play_votes v ON v.challenge_id = m.id AND v.fan_id = v_user_id
        WHERE m.status IN ('published', 'closed', 'resolved')
        ORDER BY m.closes_at ASC, m.created_at DESC
    ) q;

    RETURN v_result;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_active_mystery_plays() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_active_mystery_plays() TO authenticated;

CREATE OR REPLACE FUNCTION public.submit_mystery_play_vote(
    p_challenge_id UUID,
    p_selected_option TEXT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_fan_id UUID := auth.uid();
    v_chal RECORD;
    v_is_correct BOOLEAN;
    v_pearls_to_award INT := 0;
    v_daily_cap INT := 1000;
    v_weekly_cap INT := 5000;
    v_rem_daily INT;
    v_rem_weekly INT;
    v_effective_cap INT;
    v_vote_id UUID;
    v_today_start_caracas TIMESTAMPTZ := date_trunc('day', NOW() AT TIME ZONE 'America/Caracas') AT TIME ZONE 'America/Caracas';
    v_week_start_caracas TIMESTAMPTZ := date_trunc('week', NOW() AT TIME ZONE 'America/Caracas') AT TIME ZONE 'America/Caracas';
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Usuario no autenticado.';
    END IF;

    PERFORM public.assert_active_verified_fan(v_fan_id);

    IF p_selected_option NOT IN ('A', 'B', 'C', 'D') THEN
        RAISE EXCEPTION 'Opción no válida. Debe ser A, B, C o D.';
    END IF;

    SELECT * INTO v_chal FROM public.mystery_play_challenges WHERE id = p_challenge_id;
    IF v_chal.id IS NULL THEN
        RAISE EXCEPTION 'El desafío de jugada no existe.';
    END IF;

    IF v_chal.status <> 'published' THEN
        RAISE EXCEPTION 'Este desafío ya no está abierto.';
    END IF;

    IF now() > v_chal.closes_at THEN
        RAISE EXCEPTION 'El tiempo para participar ha finalizado.';
    END IF;

    IF EXISTS (SELECT 1 FROM public.mystery_play_votes WHERE challenge_id = p_challenge_id AND fan_id = v_fan_id) THEN
        RAISE EXCEPTION 'Ya has participado en este desafío.';
    END IF;

    v_is_correct := (p_selected_option = v_chal.correct_option);

    IF v_is_correct THEN
        SELECT daily_pearl_cap, weekly_pearl_cap INTO v_daily_cap, v_weekly_cap FROM public.economy_settings LIMIT 1;

        SELECT COALESCE(SUM(amount), 0) INTO v_rem_daily
        FROM public.ledger_entries
        WHERE wallet_id = (SELECT id FROM public.wallets WHERE fan_id = v_fan_id)
          AND created_at >= v_today_start_caracas AND amount > 0;
        v_rem_daily := GREATEST(0, v_daily_cap - v_rem_daily);

        SELECT COALESCE(SUM(amount), 0) INTO v_rem_weekly
        FROM public.ledger_entries
        WHERE wallet_id = (SELECT id FROM public.wallets WHERE fan_id = v_fan_id)
          AND created_at >= v_week_start_caracas AND amount > 0;
        v_rem_weekly := GREATEST(0, v_weekly_cap - v_rem_weekly);

        v_effective_cap := LEAST(v_rem_daily, v_rem_weekly);
        v_pearls_to_award := LEAST(v_chal.reward_pearls, v_effective_cap);

        IF v_pearls_to_award > 0 THEN
            INSERT INTO public.ledger_entries (
                wallet_id, amount, entry_type, description, metadata
            ) VALUES (
                (SELECT id FROM public.wallets WHERE fan_id = v_fan_id),
                v_pearls_to_award,
                'earn',
                'Acierto en Jugada Misteriosa: ' || v_chal.title,
                jsonb_build_object('challenge_id', p_challenge_id)
            );

            UPDATE public.wallets
            SET cached_balance = cached_balance + v_pearls_to_award,
                total_earned = total_earned + v_pearls_to_award,
                updated_at = now()
            WHERE fan_id = v_fan_id;
        END IF;

        UPDATE public.profiles
        SET current_streak = current_streak + 1,
            max_streak = GREATEST(max_streak, current_streak + 1),
            last_activity_date = CURRENT_DATE
        WHERE id = v_fan_id;
    END IF;

    INSERT INTO public.mystery_play_votes (
        challenge_id, fan_id, selected_option, is_correct, pearls_awarded
    ) VALUES (
        p_challenge_id, v_fan_id, p_selected_option, v_is_correct, v_pearls_to_award
    ) RETURNING id INTO v_vote_id;

    RETURN jsonb_build_object(
        'vote_id', v_vote_id,
        'challenge_id', p_challenge_id,
        'selected_option', p_selected_option,
        'is_correct', v_is_correct,
        'correct_option', v_chal.correct_option,
        'reveal_video_url', v_chal.reveal_video_url,
        'pearls_awarded', v_pearls_to_award
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.submit_mystery_play_vote(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_mystery_play_vote(UUID, TEXT) TO authenticated;

-- ============================================================================
-- SERVER-SIDE RPCs: ADIVINA EL MARCADOR EXACTO
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_active_score_predictions()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_result jsonb;
BEGIN
    SELECT COALESCE(jsonb_agg(sp_data), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT jsonb_build_object(
            'id', sp.id,
            'title', sp.title,
            'description', sp.description,
            'exact_reward_pearls', sp.exact_reward_pearls,
            'closest_reward_pearls', sp.closest_reward_pearls,
            'status', sp.status,
            'starts_at', sp.starts_at,
            'closes_at', sp.closes_at,
            'final_guaiqueries_score', CASE WHEN sp.status = 'resolved' THEN sp.final_guaiqueries_score ELSE NULL END,
            'final_rival_score', CASE WHEN sp.status = 'resolved' THEN sp.final_rival_score ELSE NULL END,
            'game', jsonb_build_object(
                'id', g.id,
                'opponent_name', g.opponent_name,
                'opponent_logo_url', g.opponent_logo_url,
                'game_date', g.game_date,
                'is_home', g.is_home
            ),
            'user_vote', CASE WHEN v.id IS NOT NULL THEN jsonb_build_object(
                'id', v.id,
                'predicted_guaiqueries_score', v.predicted_guaiqueries_score,
                'predicted_rival_score', v.predicted_rival_score,
                'is_exact_match', v.is_exact_match,
                'is_closest_match', v.is_closest_match,
                'pearls_awarded', v.pearls_awarded,
                'created_at', v.created_at
            ) ELSE NULL END,
            'total_participants', (SELECT COUNT(*) FROM public.score_prediction_votes sv WHERE sv.prediction_id = sp.id)
        ) AS sp_data
        FROM public.score_predictions sp
        INNER JOIN public.games g ON g.id = sp.game_id
        LEFT JOIN public.score_prediction_votes v ON v.prediction_id = sp.id AND v.fan_id = v_user_id
        WHERE sp.status IN ('published', 'closed', 'resolved')
        ORDER BY sp.closes_at ASC, sp.created_at DESC
    ) q;

    RETURN v_result;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_active_score_predictions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_active_score_predictions() TO authenticated;

CREATE OR REPLACE FUNCTION public.submit_score_prediction_vote(
    p_prediction_id UUID,
    p_guaiqueries_score INT,
    p_rival_score INT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_fan_id UUID := auth.uid();
    v_pred RECORD;
    v_vote_id UUID;
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Usuario no autenticado.';
    END IF;

    PERFORM public.assert_active_verified_fan(v_fan_id);

    IF p_guaiqueries_score < 0 OR p_rival_score < 0 THEN
        RAISE EXCEPTION 'El marcador no puede ser negativo.';
    END IF;

    SELECT * INTO v_pred FROM public.score_predictions WHERE id = p_prediction_id;
    IF v_pred.id IS NULL THEN
        RAISE EXCEPTION 'La predicción de marcador no existe.';
    END IF;

    IF v_pred.status <> 'published' THEN
        RAISE EXCEPTION 'Esta predicción no está abierta.';
    END IF;

    IF now() > v_pred.closes_at THEN
        RAISE EXCEPTION 'El tiempo para pronosticar ha cerrado.';
    END IF;

    IF EXISTS (SELECT 1 FROM public.score_prediction_votes WHERE prediction_id = p_prediction_id AND fan_id = v_fan_id) THEN
        RAISE EXCEPTION 'Ya has enviado tu pronóstico para este partido.';
    END IF;

    INSERT INTO public.score_prediction_votes (
        prediction_id, fan_id, predicted_guaiqueries_score, predicted_rival_score, is_exact_match, is_closest_match, pearls_awarded
    ) VALUES (
        p_prediction_id, v_fan_id, p_guaiqueries_score, p_rival_score, NULL, NULL, 0
    ) RETURNING id INTO v_vote_id;

    RETURN jsonb_build_object(
        'vote_id', v_vote_id,
        'prediction_id', p_prediction_id,
        'predicted_guaiqueries_score', p_guaiqueries_score,
        'predicted_rival_score', p_rival_score,
        'status', 'success',
        'message', 'Marcador registrado con éxito. ¡Mucha suerte al sonar la chicharra!'
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.submit_score_prediction_vote(UUID, INT, INT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_score_prediction_vote(UUID, INT, INT) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_resolve_score_prediction(
    p_prediction_id UUID,
    p_final_guaiqueries_score INT,
    p_final_rival_score INT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_pred RECORD;
    v_vote RECORD;
    v_exact_count INT := 0;
    v_closest_count INT := 0;
    v_total_pearls INT := 0;
    v_daily_cap INT := 1000;
    v_weekly_cap INT := 5000;
    v_rem_daily INT;
    v_rem_weekly INT;
    v_effective_cap INT;
    v_pearls_to_award INT;
    v_diff INT;
    v_today_start_caracas TIMESTAMPTZ := date_trunc('day', NOW() AT TIME ZONE 'America/Caracas') AT TIME ZONE 'America/Caracas';
    v_week_start_caracas TIMESTAMPTZ := date_trunc('week', NOW() AT TIME ZONE 'America/Caracas') AT TIME ZONE 'America/Caracas';
BEGIN
    PERFORM public.assert_admin();

    SELECT * INTO v_pred FROM public.score_predictions WHERE id = p_prediction_id;
    IF v_pred.id IS NULL THEN
        RAISE EXCEPTION 'La predicción de marcador no existe.';
    END IF;

    IF v_pred.status = 'resolved' THEN
        RAISE EXCEPTION 'Esta predicción ya fue resuelta previamente.';
    END IF;

    SELECT daily_pearl_cap, weekly_pearl_cap INTO v_daily_cap, v_weekly_cap FROM public.economy_settings LIMIT 1;

    UPDATE public.score_predictions
    SET status = 'resolved',
        final_guaiqueries_score = p_final_guaiqueries_score,
        final_rival_score = p_final_rival_score,
        resolved_at = now(),
        resolved_by = v_admin_id
    WHERE id = p_prediction_id;

    -- Evaluate each vote
    FOR v_vote IN
        SELECT id, fan_id, predicted_guaiqueries_score, predicted_rival_score
        FROM public.score_prediction_votes
        WHERE prediction_id = p_prediction_id
    LOOP
        v_diff := ABS(v_vote.predicted_guaiqueries_score - p_final_guaiqueries_score) + ABS(v_vote.predicted_rival_score - p_final_rival_score);

        IF v_vote.predicted_guaiqueries_score = p_final_guaiqueries_score AND v_vote.predicted_rival_score = p_final_rival_score THEN
            -- Exact Hit
            v_exact_count := v_exact_count + 1;

            SELECT COALESCE(SUM(amount), 0) INTO v_rem_daily FROM public.ledger_entries WHERE wallet_id = (SELECT id FROM public.wallets WHERE fan_id = v_vote.fan_id) AND created_at >= v_today_start_caracas AND amount > 0;
            v_rem_daily := GREATEST(0, v_daily_cap - v_rem_daily);

            SELECT COALESCE(SUM(amount), 0) INTO v_rem_weekly FROM public.ledger_entries WHERE wallet_id = (SELECT id FROM public.wallets WHERE fan_id = v_vote.fan_id) AND created_at >= v_week_start_caracas AND amount > 0;
            v_rem_weekly := GREATEST(0, v_weekly_cap - v_rem_weekly);

            v_effective_cap := LEAST(v_rem_daily, v_rem_weekly);
            v_pearls_to_award := LEAST(v_pred.exact_reward_pearls, v_effective_cap);

            IF v_pearls_to_award > 0 THEN
                INSERT INTO public.ledger_entries (wallet_id, amount, entry_type, description, metadata)
                VALUES ((SELECT id FROM public.wallets WHERE fan_id = v_vote.fan_id), v_pearls_to_award, 'earn', '¡Marcador Exacto acertado!: ' || v_pred.title, jsonb_build_object('prediction_id', p_prediction_id));

                UPDATE public.wallets SET cached_balance = cached_balance + v_pearls_to_award, total_earned = total_earned + v_pearls_to_award, updated_at = now() WHERE fan_id = v_vote.fan_id;
                v_total_pearls := v_total_pearls + v_pearls_to_award;
            END IF;

            UPDATE public.score_prediction_votes SET is_exact_match = TRUE, is_closest_match = FALSE, pearls_awarded = v_pearls_to_award WHERE id = v_vote.id;
            UPDATE public.profiles SET current_streak = current_streak + 2, max_streak = GREATEST(max_streak, current_streak + 2), last_activity_date = CURRENT_DATE WHERE id = v_vote.fan_id;

        ELSIF v_diff <= 4 AND (
            (p_final_guaiqueries_score > p_final_rival_score AND v_vote.predicted_guaiqueries_score > v_vote.predicted_rival_score) OR
            (p_final_guaiqueries_score < p_final_rival_score AND v_vote.predicted_guaiqueries_score < v_vote.predicted_rival_score)
        ) THEN
            -- Closest Match (< 4 pts diff + correct winner)
            v_closest_count := v_closest_count + 1;

            SELECT COALESCE(SUM(amount), 0) INTO v_rem_daily FROM public.ledger_entries WHERE wallet_id = (SELECT id FROM public.wallets WHERE fan_id = v_vote.fan_id) AND created_at >= v_today_start_caracas AND amount > 0;
            v_rem_daily := GREATEST(0, v_daily_cap - v_rem_daily);

            SELECT COALESCE(SUM(amount), 0) INTO v_rem_weekly FROM public.ledger_entries WHERE wallet_id = (SELECT id FROM public.wallets WHERE fan_id = v_vote.fan_id) AND created_at >= v_week_start_caracas AND amount > 0;
            v_rem_weekly := GREATEST(0, v_weekly_cap - v_rem_weekly);

            v_effective_cap := LEAST(v_rem_daily, v_rem_weekly);
            v_pearls_to_award := LEAST(v_pred.closest_reward_pearls, v_effective_cap);

            IF v_pearls_to_award > 0 THEN
                INSERT INTO public.ledger_entries (wallet_id, amount, entry_type, description, metadata)
                VALUES ((SELECT id FROM public.wallets WHERE fan_id = v_vote.fan_id), v_pearls_to_award, 'earn', 'Marcador Cercano: ' || v_pred.title, jsonb_build_object('prediction_id', p_prediction_id));

                UPDATE public.wallets SET cached_balance = cached_balance + v_pearls_to_award, total_earned = total_earned + v_pearls_to_award, updated_at = now() WHERE fan_id = v_vote.fan_id;
                v_total_pearls := v_total_pearls + v_pearls_to_award;
            END IF;

            UPDATE public.score_prediction_votes SET is_exact_match = FALSE, is_closest_match = TRUE, pearls_awarded = v_pearls_to_award WHERE id = v_vote.id;
        ELSE
            UPDATE public.score_prediction_votes SET is_exact_match = FALSE, is_closest_match = FALSE, pearls_awarded = 0 WHERE id = v_vote.id;
        END IF;
    END LOOP;

    INSERT INTO public.audit_logs (admin_id, action, target_type, target_id, details)
    VALUES (
        v_admin_id,
        'RESOLVE_SCORE_PREDICTION',
        'score_predictions',
        p_prediction_id,
        jsonb_build_object(
            'final_guaiqueries_score', p_final_guaiqueries_score,
            'final_rival_score', p_final_rival_score,
            'exact_winners', v_exact_count,
            'closest_winners', v_closest_count,
            'total_pearls_awarded', v_total_pearls
        )
    );

    RETURN jsonb_build_object(
        'status', 'success',
        'exact_winners', v_exact_count,
        'closest_winners', v_closest_count,
        'total_pearls_awarded', v_total_pearls
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_resolve_score_prediction(UUID, INT, INT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_resolve_score_prediction(UUID, INT, INT) TO authenticated;

-- ============================================================================
-- SERVER-SIDE RPCs: TRIVIA FLASH CONTRARRELOJ 60s
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_active_flash_trivia()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_result jsonb;
BEGIN
    SELECT COALESCE(jsonb_agg(ft_data), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT jsonb_build_object(
            'id', c.id,
            'title', c.title,
            'description', c.description,
            'time_limit_seconds', c.time_limit_seconds,
            'pearls_per_correct', c.pearls_per_correct,
            'status', c.status,
            'starts_at', c.starts_at,
            'closes_at', c.closes_at,
            'user_attempt', CASE WHEN a.id IS NOT NULL THEN jsonb_build_object(
                'id', a.id,
                'correct_count', a.correct_count,
                'total_answered', a.total_answered,
                'time_spent_seconds', a.time_spent_seconds,
                'pearls_awarded', a.pearls_awarded,
                'created_at', a.created_at
            ) ELSE NULL END,
            'questions', (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'id', q.id,
                        'question', q.question,
                        'option_a', q.option_a,
                        'option_b', q.option_b,
                        'option_c', q.option_c,
                        'option_d', q.option_d,
                        'order_index', q.order_index
                    ) ORDER BY q.order_index ASC, q.created_at ASC
                )
                FROM public.flash_trivia_questions q
                WHERE q.challenge_id = c.id
            )
        ) AS ft_data
        FROM public.flash_trivia_challenges c
        LEFT JOIN public.flash_trivia_attempts a ON a.challenge_id = c.id AND a.fan_id = v_user_id
        WHERE c.status = 'published'
        ORDER BY c.closes_at ASC, c.created_at DESC
    ) q;

    RETURN v_result;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_active_flash_trivia() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_active_flash_trivia() TO authenticated;

CREATE OR REPLACE FUNCTION public.submit_flash_trivia_session(
    p_challenge_id UUID,
    p_answers jsonb, -- Array of objects: [{"question_id": "...", "selected_option": "A"}]
    p_time_spent_seconds INT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_fan_id UUID := auth.uid();
    v_chal RECORD;
    v_item RECORD;
    v_q RECORD;
    v_correct_count INT := 0;
    v_total_answered INT := 0;
    v_pearls_earned INT := 0;
    v_pearls_to_award INT := 0;
    v_daily_cap INT := 1000;
    v_weekly_cap INT := 5000;
    v_rem_daily INT;
    v_rem_weekly INT;
    v_effective_cap INT;
    v_attempt_id UUID;
    v_today_start_caracas TIMESTAMPTZ := date_trunc('day', NOW() AT TIME ZONE 'America/Caracas') AT TIME ZONE 'America/Caracas';
    v_week_start_caracas TIMESTAMPTZ := date_trunc('week', NOW() AT TIME ZONE 'America/Caracas') AT TIME ZONE 'America/Caracas';
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Usuario no autenticado.';
    END IF;

    PERFORM public.assert_active_verified_fan(v_fan_id);

    SELECT * INTO v_chal FROM public.flash_trivia_challenges WHERE id = p_challenge_id;
    IF v_chal.id IS NULL THEN
        RAISE EXCEPTION 'El desafío flash no existe.';
    END IF;

    IF v_chal.status <> 'published' THEN
        RAISE EXCEPTION 'Este desafío flash no está activo.';
    END IF;

    IF now() > v_chal.closes_at THEN
        RAISE EXCEPTION 'El desafío flash ya cerró.';
    END IF;

    IF EXISTS (SELECT 1 FROM public.flash_trivia_attempts WHERE challenge_id = p_challenge_id AND fan_id = v_fan_id) THEN
        RAISE EXCEPTION 'Ya has participado en esta sesión contrarreloj.';
    END IF;

    -- Evaluate answers securely on server
    FOR v_item IN SELECT * FROM jsonb_to_recordset(p_answers) AS x(question_id UUID, selected_option TEXT)
    LOOP
        v_total_answered := v_total_answered + 1;
        SELECT * INTO v_q FROM public.flash_trivia_questions WHERE id = v_item.question_id AND challenge_id = p_challenge_id;
        IF v_q.id IS NOT NULL AND v_q.correct_option = UPPER(TRIM(v_item.selected_option)) THEN
            v_correct_count := v_correct_count + 1;
        END IF;
    END LOOP;

    v_pearls_earned := v_correct_count * v_chal.pearls_per_correct;

    IF v_pearls_earned > 0 THEN
        SELECT daily_pearl_cap, weekly_pearl_cap INTO v_daily_cap, v_weekly_cap FROM public.economy_settings LIMIT 1;

        SELECT COALESCE(SUM(amount), 0) INTO v_rem_daily FROM public.ledger_entries WHERE wallet_id = (SELECT id FROM public.wallets WHERE fan_id = v_fan_id) AND created_at >= v_today_start_caracas AND amount > 0;
        v_rem_daily := GREATEST(0, v_daily_cap - v_rem_daily);

        SELECT COALESCE(SUM(amount), 0) INTO v_rem_weekly FROM public.ledger_entries WHERE wallet_id = (SELECT id FROM public.wallets WHERE fan_id = v_fan_id) AND created_at >= v_week_start_caracas AND amount > 0;
        v_rem_weekly := GREATEST(0, v_weekly_cap - v_rem_weekly);

        v_effective_cap := LEAST(v_rem_daily, v_rem_weekly);
        v_pearls_to_award := LEAST(v_pearls_earned, v_effective_cap);

        IF v_pearls_to_award > 0 THEN
            INSERT INTO public.ledger_entries (wallet_id, amount, entry_type, description, metadata)
            VALUES ((SELECT id FROM public.wallets WHERE fan_id = v_fan_id), v_pearls_to_award, 'earn', 'Sesión Flash: ' || v_chal.title, jsonb_build_object('challenge_id', p_challenge_id, 'correct_count', v_correct_count));

            UPDATE public.wallets SET cached_balance = cached_balance + v_pearls_to_award, total_earned = total_earned + v_pearls_to_award, updated_at = now() WHERE fan_id = v_fan_id;
        END IF;

        UPDATE public.profiles SET current_streak = current_streak + 1, max_streak = GREATEST(max_streak, current_streak + 1), last_activity_date = CURRENT_DATE WHERE id = v_fan_id;
    END IF;

    INSERT INTO public.flash_trivia_attempts (
        challenge_id, fan_id, correct_count, total_answered, time_spent_seconds, pearls_awarded
    ) VALUES (
        p_challenge_id, v_fan_id, v_correct_count, v_total_answered, p_time_spent_seconds, v_pearls_to_award
    ) RETURNING id INTO v_attempt_id;

    RETURN jsonb_build_object(
        'attempt_id', v_attempt_id,
        'correct_count', v_correct_count,
        'total_answered', v_total_answered,
        'time_spent_seconds', p_time_spent_seconds,
        'pearls_awarded', v_pearls_to_award
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.submit_flash_trivia_session(UUID, jsonb, INT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_flash_trivia_session(UUID, jsonb, INT) TO authenticated;

-- ============================================================================
-- SERVER-SIDE RPCs: PISTAS PROGRESIVAS
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_active_progressive_clues()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_result jsonb;
BEGIN
    SELECT COALESCE(jsonb_agg(pc_data), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT jsonb_build_object(
            'id', pc.id,
            'title', pc.title,
            'description', pc.description,
            'clue_1', pc.clue_1,
            'clue_2', pc.clue_2,
            'clue_3', pc.clue_3,
            'pearls_clue_1', pc.pearls_clue_1,
            'pearls_clue_2', pc.pearls_clue_2,
            'pearls_clue_3', pc.pearls_clue_3,
            'status', pc.status,
            'starts_at', pc.starts_at,
            'closes_at', pc.closes_at,
            'target_player_name', CASE WHEN v.id IS NOT NULL OR pc.status = 'resolved' THEN pc.target_player_name ELSE NULL END,
            'reveal_photo_url', CASE WHEN v.id IS NOT NULL OR pc.status = 'resolved' THEN pc.reveal_photo_url ELSE NULL END,
            'target_player', CASE WHEN (v.id IS NOT NULL OR pc.status = 'resolved') AND pl.id IS NOT NULL THEN jsonb_build_object(
                'id', pl.id,
                'name', pl.name,
                'jersey_number', pl.jersey_number,
                'photo_url', pl.photo_url,
                'position', pl.position
            ) ELSE NULL END,
            'user_vote', CASE WHEN v.id IS NOT NULL THEN jsonb_build_object(
                'id', v.id,
                'clues_revealed_count', v.clues_revealed_count,
                'is_correct', v.is_correct,
                'pearls_awarded', v.pearls_awarded,
                'created_at', v.created_at
            ) ELSE NULL END
        ) AS pc_data
        FROM public.progressive_clue_challenges pc
        LEFT JOIN public.players pl ON pl.id = pc.player_id
        LEFT JOIN public.progressive_clue_votes v ON v.challenge_id = pc.id AND v.fan_id = v_user_id
        WHERE pc.status IN ('published', 'closed', 'resolved')
        ORDER BY pc.closes_at ASC, pc.created_at DESC
    ) q;

    RETURN v_result;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_active_progressive_clues() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_active_progressive_clues() TO authenticated;

CREATE OR REPLACE FUNCTION public.submit_progressive_clue_vote(
    p_challenge_id UUID,
    p_selected_player_id UUID,
    p_clues_revealed_count INT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_fan_id UUID := auth.uid();
    v_chal RECORD;
    v_is_correct BOOLEAN := FALSE;
    v_reward_base INT := 0;
    v_pearls_to_award INT := 0;
    v_daily_cap INT := 1000;
    v_weekly_cap INT := 5000;
    v_rem_daily INT;
    v_rem_weekly INT;
    v_effective_cap INT;
    v_vote_id UUID;
    v_today_start_caracas TIMESTAMPTZ := date_trunc('day', NOW() AT TIME ZONE 'America/Caracas') AT TIME ZONE 'America/Caracas';
    v_week_start_caracas TIMESTAMPTZ := date_trunc('week', NOW() AT TIME ZONE 'America/Caracas') AT TIME ZONE 'America/Caracas';
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Usuario no autenticado.';
    END IF;

    PERFORM public.assert_active_verified_fan(v_fan_id);

    IF p_clues_revealed_count NOT BETWEEN 1 AND 3 THEN
        RAISE EXCEPTION 'Número de pistas inválido (1-3).';
    END IF;

    SELECT * INTO v_chal FROM public.progressive_clue_challenges WHERE id = p_challenge_id;
    IF v_chal.id IS NULL THEN
        RAISE EXCEPTION 'El desafío de pistas no existe.';
    END IF;

    IF v_chal.status <> 'published' THEN
        RAISE EXCEPTION 'Este desafío no está activo.';
    END IF;

    IF now() > v_chal.closes_at THEN
        RAISE EXCEPTION 'El desafío ya cerró.';
    END IF;

    IF EXISTS (SELECT 1 FROM public.progressive_clue_votes WHERE challenge_id = p_challenge_id AND fan_id = v_fan_id) THEN
        RAISE EXCEPTION 'Ya has participado en este desafío de pistas.';
    END IF;

    -- Validate if correct
    v_is_correct := (p_selected_player_id = v_chal.player_id);

    IF v_is_correct THEN
        IF p_clues_revealed_count = 1 THEN
            v_reward_base := v_chal.pearls_clue_1;
        ELSIF p_clues_revealed_count = 2 THEN
            v_reward_base := v_chal.pearls_clue_2;
        ELSE
            v_reward_base := v_chal.pearls_clue_3;
        END IF;

        SELECT daily_pearl_cap, weekly_pearl_cap INTO v_daily_cap, v_weekly_cap FROM public.economy_settings LIMIT 1;

        SELECT COALESCE(SUM(amount), 0) INTO v_rem_daily FROM public.ledger_entries WHERE wallet_id = (SELECT id FROM public.wallets WHERE fan_id = v_fan_id) AND created_at >= v_today_start_caracas AND amount > 0;
        v_rem_daily := GREATEST(0, v_daily_cap - v_rem_daily);

        SELECT COALESCE(SUM(amount), 0) INTO v_rem_weekly FROM public.ledger_entries WHERE wallet_id = (SELECT id FROM public.wallets WHERE fan_id = v_fan_id) AND created_at >= v_week_start_caracas AND amount > 0;
        v_rem_weekly := GREATEST(0, v_weekly_cap - v_rem_weekly);

        v_effective_cap := LEAST(v_rem_daily, v_rem_weekly);
        v_pearls_to_award := LEAST(v_reward_base, v_effective_cap);

        IF v_pearls_to_award > 0 THEN
            INSERT INTO public.ledger_entries (wallet_id, amount, entry_type, description, metadata)
            VALUES ((SELECT id FROM public.wallets WHERE fan_id = v_fan_id), v_pearls_to_award, 'earn', 'Pistas Progresivas: ' || v_chal.title, jsonb_build_object('challenge_id', p_challenge_id, 'clues_used', p_clues_revealed_count));

            UPDATE public.wallets SET cached_balance = cached_balance + v_pearls_to_award, total_earned = total_earned + v_pearls_to_award, updated_at = now() WHERE fan_id = v_fan_id;
        END IF;

        UPDATE public.profiles SET current_streak = current_streak + 1, max_streak = GREATEST(max_streak, current_streak + 1), last_activity_date = CURRENT_DATE WHERE id = v_fan_id;
    END IF;

    INSERT INTO public.progressive_clue_votes (
        challenge_id, fan_id, selected_player_id, clues_revealed_count, is_correct, pearls_awarded
    ) VALUES (
        p_challenge_id, v_fan_id, p_selected_player_id, p_clues_revealed_count, v_is_correct, v_pearls_to_award
    ) RETURNING id INTO v_vote_id;

    RETURN jsonb_build_object(
        'vote_id', v_vote_id,
        'challenge_id', p_challenge_id,
        'is_correct', v_is_correct,
        'target_player_name', v_chal.target_player_name,
        'reveal_photo_url', v_chal.reveal_photo_url,
        'pearls_awarded', v_pearls_to_award
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.submit_progressive_clue_vote(UUID, UUID, INT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_progressive_clue_vote(UUID, UUID, INT) TO authenticated;

-- ============================================================================
-- ADMIN CRUD RPCs FOR ALL 5 MODALITIES
-- ============================================================================

-- 1. Over/Under CRUD
CREATE OR REPLACE FUNCTION public.admin_upsert_over_under(
    p_id UUID,
    p_game_id UUID,
    p_player_id UUID,
    p_title TEXT,
    p_description TEXT,
    p_stat_type TEXT,
    p_line_value NUMERIC(6,1),
    p_reward_pearls INT,
    p_status TEXT,
    p_starts_at TIMESTAMPTZ,
    p_closes_at TIMESTAMPTZ
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_id UUID;
BEGIN
    PERFORM public.assert_admin();

    IF p_id IS NOT NULL AND EXISTS (SELECT 1 FROM public.over_under_predictions WHERE id = p_id) THEN
        UPDATE public.over_under_predictions
        SET game_id = p_game_id,
            player_id = p_player_id,
            title = p_title,
            description = p_description,
            stat_type = COALESCE(p_stat_type, 'points'),
            line_value = p_line_value,
            reward_pearls = COALESCE(p_reward_pearls, 40),
            status = COALESCE(p_status, 'published'),
            starts_at = COALESCE(p_starts_at, now()),
            closes_at = COALESCE(p_closes_at, now() + INTERVAL '2 days')
        WHERE id = p_id
        RETURNING id INTO v_id;
    ELSE
        INSERT INTO public.over_under_predictions (
            game_id, player_id, title, description, stat_type, line_value, reward_pearls, status, starts_at, closes_at
        ) VALUES (
            p_game_id, p_player_id, p_title, p_description, COALESCE(p_stat_type, 'points'), p_line_value, COALESCE(p_reward_pearls, 40), COALESCE(p_status, 'published'), COALESCE(p_starts_at, now()), COALESCE(p_closes_at, now() + INTERVAL '2 days')
        ) RETURNING id INTO v_id;
    END IF;

    RETURN v_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_upsert_over_under FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_upsert_over_under TO authenticated;

-- 2. Mystery Play CRUD
CREATE OR REPLACE FUNCTION public.admin_upsert_mystery_play(
    p_id UUID,
    p_game_id UUID,
    p_title TEXT,
    p_description TEXT,
    p_video_url TEXT,
    p_cover_image_url TEXT,
    p_question TEXT,
    p_option_a TEXT,
    p_option_b TEXT,
    p_option_c TEXT,
    p_option_d TEXT,
    p_correct_option TEXT,
    p_reveal_video_url TEXT,
    p_reward_pearls INT,
    p_status TEXT,
    p_starts_at TIMESTAMPTZ,
    p_closes_at TIMESTAMPTZ
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_id UUID;
BEGIN
    PERFORM public.assert_admin();

    IF p_id IS NOT NULL AND EXISTS (SELECT 1 FROM public.mystery_play_challenges WHERE id = p_id) THEN
        UPDATE public.mystery_play_challenges
        SET game_id = p_game_id,
            title = p_title,
            description = p_description,
            video_url = p_video_url,
            cover_image_url = p_cover_image_url,
            question = p_question,
            option_a = p_option_a,
            option_b = p_option_b,
            option_c = p_option_c,
            option_d = p_option_d,
            correct_option = UPPER(TRIM(p_correct_option)),
            reveal_video_url = p_reveal_video_url,
            reward_pearls = COALESCE(p_reward_pearls, 50),
            status = COALESCE(p_status, 'published'),
            starts_at = COALESCE(p_starts_at, now()),
            closes_at = COALESCE(p_closes_at, now() + INTERVAL '3 days')
        WHERE id = p_id
        RETURNING id INTO v_id;
    ELSE
        INSERT INTO public.mystery_play_challenges (
            game_id, title, description, video_url, cover_image_url, question, option_a, option_b, option_c, option_d, correct_option, reveal_video_url, reward_pearls, status, starts_at, closes_at
        ) VALUES (
            p_game_id, p_title, p_description, p_video_url, p_cover_image_url, p_question, p_option_a, p_option_b, p_option_c, p_option_d, UPPER(TRIM(p_correct_option)), p_reveal_video_url, COALESCE(p_reward_pearls, 50), COALESCE(p_status, 'published'), COALESCE(p_starts_at, now()), COALESCE(p_closes_at, now() + INTERVAL '3 days')
        ) RETURNING id INTO v_id;
    END IF;

    RETURN v_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_upsert_mystery_play FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_upsert_mystery_play TO authenticated;

-- 3. Score Prediction CRUD
CREATE OR REPLACE FUNCTION public.admin_upsert_score_prediction(
    p_id UUID,
    p_game_id UUID,
    p_title TEXT,
    p_description TEXT,
    p_exact_reward_pearls INT,
    p_closest_reward_pearls INT,
    p_status TEXT,
    p_starts_at TIMESTAMPTZ,
    p_closes_at TIMESTAMPTZ
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_id UUID;
BEGIN
    PERFORM public.assert_admin();

    IF p_id IS NOT NULL AND EXISTS (SELECT 1 FROM public.score_predictions WHERE id = p_id) THEN
        UPDATE public.score_predictions
        SET game_id = p_game_id,
            title = p_title,
            description = p_description,
            exact_reward_pearls = COALESCE(p_exact_reward_pearls, 200),
            closest_reward_pearls = COALESCE(p_closest_reward_pearls, 50),
            status = COALESCE(p_status, 'published'),
            starts_at = COALESCE(p_starts_at, now()),
            closes_at = COALESCE(p_closes_at, now() + INTERVAL '2 days')
        WHERE id = p_id
        RETURNING id INTO v_id;
    ELSE
        INSERT INTO public.score_predictions (
            game_id, title, description, exact_reward_pearls, closest_reward_pearls, status, starts_at, closes_at
        ) VALUES (
            p_game_id, p_title, p_description, COALESCE(p_exact_reward_pearls, 200), COALESCE(p_closest_reward_pearls, 50), COALESCE(p_status, 'published'), COALESCE(p_starts_at, now()), COALESCE(p_closes_at, now() + INTERVAL '2 days')
        ) RETURNING id INTO v_id;
    END IF;

    RETURN v_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_upsert_score_prediction FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_upsert_score_prediction TO authenticated;

-- 4. Flash Trivia CRUD
CREATE OR REPLACE FUNCTION public.admin_upsert_flash_challenge(
    p_id UUID,
    p_title TEXT,
    p_description TEXT,
    p_time_limit_seconds INT,
    p_pearls_per_correct INT,
    p_status TEXT,
    p_starts_at TIMESTAMPTZ,
    p_closes_at TIMESTAMPTZ,
    p_questions jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_id UUID;
    v_q RECORD;
BEGIN
    PERFORM public.assert_admin();

    IF p_id IS NOT NULL AND EXISTS (SELECT 1 FROM public.flash_trivia_challenges WHERE id = p_id) THEN
        UPDATE public.flash_trivia_challenges
        SET title = p_title,
            description = p_description,
            time_limit_seconds = COALESCE(p_time_limit_seconds, 60),
            pearls_per_correct = COALESCE(p_pearls_per_correct, 10),
            status = COALESCE(p_status, 'published'),
            starts_at = COALESCE(p_starts_at, now()),
            closes_at = COALESCE(p_closes_at, now() + INTERVAL '7 days')
        WHERE id = p_id
        RETURNING id INTO v_id;
    ELSE
        INSERT INTO public.flash_trivia_challenges (
            title, description, time_limit_seconds, pearls_per_correct, status, starts_at, closes_at
        ) VALUES (
            p_title, p_description, COALESCE(p_time_limit_seconds, 60), COALESCE(p_pearls_per_correct, 10), COALESCE(p_status, 'published'), COALESCE(p_starts_at, now()), COALESCE(p_closes_at, now() + INTERVAL '7 days')
        ) RETURNING id INTO v_id;
    END IF;

    IF p_questions IS NOT NULL AND jsonb_array_length(p_questions) > 0 THEN
        FOR v_q IN SELECT * FROM jsonb_to_recordset(p_questions) AS x(
            id UUID,
            question TEXT,
            option_a TEXT,
            option_b TEXT,
            option_c TEXT,
            option_d TEXT,
            correct_option TEXT,
            order_index INT
        )
        LOOP
            IF v_q.id IS NOT NULL AND EXISTS (SELECT 1 FROM public.flash_trivia_questions WHERE id = v_q.id) THEN
                UPDATE public.flash_trivia_questions
                SET question = v_q.question,
                    option_a = v_q.option_a,
                    option_b = v_q.option_b,
                    option_c = v_q.option_c,
                    option_d = v_q.option_d,
                    correct_option = UPPER(TRIM(v_q.correct_option)),
                    order_index = COALESCE(v_q.order_index, 0)
                WHERE id = v_q.id;
            ELSE
                INSERT INTO public.flash_trivia_questions (
                    challenge_id, question, option_a, option_b, option_c, option_d, correct_option, order_index
                ) VALUES (
                    v_id, v_q.question, v_q.option_a, v_q.option_b, v_q.option_c, v_q.option_d, UPPER(TRIM(v_q.correct_option)), COALESCE(v_q.order_index, 0)
                );
            END IF;
        END LOOP;
    END IF;

    RETURN v_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_upsert_flash_challenge FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_upsert_flash_challenge TO authenticated;

-- 5. Progressive Clues CRUD
CREATE OR REPLACE FUNCTION public.admin_upsert_progressive_clue(
    p_id UUID,
    p_player_id UUID,
    p_target_player_name TEXT,
    p_title TEXT,
    p_description TEXT,
    p_clue_1 TEXT,
    p_clue_2 TEXT,
    p_clue_3 TEXT,
    p_pearls_clue_1 INT,
    p_pearls_clue_2 INT,
    p_pearls_clue_3 INT,
    p_reveal_photo_url TEXT,
    p_status TEXT,
    p_starts_at TIMESTAMPTZ,
    p_closes_at TIMESTAMPTZ
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_id UUID;
BEGIN
    PERFORM public.assert_admin();

    IF p_id IS NOT NULL AND EXISTS (SELECT 1 FROM public.progressive_clue_challenges WHERE id = p_id) THEN
        UPDATE public.progressive_clue_challenges
        SET player_id = p_player_id,
            target_player_name = p_target_player_name,
            title = p_title,
            description = p_description,
            clue_1 = p_clue_1,
            clue_2 = p_clue_2,
            clue_3 = p_clue_3,
            pearls_clue_1 = COALESCE(p_pearls_clue_1, 60),
            pearls_clue_2 = COALESCE(p_pearls_clue_2, 35),
            pearls_clue_3 = COALESCE(p_pearls_clue_3, 15),
            reveal_photo_url = p_reveal_photo_url,
            status = COALESCE(p_status, 'published'),
            starts_at = COALESCE(p_starts_at, now()),
            closes_at = COALESCE(p_closes_at, now() + INTERVAL '3 days')
        WHERE id = p_id
        RETURNING id INTO v_id;
    ELSE
        INSERT INTO public.progressive_clue_challenges (
            player_id, target_player_name, title, description, clue_1, clue_2, clue_3, pearls_clue_1, pearls_clue_2, pearls_clue_3, reveal_photo_url, status, starts_at, closes_at
        ) VALUES (
            p_player_id, p_target_player_name, p_title, p_description, p_clue_1, p_clue_2, p_clue_3, COALESCE(p_pearls_clue_1, 60), COALESCE(p_pearls_clue_2, 35), COALESCE(p_pearls_clue_3, 15), p_reveal_photo_url, COALESCE(p_status, 'published'), COALESCE(p_starts_at, now()), COALESCE(p_closes_at, now() + INTERVAL '3 days')
        ) RETURNING id INTO v_id;
    END IF;

    RETURN v_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_upsert_progressive_clue FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_upsert_progressive_clue TO authenticated;
