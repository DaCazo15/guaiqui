-- Migration: 20261007000009_fase6_trivias_and_leaderboard.sql
-- Description: Backend RPC functions for Trivias, Daily Streak Bonus, Leaderboard, and Home Summary.

-- 1. Get Attempt Questions (Strictly hides is_correct, checks attempt validity)
CREATE OR REPLACE FUNCTION public.get_attempt_questions(p_attempt_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_fan_id UUID := auth.uid();
    v_attempt trivia_attempts%ROWTYPE;
    v_questions JSONB;
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT * INTO v_attempt FROM trivia_attempts WHERE id = p_attempt_id AND fan_id = v_fan_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Trivia attempt not found or unauthorized.';
    END IF;

    IF v_attempt.submitted_at IS NOT NULL THEN
        RAISE EXCEPTION 'TRIVIA_ALREADY_PLAYED';
    END IF;

    IF NOW() > v_attempt.expires_at THEN
        RAISE EXCEPTION 'ATTEMPT_EXPIRED';
    END IF;

    -- Fetch questions without is_correct
    SELECT jsonb_agg(
        jsonb_build_object(
            'question_id', q.id,
            'question_text', q.question_text,
            'points', q.points,
            'options', (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'option_id', o.id,
                        'option_text', o.option_text
                    )
                ) FROM trivia_options o WHERE o.question_id = q.id
            )
        ) ORDER BY hashtext(q.id::text || v_attempt.seed::text)
    ) INTO v_questions
    FROM trivia_questions q
    WHERE q.trivia_id = v_attempt.trivia_id;

    RETURN jsonb_build_object(
        'attempt_id', v_attempt.id,
        'trivia_id', v_attempt.trivia_id,
        'expires_at', v_attempt.expires_at,
        'seed', v_attempt.seed,
        'questions', COALESCE(v_questions, '[]'::jsonb)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 2. Daily Streak Bonus Logic (Atomic ledger payout, max 1 per day)
CREATE OR REPLACE FUNCTION public.calculate_and_apply_streak_bonus(p_fan_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_today DATE := CURRENT_DATE;
    v_already_awarded BOOLEAN;
    v_streak_days INT := 0;
    v_day_check DATE;
    v_bonus_amount INT := 0;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM ledger_entries
        WHERE fan_id = p_fan_id
          AND type = 'streak_bonus'
          AND created_at::date = v_today
    ) INTO v_already_awarded;

    -- Calculate consecutive days up to today
    v_day_check := v_today;
    LOOP
        IF EXISTS (
            SELECT 1 FROM trivia_attempts
            WHERE fan_id = p_fan_id
              AND submitted_at IS NOT NULL
              AND submitted_at::date = v_day_check
        ) THEN
            v_streak_days := v_streak_days + 1;
            v_day_check := v_day_check - INTERVAL '1 day';
        ELSE
            EXIT;
        END IF;
    END LOOP;

    IF v_already_awarded THEN
        RETURN jsonb_build_object('streak_days', v_streak_days, 'bonus_awarded', 0, 'already_awarded_today', true);
    END IF;

    -- Award milestone bonus
    IF v_streak_days >= 7 THEN
        v_bonus_amount := 300;
    ELSIF v_streak_days >= 3 THEN
        v_bonus_amount := 100;
    ELSIF v_streak_days >= 1 THEN
        v_bonus_amount := 20;
    END IF;

    IF v_bonus_amount > 0 THEN
        INSERT INTO ledger_entries (
            fan_id, amount, type, status, source_type, source_id, note
        ) VALUES (
            p_fan_id, v_bonus_amount, 'streak_bonus', 'confirmed', 'streak', v_today::text || '-' || v_streak_days,
            'Bono de racha diaria (' || v_streak_days || ' días consecutivos)'
        ) ON CONFLICT DO NOTHING;

        INSERT INTO wallets (fan_id, balance_cache)
        VALUES (p_fan_id, v_bonus_amount)
        ON CONFLICT (fan_id)
        DO UPDATE SET balance_cache = wallets.balance_cache + v_bonus_amount, updated_at = NOW();
    END IF;

    RETURN jsonb_build_object(
        'streak_days', v_streak_days,
        'bonus_awarded', v_bonus_amount,
        'already_awarded_today', false
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 3. Leaderboard RPC (Excludes suspended/deleted users, held/revoked pearls)
CREATE OR REPLACE FUNCTION public.get_leaderboard(p_period TEXT DEFAULT 'monthly')
RETURNS JSONB AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_start_date TIMESTAMPTZ;
    v_leaderboard JSONB;
BEGIN
    IF p_period = 'weekly' THEN
        v_start_date := date_trunc('week', NOW());
    ELSE
        v_start_date := date_trunc('month', NOW());
    END IF;

    SELECT jsonb_agg(
        jsonb_build_object(
            'rank', r.rank_number,
            'user_id', r.fan_id,
            'display_name', r.display_name,
            'avatar_url', r.avatar_url,
            'pearls_earned', r.total_pearls,
            'is_current_user', (r.fan_id = v_uid)
        )
    ) INTO v_leaderboard
    FROM (
        SELECT 
            p.id AS fan_id,
            p.display_name,
            p.avatar_url,
            COALESCE(SUM(l.amount), 0)::int AS total_pearls,
            ROW_NUMBER() OVER (ORDER BY COALESCE(SUM(l.amount), 0) DESC, p.created_at ASC) AS rank_number
        FROM profiles p
        JOIN ledger_entries l ON l.fan_id = p.id
        WHERE p.status = 'active'
          AND p.deleted_at IS NULL
          AND l.status = 'confirmed'
          AND l.type IN ('trivia_reward', 'bonus', 'streak_bonus')
          AND l.created_at >= v_start_date
        GROUP BY p.id, p.display_name, p.avatar_url, p.created_at
        HAVING COALESCE(SUM(l.amount), 0) > 0
        ORDER BY total_pearls DESC
        LIMIT 50
    ) r;

    RETURN jsonb_build_object(
        'period', p_period,
        'leaderboard', COALESCE(v_leaderboard, '[]'::jsonb)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 4. Home Summary RPC (Aggregates balance, trivia, streak, game, rank in 1 call)
CREATE OR REPLACE FUNCTION public.home_summary()
RETURNS JSONB AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_balance INT := 0;
    v_active_trivia JSONB;
    v_streak JSONB;
    v_next_game JSONB;
    v_my_rank INT := NULL;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    -- Balance
    SELECT COALESCE(balance_cache, 0) INTO v_balance FROM wallets WHERE fan_id = v_uid;

    -- Active Trivia
    SELECT jsonb_build_object(
        'id', t.id,
        'title', t.title,
        'description', t.description,
        'time_limit_seconds', t.time_limit_seconds,
        'starts_at', t.starts_at,
        'ends_at', t.ends_at,
        'max_attempts', t.max_attempts,
        'played', EXISTS (
            SELECT 1 FROM trivia_attempts ta 
            WHERE ta.fan_id = v_uid AND ta.trivia_id = t.id AND ta.submitted_at IS NOT NULL
        )
    ) INTO v_active_trivia
    FROM trivias t
    WHERE t.status = 'published' AND NOW() BETWEEN t.starts_at AND t.ends_at
    ORDER BY t.starts_at DESC
    LIMIT 1;

    -- Streak
    v_streak := calculate_and_apply_streak_bonus(v_uid);

    -- Next Game
    SELECT jsonb_build_object(
        'id', g.id,
        'opponent', g.opponent,
        'location', g.location,
        'game_date', g.game_date,
        'is_home', g.is_home,
        'status', g.status
    ) INTO v_next_game
    FROM games g
    WHERE g.status IN ('scheduled', 'live')
    ORDER BY g.game_date ASC
    LIMIT 1;

    -- Rank
    SELECT rank_number INTO v_my_rank
    FROM (
        SELECT 
            p.id AS fan_id,
            ROW_NUMBER() OVER (ORDER BY COALESCE(SUM(l.amount), 0) DESC) AS rank_number
        FROM profiles p
        JOIN ledger_entries l ON l.fan_id = p.id
        WHERE p.status = 'active' AND p.deleted_at IS NULL AND l.status = 'confirmed' AND l.created_at >= date_trunc('month', NOW())
        GROUP BY p.id
    ) ranks
    WHERE ranks.fan_id = v_uid;

    RETURN jsonb_build_object(
        'balance', v_balance,
        'active_trivia', v_active_trivia,
        'streak', v_streak,
        'next_game', v_next_game,
        'my_rank', v_my_rank
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 5. Revoke from PUBLIC/anon, grant to authenticated/service_role
REVOKE ALL ON FUNCTION public.get_attempt_questions(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_attempt_questions(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.calculate_and_apply_streak_bonus(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.calculate_and_apply_streak_bonus(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.get_leaderboard(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_leaderboard(TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.home_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.home_summary() TO authenticated, service_role;
