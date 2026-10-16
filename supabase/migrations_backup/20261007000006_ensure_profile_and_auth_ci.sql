-- Migration: 20261007000006_ensure_profile_and_auth_ci.sql
-- Description: Trigger error logging table, resilient handle_new_user, and ensure_profile() fallback RPC.

-- 1. Error logging table for Auth Triggers
CREATE TABLE IF NOT EXISTS public.auth_trigger_errors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID,
    error_message TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Explicit RLS: Enable RLS and REVOKE ALL from anon and authenticated (fan / staff cannot read/write)
ALTER TABLE public.auth_trigger_errors ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.auth_trigger_errors FROM PUBLIC, anon, authenticated;

-- 2. Resilient handle_new_user logging errors to auth_trigger_errors
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    v_is_staff BOOLEAN := false;
    v_random_suffix TEXT;
BEGIN
    IF NEW.id IS NOT NULL THEN
        SELECT EXISTS (SELECT 1 FROM public.staff_members WHERE user_id = NEW.id) INTO v_is_staff;
    END IF;

    IF v_is_staff THEN
        RETURN NEW;
    END IF;

    v_random_suffix := floor(random() * 900000 + 100000)::text;

    INSERT INTO public.profiles (id, display_name, status)
    VALUES (NEW.id, 'Fanático #' || v_random_suffix, 'active')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.wallets (fan_id, balance_cache)
    VALUES (NEW.id, 0)
    ON CONFLICT (fan_id) DO NOTHING;

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Log error in auth_trigger_errors without blocking auth.users creation
    INSERT INTO public.auth_trigger_errors (user_id, error_message)
    VALUES (NEW.id, SQLERRM);
    RAISE WARNING 'handle_new_user warning for user %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 3. ensure_profile() Fallback RPC: Checks staff and deleted status
CREATE OR REPLACE FUNCTION public.ensure_profile()
RETURNS JSONB AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_is_staff BOOLEAN := false;
    v_current_status user_status;
    v_random_suffix TEXT;
    v_created BOOLEAN := false;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    -- 1. Check if user is a staff member
    SELECT EXISTS (SELECT 1 FROM public.staff_members WHERE user_id = v_uid AND active = true) INTO v_is_staff;
    IF v_is_staff THEN
        RETURN jsonb_build_object(
            'success', false,
            'reason', 'User is a staff member. Fan profile creation skipped.'
        );
    END IF;

    -- 2. Check if profile already exists and is deleted
    SELECT status INTO v_current_status FROM public.profiles WHERE id = v_uid;
    IF v_current_status = 'deleted' THEN
        RETURN jsonb_build_object(
            'success', false,
            'reason', 'Account is permanently deleted. Cannot recreate or reactivate profile.',
            'status', 'deleted'
        );
    END IF;

    v_random_suffix := floor(random() * 900000 + 100000)::text;

    -- Create profile if missing
    IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_uid) THEN
        INSERT INTO public.profiles (id, display_name, status)
        VALUES (v_uid, 'Fanático #' || v_random_suffix, 'active')
        ON CONFLICT (id) DO NOTHING;
        v_created := true;
    END IF;

    -- Create wallet if missing
    IF NOT EXISTS (SELECT 1 FROM public.wallets WHERE fan_id = v_uid) THEN
        INSERT INTO public.wallets (fan_id, balance_cache)
        VALUES (v_uid, 0)
        ON CONFLICT (fan_id) DO NOTHING;
        v_created := true;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'created', v_created,
        'user_id', v_uid
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE EXECUTE ON FUNCTION public.ensure_profile() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ensure_profile() TO authenticated;
