-- Migration: 20261011000040_fix_get_ads_progress_null_handling.sql
-- Description: Fix NULL return values in get_ads_progress when user has no daily progress rows yet,
--              ensuring safe zero defaults and robust block calculations.

CREATE OR REPLACE FUNCTION public.get_ads_progress()
RETURNS JSONB AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_today DATE := (NOW() AT TIME ZONE 'America/Caracas')::date;
    v_eco RECORD;
    v_completed INT := 0;
    v_earned_today INT := 0;
    v_account_age_days INT;
    v_trivias_count INT;
    v_can_watch BOOLEAN := true;
    v_cant_reason TEXT := NULL;
    v_block_size INT := 10;
    v_daily_limit INT := 50;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT ads_enabled, daily_ad_views, block_size, ad_min_seconds, ad_min_account_age_days, ad_min_trivias_completed
    INTO v_eco
    FROM public.economy_settings
    ORDER BY created_at DESC LIMIT 1;

    IF v_eco IS NOT NULL THEN
        v_block_size := COALESCE(v_eco.block_size, 10);
        v_daily_limit := COALESCE(v_eco.daily_ad_views, 50);
    END IF;

    -- Check daily completed count
    SELECT COALESCE(completed_count, 0) INTO v_completed
    FROM public.ad_daily_progress
    WHERE user_id = v_uid AND day = v_today;

    -- When SELECT INTO finds no rows, PL/pgSQL assigns NULL to v_completed. Force safe 0 fallback.
    v_completed := COALESCE(v_completed, 0);

    -- Calculate total pearls earned from ads today
    SELECT COALESCE(SUM(amount), 0) INTO v_earned_today
    FROM public.ledger_entries
    WHERE fan_id = v_uid
      AND type = 'ad_reward'
      AND (created_at AT TIME ZONE 'America/Caracas')::date = v_today;

    -- Force safe 0 fallback
    v_earned_today := COALESCE(v_earned_today, 0);

    -- Check conditions if fan can watch ads
    IF v_eco.ads_enabled IS NOT TRUE THEN
        v_can_watch := false;
        v_cant_reason := 'ADS_DISABLED';
    ELSIF v_completed >= v_daily_limit THEN
        v_can_watch := false;
        v_cant_reason := 'AD_DAILY_LIMIT';
    ELSE
        SELECT EXTRACT(DAY FROM (NOW() - created_at))::int INTO v_account_age_days
        FROM public.profiles WHERE id = v_uid;

        IF COALESCE(v_account_age_days, 0) < COALESCE(v_eco.ad_min_account_age_days, 3) THEN
            v_can_watch := false;
            v_cant_reason := 'ACCOUNT_TOO_NEW';
        ELSE
            SELECT COUNT(*) INTO v_trivias_count
            FROM public.trivia_attempts
            WHERE fan_id = v_uid AND submitted_at IS NOT NULL;

            IF v_trivias_count < COALESCE(v_eco.ad_min_trivias_completed, 1) THEN
                v_can_watch := false;
                v_cant_reason := 'TRIVIAS_REQUIRED';
            END IF;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'ads_enabled', COALESCE(v_eco.ads_enabled, false),
        'completed_today', v_completed,
        'daily_limit', v_daily_limit,
        'block_size', v_block_size,
        'block_progress', CASE WHEN v_block_size > 0 THEN v_completed % v_block_size ELSE 0 END,
        'next_block_number', CASE WHEN v_block_size > 0 THEN (v_completed / v_block_size) + 1 ELSE 1 END,
        'pearls_earned_today', v_earned_today,
        'can_watch', v_can_watch,
        'cant_reason', v_cant_reason,
        'ad_min_seconds', COALESCE(v_eco.ad_min_seconds, 6)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.get_ads_progress() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_ads_progress() TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';
