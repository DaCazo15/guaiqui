-- ============================================================================
-- Migration: 20261028000008_create_team_follows.sql
-- Description: Paso 1 — Seguir Equipos:
--              1. Table public.team_follows (user_id, team_id, created_at)
--              2. RLS policies: fan manages own follows on active teams;
--                 staff does not read follower list directly; platform admin reads all.
--              3. RPC team_follower_count(p_team_id)
--              4. RPC follow_team(p_team_id) (idempotent, rate limited, creates wallet)
--              5. RPC unfollow_team(p_team_id) (idempotent, rate limited, preserves wallet)
--              6. RPC search_teams(p_query, p_limit, p_offset) (active only, public fields, capped)
--              7. Backfill: existing fans follow team #1 (Guaiqueríes)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Table public.team_follows
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.team_follows (
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT team_follows_pkey PRIMARY KEY (user_id, team_id)
);

CREATE INDEX IF NOT EXISTS idx_team_follows_user_id ON public.team_follows (user_id);
CREATE INDEX IF NOT EXISTS idx_team_follows_team_id ON public.team_follows (team_id);

-- ----------------------------------------------------------------------------
-- 2. Row Level Security for public.team_follows
-- ----------------------------------------------------------------------------
ALTER TABLE public.team_follows ENABLE ROW LEVEL SECURITY;

-- 2.1 Fan reads own follows
DROP POLICY IF EXISTS "fan_select_own_follows" ON public.team_follows;
CREATE POLICY "fan_select_own_follows" ON public.team_follows
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

-- 2.2 Fan inserts own follow ONLY on active teams
DROP POLICY IF EXISTS "fan_insert_own_follows" ON public.team_follows;
CREATE POLICY "fan_insert_own_follows" ON public.team_follows
    FOR INSERT TO authenticated
    WITH CHECK (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1 FROM public.teams t
            WHERE t.id = team_id AND t.status = 'active'
        )
    );

-- 2.3 Fan deletes own follow
DROP POLICY IF EXISTS "fan_delete_own_follows" ON public.team_follows;
CREATE POLICY "fan_delete_own_follows" ON public.team_follows
    FOR DELETE TO authenticated
    USING (auth.uid() = user_id);

-- 2.4 Platform admin full access
DROP POLICY IF EXISTS "platform_admin_team_follows" ON public.team_follows;
CREATE POLICY "platform_admin_team_follows" ON public.team_follows
    FOR ALL TO authenticated
    USING (public.is_platform_admin(auth.uid()))
    WITH CHECK (public.is_platform_admin(auth.uid()));

-- Permissions
REVOKE ALL ON TABLE public.team_follows FROM PUBLIC, anon;
GRANT SELECT, INSERT, DELETE ON TABLE public.team_follows TO authenticated;
GRANT ALL ON TABLE public.team_follows TO service_role;

-- ----------------------------------------------------------------------------
-- 3. Backfill: Existing fans follow team #1 (Guaiqueríes de Margarita)
-- ----------------------------------------------------------------------------
INSERT INTO public.team_follows (user_id, team_id, created_at)
SELECT p.id, 'a0000000-0000-0000-0000-000000000001'::uuid, NOW()
FROM public.profiles p
WHERE p.status != 'deleted'
ON CONFLICT (user_id, team_id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 4. RPC: team_follower_count(p_team_id)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.team_follower_count(p_team_id UUID)
RETURNS INTEGER
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
    SELECT COUNT(*)::INT
    FROM public.team_follows tf
    JOIN public.profiles p ON p.id = tf.user_id
    WHERE tf.team_id = p_team_id AND p.status = 'active';
$$;

-- ----------------------------------------------------------------------------
-- 5. RPC: follow_team(p_team_id)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.follow_team(p_team_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_fan_id UUID;
    v_team_status public.team_status;
BEGIN
    v_fan_id := public.assert_active_verified_fan();

    IF p_team_id IS NULL THEN
        RAISE EXCEPTION 'El identificador del equipo es obligatorio.';
    END IF;

    -- Rate limiting: máximo 30 operaciones por minuto
    PERFORM public.check_rate_limit(v_fan_id, 'follow_team', 30, 60);

    SELECT status INTO v_team_status
    FROM public.teams
    WHERE id = p_team_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Equipo no encontrado.';
    END IF;

    IF v_team_status != 'active' THEN
        RAISE EXCEPTION 'No es posible seguir a un equipo inactivo.' USING ERRCODE = '42501';
    END IF;

    -- Inserción idempotente de follow
    INSERT INTO public.team_follows (user_id, team_id, created_at)
    VALUES (v_fan_id, p_team_id, NOW())
    ON CONFLICT (user_id, team_id) DO NOTHING;

    -- Asegurar que el wallet del equipo exista para este fanático
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'wallets' AND column_name = 'team_id'
    ) THEN
        INSERT INTO public.wallets (fan_id, team_id, balance_cache, updated_at)
        VALUES (v_fan_id, p_team_id, 0, NOW())
        ON CONFLICT (fan_id, team_id) DO NOTHING;
    ELSE
        INSERT INTO public.wallets (fan_id, balance_cache, updated_at)
        VALUES (v_fan_id, 0, NOW())
        ON CONFLICT (fan_id) DO NOTHING;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'team_id', p_team_id,
        'following', true
    );
END;
$function$;

-- ----------------------------------------------------------------------------
-- 6. RPC: unfollow_team(p_team_id)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.unfollow_team(p_team_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_fan_id UUID;
BEGIN
    v_fan_id := public.assert_active_verified_fan();

    IF p_team_id IS NULL THEN
        RAISE EXCEPTION 'El identificador del equipo es obligatorio.';
    END IF;

    PERFORM public.check_rate_limit(v_fan_id, 'unfollow_team', 30, 60);

    DELETE FROM public.team_follows
    WHERE user_id = v_fan_id AND team_id = p_team_id;

    -- NOTA REGLA DE NEGOCIO: Dejar de seguir NO borra ni congela el saldo.
    -- El wallet y el ledger quedan intactos para canjes.

    RETURN jsonb_build_object(
        'success', true,
        'team_id', p_team_id,
        'following', false
    );
END;
$function$;

-- ----------------------------------------------------------------------------
-- 7. RPC: search_teams(p_query, p_limit, p_offset)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.search_teams(
    p_query TEXT DEFAULT NULL::TEXT,
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    id UUID,
    name TEXT,
    slug TEXT,
    short_name TEXT,
    logo_url TEXT,
    primary_color TEXT,
    secondary_color TEXT,
    follower_count INTEGER,
    is_following BOOLEAN
)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_limit INT := LEAST(GREATEST(COALESCE(p_limit, 20), 1), 50);
    v_offset INT := GREATEST(COALESCE(p_offset, 0), 0);
    v_clean_query TEXT := trim(COALESCE(p_query, ''));
BEGIN
    RETURN QUERY
    SELECT 
        t.id,
        t.name,
        t.slug,
        t.short_name,
        t.logo_url,
        t.primary_color,
        t.secondary_color,
        COALESCE(fc.cnt, 0)::INT AS follower_count,
        (v_caller_id IS NOT NULL AND EXISTS (
            SELECT 1 FROM public.team_follows tf
            WHERE tf.team_id = t.id AND tf.user_id = v_caller_id
        )) AS is_following
    FROM public.teams t
    LEFT JOIN (
        SELECT tf_sub.team_id, COUNT(*)::INT AS cnt
        FROM public.team_follows tf_sub
        JOIN public.profiles p_sub ON p_sub.id = tf_sub.user_id
        WHERE p_sub.status = 'active'
        GROUP BY tf_sub.team_id
    ) fc ON fc.team_id = t.id
    WHERE t.status = 'active'
      AND (
          v_clean_query = ''
          OR t.name ILIKE '%' || v_clean_query || '%'
          OR t.slug ILIKE '%' || v_clean_query || '%'
          OR COALESCE(t.short_name, '') ILIKE '%' || v_clean_query || '%'
      )
    ORDER BY is_following DESC, follower_count DESC, t.name ASC
    LIMIT v_limit OFFSET v_offset;
END;
$function$;

-- ----------------------------------------------------------------------------
-- 8. Permisos de Ejecución
-- ----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.team_follower_count(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.team_follower_count(UUID) TO anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public.follow_team(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.follow_team(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.unfollow_team(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.unfollow_team(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.search_teams(TEXT, INTEGER, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.search_teams(TEXT, INTEGER, INTEGER) TO anon, authenticated, service_role;
