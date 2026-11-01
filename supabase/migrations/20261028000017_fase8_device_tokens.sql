-- ============================================================================
-- Migration: 20261028000017_fase8_device_tokens.sql
-- Description: Fase 8: Registro de tokens de dispositivos para notificaciones push (FCM)
--              en aplicaciones móviles (Capacitor Android/iOS) y web.
--              - Tabla device_tokens con token único y validación de plataforma.
--              - RLS estricto: cada usuario solo ve y gestiona sus tokens.
--              - RPC register_device_token con SECURITY DEFINER.
--              - Permisos mínimos: REVOKE a PUBLIC y anon; GRANT a authenticated y service_role.
-- ============================================================================

-- 1. Tabla device_tokens
CREATE TABLE IF NOT EXISTS public.device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fan_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    token TEXT NOT NULL UNIQUE,
    platform TEXT NOT NULL CHECK (platform IN ('android', 'ios', 'web')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Índices de alto rendimiento
CREATE INDEX IF NOT EXISTS device_tokens_fan_id_idx ON public.device_tokens (fan_id);
CREATE UNIQUE INDEX IF NOT EXISTS device_tokens_token_idx ON public.device_tokens (token);

-- 2. Habilitar RLS
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "device_tokens_fan_all" ON public.device_tokens;
CREATE POLICY "device_tokens_fan_all" ON public.device_tokens
    FOR ALL
    TO authenticated
    USING (auth.uid() = fan_id)
    WITH CHECK (auth.uid() = fan_id);

-- 3. Permisos de tabla
REVOKE ALL ON TABLE public.device_tokens FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.device_tokens TO authenticated, service_role;

-- 4. RPC: register_device_token
CREATE OR REPLACE FUNCTION public.register_device_token(
    p_token TEXT,
    p_platform TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid UUID := auth.uid();
    v_clean_token TEXT := trim(COALESCE(p_token, ''));
    v_clean_platform TEXT := lower(trim(COALESCE(p_platform, '')));
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'No autenticado' USING ERRCODE = '42501';
    END IF;

    IF v_clean_token = '' THEN
        RAISE EXCEPTION 'Token no puede estar vacío' USING ERRCODE = '22023';
    END IF;

    IF v_clean_platform NOT IN ('android', 'ios', 'web') THEN
        RAISE EXCEPTION 'Plataforma no válida' USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.device_tokens (fan_id, token, platform, updated_at)
    VALUES (v_uid, v_clean_token, v_clean_platform, now())
    ON CONFLICT (token) DO UPDATE SET
        fan_id = EXCLUDED.fan_id,
        platform = EXCLUDED.platform,
        updated_at = now();

    RETURN jsonb_build_object('success', true, 'token', v_clean_token);
END;
$function$;

-- 5. Permisos de la RPC
REVOKE ALL ON FUNCTION public.register_device_token(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.register_device_token(TEXT, TEXT) TO authenticated, service_role;
