-- ============================================================================
-- Migration: 20261020000001_check_email_and_handle_new_user.sql
-- Description: Adds service_role RPC to check email availability and
--              hardens handle_new_user to ingest registration metadata.
-- ============================================================================

-- 1. Helper function for service_role to check if email already exists in auth.users
CREATE OR REPLACE FUNCTION public.check_email_exists(p_email text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $$
BEGIN
    IF p_email IS NULL OR TRIM(p_email) = '' THEN
        RETURN FALSE;
    END IF;

    RETURN EXISTS (
        SELECT 1
        FROM auth.users
        WHERE LOWER(email) = LOWER(TRIM(p_email))
    );
END;
$$;

-- Security hardening: strictly revoke from public, anon, and authenticated. Only service_role can execute.
REVOKE ALL ON FUNCTION public.check_email_exists(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_email_exists(text) TO service_role;

-- 2. Error logging table for auth triggers if not already present
CREATE TABLE IF NOT EXISTS public.auth_trigger_errors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID,
    error_message TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.auth_trigger_errors ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.auth_trigger_errors FROM PUBLIC, anon, authenticated;

-- 3. Resilient handle_new_user trigger function ingesting registration metadata
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_is_staff BOOLEAN := false;
    v_random_suffix TEXT;
    v_meta JSONB;
    v_display_name TEXT;
    v_municipality TEXT;
    v_birth_date DATE;
    v_gender TEXT;
    v_fav_player UUID;
    v_shirt_size TEXT;
    v_referral TEXT;
    v_terms_at TIMESTAMPTZ;
    v_terms_ver TEXT;
    v_priv_at TIMESTAMPTZ;
    v_priv_ver TEXT;
    v_pearls_at TIMESTAMPTZ;
    v_pearls_ver TEXT;
BEGIN
    -- Check if user is staff member
    IF NEW.id IS NOT NULL THEN
        SELECT EXISTS (SELECT 1 FROM public.staff_members WHERE user_id = NEW.id) INTO v_is_staff;
    END IF;

    -- Staff accounts have dedicated onboarding; skip fan profile creation
    IF v_is_staff THEN
        RETURN NEW;
    END IF;

    v_random_suffix := floor(random() * 900000 + 100000)::text;
    v_meta := COALESCE(NEW.raw_user_meta_data, '{}'::jsonb);

    -- Extract display name with fallback to Fanático #XXXXXX
    v_display_name := NULLIF(TRIM(v_meta->>'display_name'), '');
    IF v_display_name IS NULL THEN
        v_display_name := 'Fanático #' || v_random_suffix;
    END IF;

    v_municipality := NULLIF(TRIM(v_meta->>'municipality'), '');
    v_gender := NULLIF(TRIM(v_meta->>'gender'), '');
    v_shirt_size := NULLIF(TRIM(v_meta->>'shirt_size'), '');
    v_referral := NULLIF(TRIM(v_meta->>'referral_source'), '');

    -- Safe birth_date extraction
    IF v_meta->>'birth_date' IS NOT NULL AND TRIM(v_meta->>'birth_date') <> '' THEN
        BEGIN
            v_birth_date := (v_meta->>'birth_date')::date;
        EXCEPTION WHEN OTHERS THEN
            v_birth_date := NULL;
        END;
    END IF;

    -- Safe favorite_player_id extraction
    IF v_meta->>'favorite_player_id' IS NOT NULL AND TRIM(v_meta->>'favorite_player_id') <> '' THEN
        BEGIN
            v_fav_player := (v_meta->>'favorite_player_id')::uuid;
        EXCEPTION WHEN OTHERS THEN
            v_fav_player := NULL;
        END;
    END IF;

    -- Legal acceptance timestamps & versions
    IF (v_meta->>'terms_accepted_at') IS NOT NULL THEN
        BEGIN
            v_terms_at := (v_meta->>'terms_accepted_at')::timestamptz;
        EXCEPTION WHEN OTHERS THEN
            v_terms_at := NOW();
        END;
    END IF;
    v_terms_ver := COALESCE(NULLIF(TRIM(v_meta->>'terms_version'), ''), 'v1.0');

    IF (v_meta->>'privacy_accepted_at') IS NOT NULL THEN
        BEGIN
            v_priv_at := (v_meta->>'privacy_accepted_at')::timestamptz;
        EXCEPTION WHEN OTHERS THEN
            v_priv_at := NOW();
        END;
    END IF;
    v_priv_ver := COALESCE(NULLIF(TRIM(v_meta->>'privacy_version'), ''), 'v1.0');

    IF (v_meta->>'pearls_rules_accepted_at') IS NOT NULL THEN
        BEGIN
            v_pearls_at := (v_meta->>'pearls_rules_accepted_at')::timestamptz;
        EXCEPTION WHEN OTHERS THEN
            v_pearls_at := NOW();
        END;
    END IF;
    v_pearls_ver := COALESCE(NULLIF(TRIM(v_meta->>'pearls_rules_version'), ''), 'v1.0');

    -- Insert or update profile
    INSERT INTO public.profiles (
        id,
        display_name,
        municipality,
        birth_date,
        gender,
        favorite_player_id,
        shirt_size,
        referral_source,
        status,
        terms_accepted_at,
        terms_version,
        privacy_accepted_at,
        privacy_version,
        pearls_rules_accepted_at,
        pearls_rules_version,
        created_at
    )
    VALUES (
        NEW.id,
        v_display_name,
        v_municipality,
        v_birth_date,
        v_gender,
        v_fav_player,
        v_shirt_size,
        v_referral,
        'active',
        v_terms_at,
        v_terms_ver,
        v_priv_at,
        v_priv_ver,
        v_pearls_at,
        v_pearls_ver,
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        display_name = COALESCE(NULLIF(EXCLUDED.display_name, ''), profiles.display_name),
        municipality = COALESCE(EXCLUDED.municipality, profiles.municipality),
        birth_date = COALESCE(EXCLUDED.birth_date, profiles.birth_date),
        gender = COALESCE(EXCLUDED.gender, profiles.gender),
        favorite_player_id = COALESCE(EXCLUDED.favorite_player_id, profiles.favorite_player_id),
        shirt_size = COALESCE(EXCLUDED.shirt_size, profiles.shirt_size),
        referral_source = COALESCE(EXCLUDED.referral_source, profiles.referral_source),
        terms_accepted_at = COALESCE(EXCLUDED.terms_accepted_at, profiles.terms_accepted_at),
        terms_version = COALESCE(EXCLUDED.terms_version, profiles.terms_version),
        privacy_accepted_at = COALESCE(EXCLUDED.privacy_accepted_at, profiles.privacy_accepted_at),
        privacy_version = COALESCE(EXCLUDED.privacy_version, profiles.privacy_version),
        pearls_rules_accepted_at = COALESCE(EXCLUDED.pearls_rules_accepted_at, profiles.pearls_rules_accepted_at),
        pearls_rules_version = COALESCE(EXCLUDED.pearls_rules_version, profiles.pearls_rules_version);

    -- Create Wallet
    INSERT INTO public.wallets (fan_id, balance_cache)
    VALUES (NEW.id, 0)
    ON CONFLICT (fan_id) DO NOTHING;

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Resilient logging to auth_trigger_errors
    BEGIN
        INSERT INTO public.auth_trigger_errors (user_id, error_message)
        VALUES (NEW.id, SQLERRM);
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;
    RAISE WARNING 'handle_new_user error for user %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;

-- Ensure trigger is active on auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
