-- Migration: 20261007000005_auth_onboarding_and_anonymization.sql
-- Description: Auth onboarding trigger, consent fields, active/verified enforcement, account anonymization, and avatars storage policies.

-- 1. Add 'deleted' to user_status enum if not exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_enum e ON t.oid = e.enumtypid WHERE t.typname = 'user_status' AND e.enumlabel = 'deleted') THEN
        ALTER TYPE user_status ADD VALUE 'deleted';
    END IF;
END $$;

-- 2. Add consent & deletion columns to profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS terms_accepted_at TIMESTAMPTZ;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS terms_version TEXT DEFAULT '1.0';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS privacy_accepted_at TIMESTAMPTZ;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS privacy_version TEXT DEFAULT '1.0';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS pearls_rules_accepted_at TIMESTAMPTZ;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS pearls_rules_version TEXT DEFAULT '1.0';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- 3. Adjust Foreign Keys to RESTRICT on auth.users / profiles delete (financial integrity)
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_id_fkey;
ALTER TABLE profiles ADD CONSTRAINT profiles_id_fkey 
    FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE RESTRICT;

ALTER TABLE ledger_entries DROP CONSTRAINT IF EXISTS ledger_entries_fan_id_fkey;
ALTER TABLE ledger_entries ADD CONSTRAINT ledger_entries_fan_id_fkey 
    FOREIGN KEY (fan_id) REFERENCES profiles(id) ON DELETE RESTRICT;

ALTER TABLE redemptions DROP CONSTRAINT IF EXISTS redemptions_fan_id_fkey;
ALTER TABLE redemptions ADD CONSTRAINT redemptions_fan_id_fkey 
    FOREIGN KEY (fan_id) REFERENCES profiles(id) ON DELETE RESTRICT;

ALTER TABLE audit_log DROP CONSTRAINT IF EXISTS audit_log_actor_id_fkey;
ALTER TABLE audit_log ADD CONSTRAINT audit_log_actor_id_fkey 
    FOREIGN KEY (actor_id) REFERENCES auth.users(id) ON DELETE SET NULL;

-- 4. Trigger on auth.users registration (minimal, fail-safe, no email leakage)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    v_is_staff BOOLEAN := false;
    v_random_suffix TEXT;
BEGIN
    -- Check if user is staff member
    IF NEW.id IS NOT NULL THEN
        SELECT EXISTS (SELECT 1 FROM public.staff_members WHERE user_id = NEW.id) INTO v_is_staff;
    END IF;

    -- Do not create fan profile if user is staff
    IF v_is_staff THEN
        RETURN NEW;
    END IF;

    -- Generate random display_name suffix ("Fanático #123456") - strictly without using email
    v_random_suffix := floor(random() * 900000 + 100000)::text;

    -- Create Profile
    INSERT INTO public.profiles (id, display_name, status)
    VALUES (NEW.id, 'Fanático #' || v_random_suffix, 'active')
    ON CONFLICT (id) DO NOTHING;

    -- Create Wallet
    INSERT INTO public.wallets (fan_id, balance_cache)
    VALUES (NEW.id, 0)
    ON CONFLICT (fan_id) DO NOTHING;

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Fail-safe: log warning without breaking auth user creation
    RAISE WARNING 'handle_new_user warning for user %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 5. Helper SQL assert_active_verified_fan()
CREATE OR REPLACE FUNCTION public.assert_active_verified_fan()
RETURNS UUID AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_email_confirmed TIMESTAMPTZ;
    v_profile_status user_status;
    v_deleted_at TIMESTAMPTZ;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    -- Check email confirmation in auth.users
    SELECT email_confirmed_at INTO v_email_confirmed
    FROM auth.users
    WHERE id = v_uid;

    IF v_email_confirmed IS NULL THEN
        RAISE EXCEPTION 'El correo electrónico debe estar verificado para realizar esta acción.';
    END IF;

    -- Check profile status
    SELECT status, deleted_at INTO v_profile_status, v_deleted_at
    FROM public.profiles
    WHERE id = v_uid;

    IF v_profile_status IS NULL OR v_profile_status != 'active' OR v_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION 'Tu cuenta está inactiva, suspendida o ha sido eliminada.';
    END IF;

    RETURN v_uid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 6. RPC Function delete_my_account() - Idempotent, self-only via auth.uid()
CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS JSONB AS $$
DECLARE
    v_fan_id UUID := auth.uid();
    v_current_status user_status;
    v_pending_redemptions INT;
    v_held_entries INT;
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT status INTO v_current_status FROM public.profiles WHERE id = v_fan_id;

    -- Idempotent check: if already deleted, return success
    IF v_current_status = 'deleted' THEN
        RETURN jsonb_build_object(
            'success', true,
            'message', 'La cuenta ya ha sido eliminada previamente.',
            'already_deleted', true
        );
    END IF;

    -- Block if pending redemptions exist
    SELECT COUNT(*) INTO v_pending_redemptions
    FROM public.redemptions
    WHERE fan_id = v_fan_id AND status IN ('pending', 'approved', 'scheduled');

    IF v_pending_redemptions > 0 THEN
        RAISE EXCEPTION 'No puedes eliminar tu cuenta mientras tengas % canje(s) en proceso o pendiente(s) de entrega. Por favor completa o cancela tus canjes primero.', v_pending_redemptions;
    END IF;

    -- Block if held pearls exist
    SELECT COUNT(*) INTO v_held_entries
    FROM public.ledger_entries
    WHERE fan_id = v_fan_id AND status = 'held';

    IF v_held_entries > 0 THEN
        RAISE EXCEPTION 'No puedes eliminar tu cuenta mientras tengas perlitas retenidas bajo revisión de soporte.';
    END IF;

    -- Anonymize profile
    UPDATE public.profiles
    SET display_name = 'Fanático Anónimo',
        avatar_url = NULL,
        municipality = NULL,
        birth_date = NULL,
        gender = NULL,
        favorite_player_id = NULL,
        shirt_size = NULL,
        referral_source = NULL,
        notification_prefs = '{}'::jsonb,
        status = 'deleted',
        deleted_at = NOW()
    WHERE id = v_fan_id;

    -- Audit log
    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        v_fan_id, 'delete_my_account', 'profiles', v_fan_id::text,
        jsonb_build_object('status', COALESCE(v_current_status::text, 'active')),
        jsonb_build_object('status', 'deleted', 'anonymized', true, 'deleted_at', NOW())
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Cuenta anonimizada y marcada para eliminación.',
        'already_deleted', false
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- Revoke execute from public/anon, grant to authenticated only
REVOKE EXECUTE ON FUNCTION public.delete_my_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;

-- 7. Setup Storage Bucket 'avatars' with size limit & MIME types
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'avatars',
    'avatars',
    true,
    2097152, -- 2 MB
    ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 2097152,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp'];

-- Storage RLS Policies for 'avatars'
DROP POLICY IF EXISTS "Avatars Public Read" ON storage.objects;
CREATE POLICY "Avatars Public Read" ON storage.objects
    FOR SELECT USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Avatars User Insert" ON storage.objects;
CREATE POLICY "Avatars User Insert" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'avatars' AND
        auth.role() = 'authenticated' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

DROP POLICY IF EXISTS "Avatars User Update" ON storage.objects;
CREATE POLICY "Avatars User Update" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'avatars' AND
        auth.role() = 'authenticated' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

DROP POLICY IF EXISTS "Avatars User Delete" ON storage.objects;
CREATE POLICY "Avatars User Delete" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'avatars' AND
        auth.role() = 'authenticated' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );
