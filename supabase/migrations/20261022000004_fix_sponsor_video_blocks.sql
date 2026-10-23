-- Migration: 20261022000004_fix_sponsor_video_blocks.sql
-- Description: Award points only every 10 sponsor videos (5 blocks of 10 = max 60 points/day)

CREATE OR REPLACE FUNCTION public.claim_video_points(p_video_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid UUID;
    v_video RECORD;
    v_today DATE := (NOW() AT TIME ZONE 'America/Caracas')::date;
    v_completed_count INT;
    v_block_number INT;
    v_points_to_award INT := 0;
    v_source_id TEXT;
    v_ledger_id UUID := gen_random_uuid();
    v_new_balance INT := 0;
    v_is_block_completed BOOLEAN := false;
BEGIN
    v_uid := public.assert_active_verified_fan();

    -- Verify video exists and is active
    SELECT * INTO v_video FROM public.sponsor_videos WHERE id = p_video_id AND is_active = true;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El video de patrocinador no está disponible o ha sido desactivado.';
    END IF;

    -- Upsert and increment ad_daily_progress atomically
    INSERT INTO public.ad_daily_progress (user_id, day, completed_count, updated_at)
    VALUES (v_uid, v_today, 1, NOW())
    ON CONFLICT (user_id, day)
    DO UPDATE SET
        completed_count = public.ad_daily_progress.completed_count + 1,
        updated_at = NOW()
    RETURNING completed_count INTO v_completed_count;

    -- Enforce maximum 50 videos limit per day
    IF v_completed_count > 50 THEN
        UPDATE public.ad_daily_progress
        SET completed_count = 50, updated_at = NOW()
        WHERE user_id = v_uid AND day = v_today;

        RAISE EXCEPTION 'Has alcanzado el límite diario de videos patrocinados (50 al día). Vuelve mañana para seguir acumulando.';
    END IF;

    -- Award points ONLY when completing a block of 10 videos (10, 20, 30, 40, 50)
    IF v_completed_count % 10 = 0 THEN
        v_is_block_completed := true;
        v_block_number := v_completed_count / 10;

        -- Point distribution per block:
        -- Bloque 1 (video 10): 5 pts
        -- Bloque 2 (video 20): 10 pts
        -- Bloque 3 (video 30): 15 pts
        -- Bloque 4 (video 40): 15 pts
        -- Bloque 5 (video 50): 15 pts
        -- Total máximo diario: 5 + 10 + 15 + 15 + 15 = 60 pts
        IF v_block_number = 1 THEN
            v_points_to_award := 5;
        ELSIF v_block_number = 2 THEN
            v_points_to_award := 10;
        ELSE
            v_points_to_award := 15;
        END IF;

        -- Lock wallet for atomic balance update
        SELECT balance_cache INTO v_new_balance 
        FROM public.wallets 
        WHERE fan_id = v_uid 
        FOR UPDATE;

        IF NOT FOUND THEN
            INSERT INTO public.wallets (fan_id, balance_cache, created_at, updated_at)
            VALUES (v_uid, 0, NOW(), NOW())
            RETURNING balance_cache INTO v_new_balance;
        END IF;

        -- Idempotent source_id for this user, day and block
        v_source_id := 'video_block:' || v_uid::text || ':' || v_today::text || ':' || v_block_number::text;

        -- Insert ledger entry atomically
        INSERT INTO public.ledger_entries (
            id, fan_id, amount, type, status, source_type, source_id, note
        ) VALUES (
            v_ledger_id, v_uid, v_points_to_award, 'ad_reward', 'confirmed', 'sponsor_video_block', v_source_id,
            'Puntos por completar bloque #' || v_block_number::text || ' de 10 videos patrocinados'
        );

        -- Update wallet balance cache
        UPDATE public.wallets
        SET balance_cache = balance_cache + v_points_to_award,
            updated_at = NOW()
        WHERE fan_id = v_uid
        RETURNING balance_cache INTO v_new_balance;

        -- Update blocks_paid in ad_daily_progress
        UPDATE public.ad_daily_progress
        SET blocks_paid = v_block_number, updated_at = NOW()
        WHERE user_id = v_uid AND day = v_today;
    ELSE
        SELECT COALESCE(balance_cache, 0) INTO v_new_balance FROM public.wallets WHERE fan_id = v_uid;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'completed_today', v_completed_count,
        'block_completed', v_is_block_completed,
        'block_number', COALESCE(v_block_number, (v_completed_count / 10) + 1),
        'points_awarded', v_points_to_award,
        'balance', COALESCE(v_new_balance, 0),
        'block_progress', v_completed_count % 10,
        'videos_until_next_block', CASE WHEN v_completed_count >= 50 THEN 0 ELSE 10 - (v_completed_count % 10) END,
        'daily_limit', 50,
        'max_daily_points', 60
    );
END;
$$;

REVOKE ALL ON FUNCTION public.claim_video_points(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_video_points(UUID) TO authenticated;

-- Function to get daily video progress and tier reward
CREATE OR REPLACE FUNCTION public.get_daily_video_progress()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid UUID;
    v_today DATE := (NOW() AT TIME ZONE 'America/Caracas')::date;
    v_completed_count INT := 0;
    v_points_today INT := 0;
    v_current_tier_reward INT;
    v_current_block INT;
BEGIN
    v_uid := public.assert_active_verified_fan();

    SELECT COALESCE(completed_count, 0)
    INTO v_completed_count
    FROM public.ad_daily_progress
    WHERE user_id = v_uid AND day = v_today;

    SELECT COALESCE(SUM(amount), 0)
    INTO v_points_today
    FROM public.ledger_entries
    WHERE fan_id = v_uid 
      AND (source_type = 'sponsor_video_block' OR source_type = 'sponsor_video')
      AND (created_at AT TIME ZONE 'America/Caracas')::date = v_today;

    v_current_block := (v_completed_count / 10) + 1;
    IF v_current_block = 1 THEN
        v_current_tier_reward := 5;
    ELSIF v_current_block = 2 THEN
        v_current_tier_reward := 10;
    ELSE
        v_current_tier_reward := 15;
    END IF;

    RETURN jsonb_build_object(
        'completed_today', v_completed_count,
        'points_earned_today', v_points_today,
        'current_tier_reward', v_current_tier_reward,
        'block_progress', v_completed_count % 10,
        'videos_until_next_block', CASE WHEN v_completed_count >= 50 THEN 0 ELSE 10 - (v_completed_count % 10) END,
        'max_daily', 50,
        'max_daily_points', 60
    );
END;
$$;

REVOKE ALL ON FUNCTION public.get_daily_video_progress() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_daily_video_progress() TO authenticated;
