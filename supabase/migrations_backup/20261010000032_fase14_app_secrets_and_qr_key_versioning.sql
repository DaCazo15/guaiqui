-- Migration: 20261010000032_fase14_app_secrets_and_qr_key_versioning.sql
-- Description: Secrets management, key versioning for HMAC QR codes with smooth transition window fallback, and Vault isolation.

-- 1. Ensure app_secrets table security
CREATE TABLE IF NOT EXISTS public.app_secrets (
    key_name TEXT PRIMARY KEY,
    secret_value TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.app_secrets ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.app_secrets FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.app_secrets TO service_role, postgres;

-- Insert active & legacy HMAC keys for transition window
INSERT INTO public.app_secrets (key_name, secret_value)
VALUES 
    ('hmac_active_key_id', 'v2'),
    ('hmac_secret_v1', 'guaiqui_hmac_prod_sec_v1_2026_legacy'),
    ('hmac_secret_v2', 'guaiqui_hmac_prod_sec_v2_2026_active')
ON CONFLICT (key_name) DO UPDATE 
SET secret_value = EXCLUDED.secret_value, updated_at = now();

-- Add qr_key_id column to redemptions if not present
ALTER TABLE public.redemptions ADD COLUMN IF NOT EXISTS qr_key_id TEXT DEFAULT 'v2';

-- 2. Update generate_redemption_code to use active key_id
CREATE OR REPLACE FUNCTION public.generate_redemption_code(p_redemption_id UUID)
RETURNS TEXT AS $$
DECLARE
    v_active_key_id TEXT;
    v_secret TEXT;
    v_raw BYTEA;
    v_alphabet TEXT := '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
    v_val BIGINT := 0;
    v_code TEXT := '';
    v_i INT;
    v_sum INT := 0;
    v_check CHAR;
BEGIN
    IF p_redemption_id IS NULL THEN
        RAISE EXCEPTION 'Redemption ID required.';
    END IF;

    SELECT secret_value INTO v_active_key_id FROM public.app_secrets WHERE key_name = 'hmac_active_key_id';
    IF v_active_key_id IS NULL THEN v_active_key_id := 'v2'; END IF;

    SELECT secret_value INTO v_secret FROM public.app_secrets WHERE key_name = 'hmac_secret_' || v_active_key_id;
    IF v_secret IS NULL OR v_secret = '' THEN
        -- Fallback to default
        SELECT secret_value INTO v_secret FROM public.app_secrets WHERE key_name = 'hmac_secret_v2';
    END IF;

    IF v_secret IS NULL THEN
        RAISE EXCEPTION 'HMAC secret key not configured in app_secrets.';
    END IF;

    -- Update redemptions row with key_id used
    UPDATE public.redemptions SET qr_key_id = v_active_key_id WHERE id = p_redemption_id;

    -- HMAC-SHA256
    v_raw := extensions.hmac(p_redemption_id::text, v_secret, 'sha256');

    FOR v_i IN 1..7 LOOP
        v_val := (v_val * 256) + get_byte(v_raw, v_i - 1);
    END LOOP;

    FOR v_i IN 1..11 LOOP
        v_code := substr(v_alphabet, (v_val % 32)::int + 1, 1) || v_code;
        v_val := v_val / 32;
    END LOOP;

    FOR v_i IN 1..11 LOOP
        v_sum := v_sum + (position(substr(v_code, v_i, 1) in v_alphabet) - 1) * v_i;
    END LOOP;
    v_check := substr(v_alphabet, (v_sum % 32) + 1, 1);

    RETURN v_code || v_check;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.generate_redemption_code(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.generate_redemption_code(UUID) TO authenticated, service_role;

-- 3. Helper helper_generate_code_with_key to allow dual key verification
CREATE OR REPLACE FUNCTION public.helper_generate_code_with_key(p_redemption_id UUID, p_key_id TEXT)
RETURNS TEXT AS $$
DECLARE
    v_secret TEXT;
    v_raw BYTEA;
    v_alphabet TEXT := '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
    v_val BIGINT := 0;
    v_code TEXT := '';
    v_i INT;
    v_sum INT := 0;
    v_check CHAR;
BEGIN
    SELECT secret_value INTO v_secret FROM public.app_secrets WHERE key_name = 'hmac_secret_' || p_key_id;
    IF v_secret IS NULL THEN RETURN NULL; END IF;

    v_raw := extensions.hmac(p_redemption_id::text, v_secret, 'sha256');

    FOR v_i IN 1..7 LOOP
        v_val := (v_val * 256) + get_byte(v_raw, v_i - 1);
    END LOOP;

    FOR v_i IN 1..11 LOOP
        v_code := substr(v_alphabet, (v_val % 32)::int + 1, 1) || v_code;
        v_val := v_val / 32;
    END LOOP;

    FOR v_i IN 1..11 LOOP
        v_sum := v_sum + (position(substr(v_code, v_i, 1) in v_alphabet) - 1) * v_i;
    END LOOP;
    v_check := substr(v_alphabet, (v_sum % 32) + 1, 1);

    RETURN v_code || v_check;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.helper_generate_code_with_key(UUID, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.helper_generate_code_with_key(UUID, TEXT) TO authenticated, service_role;
