-- Migration: 20261011000039_fix_admin_update_ads_settings.sql
-- Description: Fix UPDATE safeupdate without WHERE clause in admin_update_ads_settings,
--              ensure economy_settings has an initial row, and reload PostgREST schema cache.

-- 1. Ensure at least one row exists in economy_settings
INSERT INTO public.economy_settings (
    daily_pearl_cap,
    weekly_pearl_cap,
    streak_bonus_config,
    ads_enabled,
    daily_ad_views,
    block_size,
    ad_min_seconds,
    ad_min_account_age_days,
    ad_min_trivias_completed
)
SELECT
    500,
    2500,
    '{"streak_3_days": 100, "streak_7_days": 300}'::jsonb,
    true,
    50,
    10,
    6,
    3,
    1
WHERE NOT EXISTS (
    SELECT 1 FROM public.economy_settings
);

-- 2. Replace admin_update_ads_settings with safe WHERE clause and fallback INSERT
CREATE OR REPLACE FUNCTION public.admin_update_ads_settings(p_settings JSONB)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_enabled BOOLEAN;
    v_daily_views INT;
    v_block_size INT;
    v_min_sec INT;
    v_min_age INT;
    v_min_trivias INT;
    v_tiers JSONB;
    v_tier RECORD;
    v_old_settings JSONB;
    v_latest_id UUID;
BEGIN
    PERFORM public.assert_admin();

    v_enabled := COALESCE((p_settings->>'ads_enabled')::boolean, true);
    v_daily_views := COALESCE((p_settings->>'daily_ad_views')::int, 50);
    v_block_size := COALESCE((p_settings->>'block_size')::int, 10);
    v_min_sec := COALESCE((p_settings->>'ad_min_seconds')::int, 6);
    v_min_age := COALESCE((p_settings->>'ad_min_account_age_days')::int, 3);
    v_min_trivias := COALESCE((p_settings->>'ad_min_trivias_completed')::int, 1);
    v_tiers := p_settings->'reward_tiers';

    IF v_daily_views <= 0 OR v_block_size <= 0 OR v_min_sec <= 0 THEN
        RAISE EXCEPTION 'Los parámetros numéricos deben ser mayores a 0.';
    END IF;

    IF v_daily_views % v_block_size != 0 THEN
        RAISE EXCEPTION 'El límite diario (%) debe ser múltiplo del tamaño de bloque (%).', v_daily_views, v_block_size;
    END IF;

    -- Fetch latest economy settings row
    SELECT id, jsonb_build_object(
        'ads_enabled', ads_enabled,
        'daily_ad_views', daily_ad_views,
        'block_size', block_size,
        'ad_min_seconds', ad_min_seconds,
        'ad_min_account_age_days', ad_min_account_age_days,
        'ad_min_trivias_completed', ad_min_trivias_completed
    ) INTO v_latest_id, v_old_settings
    FROM public.economy_settings
    ORDER BY created_at DESC LIMIT 1;

    IF v_latest_id IS NOT NULL THEN
        -- Safe UPDATE targeting specific ID
        UPDATE public.economy_settings
        SET ads_enabled = v_enabled,
            daily_ad_views = v_daily_views,
            block_size = v_block_size,
            ad_min_seconds = v_min_sec,
            ad_min_account_age_days = v_min_age,
            ad_min_trivias_completed = v_min_trivias
        WHERE id = v_latest_id;
    ELSE
        -- Fallback INSERT if no economy settings existed
        INSERT INTO public.economy_settings (
            daily_pearl_cap,
            weekly_pearl_cap,
            streak_bonus_config,
            ads_enabled,
            daily_ad_views,
            block_size,
            ad_min_seconds,
            ad_min_account_age_days,
            ad_min_trivias_completed
        ) VALUES (
            500,
            2500,
            '{"streak_3_days": 100, "streak_7_days": 300}'::jsonb,
            v_enabled,
            v_daily_views,
            v_block_size,
            v_min_sec,
            v_min_age,
            v_min_trivias
        ) RETURNING id INTO v_latest_id;
    END IF;

    -- Update reward tiers if provided
    IF v_tiers IS NOT NULL AND jsonb_array_length(v_tiers) > 0 THEN
        FOR v_tier IN SELECT * FROM jsonb_to_recordset(v_tiers) AS x(block_number int, pearls int) LOOP
            IF v_tier.block_number IS NOT NULL AND v_tier.pearls IS NOT NULL AND v_tier.pearls > 0 THEN
                INSERT INTO public.ad_reward_tiers (block_number, pearls)
                VALUES (v_tier.block_number, v_tier.pearls)
                ON CONFLICT (block_number) DO UPDATE SET pearls = EXCLUDED.pearls, updated_at = NOW();
            END IF;
        END LOOP;
    END IF;

    -- Audit log entry
    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        v_admin_id, 'update_ads_settings', 'economy_settings', COALESCE(v_latest_id::text, '1'),
        v_old_settings, p_settings
    );

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.admin_update_ads_settings(JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_ads_settings(JSONB) TO authenticated, service_role;

-- 3. Update get_ads_progress to include ads_enabled flag
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
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT ads_enabled, daily_ad_views, block_size, ad_min_seconds, ad_min_account_age_days, ad_min_trivias_completed
    INTO v_eco
    FROM public.economy_settings
    ORDER BY created_at DESC LIMIT 1;

    -- Check daily completed count
    SELECT COALESCE(completed_count, 0) INTO v_completed
    FROM public.ad_daily_progress
    WHERE user_id = v_uid AND day = v_today;

    -- Calculate total pearls earned from ads today
    SELECT COALESCE(SUM(amount), 0) INTO v_earned_today
    FROM public.ledger_entries
    WHERE fan_id = v_uid
      AND type = 'ad_reward'
      AND (created_at AT TIME ZONE 'America/Caracas')::date = v_today;

    -- Check conditions if fan can watch ads
    IF v_eco.ads_enabled IS NOT TRUE THEN
        v_can_watch := false;
        v_cant_reason := 'ADS_DISABLED';
    ELSIF v_completed >= v_eco.daily_ad_views THEN
        v_can_watch := false;
        v_cant_reason := 'AD_DAILY_LIMIT';
    ELSE
        SELECT EXTRACT(DAY FROM (NOW() - created_at))::int INTO v_account_age_days
        FROM public.profiles WHERE id = v_uid;

        IF COALESCE(v_account_age_days, 0) < v_eco.ad_min_account_age_days THEN
            v_can_watch := false;
            v_cant_reason := 'ACCOUNT_TOO_NEW';
        ELSE
            SELECT COUNT(*) INTO v_trivias_count
            FROM public.trivia_attempts
            WHERE fan_id = v_uid AND submitted_at IS NOT NULL;

            IF v_trivias_count < v_eco.ad_min_trivias_completed THEN
                v_can_watch := false;
                v_cant_reason := 'TRIVIAS_REQUIRED';
            END IF;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'ads_enabled', COALESCE(v_eco.ads_enabled, false),
        'completed_today', v_completed,
        'daily_limit', v_eco.daily_ad_views,
        'block_size', v_eco.block_size,
        'block_progress', v_completed % v_eco.block_size,
        'next_block_number', (v_completed / v_eco.block_size) + 1,
        'pearls_earned_today', v_earned_today,
        'can_watch', v_can_watch,
        'cant_reason', v_cant_reason,
        'ad_min_seconds', v_eco.ad_min_seconds
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.get_ads_progress() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_ads_progress() TO authenticated, service_role;

-- 4. Fix audit_log table and column references in login modal admin functions
CREATE OR REPLACE FUNCTION public.admin_upsert_login_modal_slide(
    p_id UUID,
    p_position INT,
    p_image_url TEXT,
    p_title TEXT,
    p_subtitle TEXT,
    p_cta_label TEXT,
    p_cta_url TEXT,
    p_status TEXT,
    p_starts_at TIMESTAMPTZ,
    p_ends_at TIMESTAMPTZ
)
RETURNS JSONB AS $$
DECLARE
    v_slide_id UUID;
    v_clean_title TEXT := TRIM(p_title);
    v_clean_subtitle TEXT := TRIM(COALESCE(p_subtitle, ''));
    v_clean_cta_label TEXT := COALESCE(NULLIF(TRIM(p_cta_label), ''), 'Ver más');
    v_status TEXT := COALESCE(p_status, 'draft');
BEGIN
    PERFORM public.assert_admin();
    PERFORM public.validate_login_modal_urls(p_image_url, p_cta_url);

    IF p_position < 1 OR p_position > 5 THEN
        RAISE EXCEPTION 'La posición de la diapositiva debe estar entre 1 y 5.';
    END IF;

    IF v_clean_title IS NULL OR v_clean_title = '' OR CHAR_LENGTH(v_clean_title) > 80 THEN
        RAISE EXCEPTION 'El título es obligatorio y debe tener como máximo 80 caracteres.';
    END IF;

    IF CHAR_LENGTH(v_clean_subtitle) > 160 THEN
        RAISE EXCEPTION 'El subtítulo no puede exceder 160 caracteres.';
    END IF;

    IF p_id IS NOT NULL THEN
        UPDATE public.login_modal_slides
        SET position = p_position,
            image_url = p_image_url,
            title = v_clean_title,
            subtitle = v_clean_subtitle,
            cta_label = v_clean_cta_label,
            cta_url = TRIM(p_cta_url),
            status = v_status,
            starts_at = COALESCE(p_starts_at, NOW()),
            ends_at = p_ends_at,
            updated_at = NOW()
        WHERE id = p_id;
        v_slide_id := p_id;
    ELSE
        INSERT INTO public.login_modal_slides (
            position, image_url, title, subtitle, cta_label, cta_url, status, starts_at, ends_at, created_by
        )
        VALUES (
            p_position, p_image_url, v_clean_title, v_clean_subtitle, v_clean_cta_label, TRIM(p_cta_url), v_status, COALESCE(p_starts_at, NOW()), p_ends_at, auth.uid()
        )
        RETURNING id INTO v_slide_id;
    END IF;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        auth.uid(),
        'admin_upsert_login_modal_slide',
        'login_modal_slides',
        v_slide_id::text,
        NULL,
        jsonb_build_object('title', v_clean_title, 'position', p_position, 'status', v_status)
    );

    RETURN jsonb_build_object('success', true, 'id', v_slide_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.admin_upsert_login_modal_slide(UUID, INT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_upsert_login_modal_slide(UUID, INT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_delete_login_modal_slide(p_slide_id UUID)
RETURNS JSONB AS $$
BEGIN
    PERFORM public.assert_admin();

    DELETE FROM public.login_modal_slides WHERE id = p_slide_id;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        auth.uid(),
        'admin_delete_login_modal_slide',
        'login_modal_slides',
        p_slide_id::text,
        jsonb_build_object('deleted_id', p_slide_id),
        NULL
    );

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.admin_delete_login_modal_slide(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_delete_login_modal_slide(UUID) TO authenticated, service_role;

-- 5. Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
