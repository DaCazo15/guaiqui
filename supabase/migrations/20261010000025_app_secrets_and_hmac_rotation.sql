-- Migration: 20261010000025_app_secrets_and_hmac_rotation.sql
-- Description: Rotates HMAC secret, creates private table public.app_secrets, and updates generate_redemption_code to read secret from public.app_secrets

-- 1. Create app_secrets table if not exists
CREATE TABLE IF NOT EXISTS public.app_secrets (
    key_name TEXT PRIMARY KEY,
    secret_value TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable RLS and revoke all access from public, anon, and authenticated
ALTER TABLE public.app_secrets ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.app_secrets FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.app_secrets TO service_role, postgres;

-- Insert / Update rotated HMAC secret key
INSERT INTO public.app_secrets (key_name, secret_value)
VALUES ('hmac_redemption_secret', 'guaiqui_hmac_prod_sec_v2_2026_rotated')
ON CONFLICT (key_name) DO UPDATE 
SET secret_value = EXCLUDED.secret_value, updated_at = now();

-- 2. Update generate_redemption_code function to read from public.app_secrets
CREATE OR REPLACE FUNCTION public.generate_redemption_code(p_redemption_id UUID)
RETURNS TEXT AS $$
DECLARE
    v_secret TEXT;
    v_raw BYTEA;
    v_alphabet TEXT := '0123456789ABCDEFGHJKMNPQRSTVWXYZ'; -- Crockford Base32
    v_val BIGINT := 0;
    v_code TEXT := '';
    v_i INT;
    v_sum INT := 0;
    v_check CHAR;
BEGIN
    IF p_redemption_id IS NULL THEN
        RAISE EXCEPTION 'Redemption ID required.';
    END IF;

    SELECT secret_value INTO v_secret
    FROM public.app_secrets
    WHERE key_name = 'hmac_redemption_secret';

    IF v_secret IS NULL OR v_secret = '' THEN
        RAISE EXCEPTION 'HMAC secret key not configured in app_secrets.';
    END IF;

    -- HMAC-SHA256 del UUID del canje usando strings
    v_raw := extensions.hmac(p_redemption_id::text, v_secret, 'sha256');

    -- Extraer los primeros 7 bytes (56 bits) para derivar 11 dígitos base32
    FOR v_i IN 1..7 LOOP
        v_val := (v_val * 256) + get_byte(v_raw, v_i - 1);
    END LOOP;

    FOR v_i IN 1..11 LOOP
        v_code := substr(v_alphabet, (v_val % 32)::int + 1, 1) || v_code;
        v_val := v_val / 32;
    END LOOP;

    -- Dígito verificador ponderado mod 32
    FOR v_i IN 1..11 LOOP
        v_sum := v_sum + (position(substr(v_code, v_i, 1) in v_alphabet) - 1) * v_i;
    END LOOP;
    v_check := substr(v_alphabet, (v_sum % 32) + 1, 1);

    RETURN v_code || v_check;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.generate_redemption_code(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.generate_redemption_code(UUID) TO authenticated, service_role;
