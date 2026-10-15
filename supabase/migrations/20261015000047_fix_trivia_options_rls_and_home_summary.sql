-- Migration: 20261015000047_fix_trivia_options_rls_and_home_summary.sql
-- Description: Allow staff and admin to read and manage trivia_options; fix home_summary played flag to only consider won trivias (pearls_awarded > 0).

-- 1. Allow staff and admin to read and manage trivia_options
DROP POLICY IF EXISTS "Trivia Options Admin Select" ON public.trivia_options;
DROP POLICY IF EXISTS "Trivia Options Admin All" ON public.trivia_options;
DROP POLICY IF EXISTS "Trivia Options Staff Select" ON public.trivia_options;
DROP POLICY IF EXISTS "Trivia Options Staff All" ON public.trivia_options;

CREATE POLICY "Trivia Options Staff Select" ON public.trivia_options 
FOR SELECT TO authenticated 
USING (public.is_staff_or_admin(auth.uid()));

CREATE POLICY "Trivia Options Staff All" ON public.trivia_options 
FOR ALL TO authenticated 
USING (public.is_staff_or_admin(auth.uid()));

-- 2. Update home_summary: only mark active_trivia as played if fan actually won it (pearls_awarded > 0)
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

    -- Active Trivia (played is TRUE only if fan won it with pearls_awarded > 0, matching unlimited retries policy)
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
            WHERE ta.fan_id = v_uid AND ta.trivia_id = t.id AND ta.submitted_at IS NOT NULL AND ta.pearls_awarded > 0
        )
    ) INTO v_active_trivia
    FROM trivias t
    WHERE t.status = 'published' AND NOW() BETWEEN t.starts_at AND t.ends_at
    ORDER BY t.starts_at DESC
    LIMIT 1;

    -- Read-only Streak Calculation (No ledger side-effects)
    v_streak := get_streak_info(v_uid);

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

REVOKE ALL ON FUNCTION public.home_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.home_summary() TO authenticated, service_role;
