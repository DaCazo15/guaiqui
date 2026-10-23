-- Migration: 20261022000002_update_sponsor_video_tiers.sql
-- Description: Update claim_video_points to support tiered points (1-10: 5pts, 11-20: 10pts, 21-50: 15pts) and 50 daily limit

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
    v_source_id TEXT;
    v_ledger_id UUID := gen_random_uuid();
    v_new_balance INT;
    v_views_today INT;
    v_points_to_award INT;
BEGIN
    v_uid := public.assert_active_verified_fan();

    -- Verify video exists and is active
    SELECT * INTO v_video FROM public.sponsor_videos WHERE id = p_video_id AND is_active = true;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El video de patrocinador no está disponible o ha sido desactivado.';
    END IF;

    -- Count video claims today
    SELECT COUNT(*) INTO v_views_today
    FROM public.ledger_entries
    WHERE fan_id = v_uid 
      AND source_type = 'sponsor_video' 
      AND (created_at AT TIME ZONE 'America/Caracas')::date = v_today;

    IF v_views_today >= 50 THEN
        RAISE EXCEPTION 'Has alcanzado el límite diario de videos patrocinados (50 al día). Vuelve mañana para seguir acumulando.';
    END IF;

    -- Calculate points by tier:
    -- Primeros 10 videos (0 a 9 vistos): 5 puntos
    -- Próximos 10 videos (10 a 19 vistos): 10 puntos
    -- A partir del video 21 (20 a 49 vistos): 15 puntos
    IF v_views_today < 10 THEN
        v_points_to_award := 5;
    ELSIF v_views_today < 20 THEN
        v_points_to_award := 10;
    ELSE
        v_points_to_award := 15;
    END IF;

    -- Lock wallet for update to guarantee atomic balance calculation
    SELECT balance_cache INTO v_new_balance 
    FROM public.wallets 
    WHERE fan_id = v_uid 
    FOR UPDATE;

    IF NOT FOUND THEN
        INSERT INTO public.wallets (fan_id, balance_cache, created_at, updated_at)
        VALUES (v_uid, 0, NOW(), NOW())
        RETURNING balance_cache INTO v_new_balance;
    END IF;

    -- Generate idempotent sequential source_id for this day and slot
    v_source_id := 'video_view:' || v_uid::text || ':' || v_today::text || ':' || (v_views_today + 1)::text;

    -- Insert ledger entry atomically
    INSERT INTO public.ledger_entries (
        id, fan_id, amount, type, status, source_type, source_id, note
    ) VALUES (
        v_ledger_id, v_uid, v_points_to_award, 'ad_reward', 'confirmed', 'sponsor_video', v_source_id,
        'Puntos por video patrocinado #' || (v_views_today + 1)::text || ' (' || COALESCE(v_video.sponsor_name, v_video.title) || ')'
    );

    -- Update wallet balance cache
    UPDATE public.wallets
    SET balance_cache = balance_cache + v_points_to_award,
        updated_at = NOW()
    WHERE fan_id = v_uid
    RETURNING balance_cache INTO v_new_balance;

    -- Keep ad_daily_progress in sync
    INSERT INTO public.ad_daily_progress (user_id, day, completed_count, updated_at)
    VALUES (v_uid, v_today, 1, NOW())
    ON CONFLICT (user_id, day)
    DO UPDATE SET
        completed_count = public.ad_daily_progress.completed_count + 1,
        updated_at = NOW();

    RETURN jsonb_build_object(
        'success', true,
        'already_claimed', false,
        'message', '¡Puntos acreditados con éxito a tu billetera!',
        'balance', v_new_balance,
        'points_awarded', v_points_to_award,
        'completed_today', v_views_today + 1,
        'daily_limit', 50
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
    v_views_today INT;
    v_points_today INT;
    v_tier_reward INT;
BEGIN
    v_uid := public.assert_active_verified_fan();

    SELECT 
        COUNT(*),
        COALESCE(SUM(amount), 0)
    INTO v_views_today, v_points_today
    FROM public.ledger_entries
    WHERE fan_id = v_uid 
      AND source_type = 'sponsor_video' 
      AND (created_at AT TIME ZONE 'America/Caracas')::date = v_today;

    IF v_views_today < 10 THEN
        v_tier_reward := 5;
    ELSIF v_views_today < 20 THEN
        v_tier_reward := 10;
    ELSE
        v_tier_reward := 15;
    END IF;

    RETURN jsonb_build_object(
        'completed_today', v_views_today,
        'points_earned_today', v_points_today,
        'current_tier_reward', v_tier_reward,
        'max_daily', 50
    );
END;
$$;

REVOKE ALL ON FUNCTION public.get_daily_video_progress() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_daily_video_progress() TO authenticated;
