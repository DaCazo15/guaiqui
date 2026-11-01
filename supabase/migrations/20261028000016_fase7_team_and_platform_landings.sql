-- ============================================================================
-- Migration: 20261028000016_fase7_team_and_platform_landings.sql
-- Description: Fase 7: Landing por equipo y landing de plataforma multi-equipo.
--              1. Tabla team_landing_content con RLS para lectura pública de equipos activos
--                 y escritura restringida a personal del equipo o platform admin.
--              2. Trigger trg_enforce_tenant_team_id para aislamiento de inquilinos.
--              3. RPC pública get_team_landing(slug) que expone datos de equipo activo,
--                 resumen de trivias, ranking público sin datos privados, productos y seguidores.
--              4. RPC pública get_platform_landing() con equipos activos y totales públicos.
--              5. RPC autenticada update_team_landing_content con validación de roles.
--              6. Permisos mínimos con REVOKE a PUBLIC/anon salvo RPCs públicas autorizadas.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Tabla team_landing_content
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.team_landing_content (
    team_id UUID PRIMARY KEY REFERENCES public.teams(id) ON DELETE CASCADE,
    hero_title TEXT NOT NULL DEFAULT 'Fan Zone Oficial',
    hero_subtitle TEXT NOT NULL DEFAULT 'Gana perlitas exclusivas respondiendo trivias y canjeándolas por recompensas oficiales.',
    hero_image_url TEXT,
    sections JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE public.team_landing_content ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "team_landing_content_public_read_active" ON public.team_landing_content;
CREATE POLICY "team_landing_content_public_read_active" ON public.team_landing_content
    FOR SELECT
    TO anon, authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.teams t 
            WHERE t.id = team_landing_content.team_id 
              AND t.status = 'active'
        )
    );

DROP POLICY IF EXISTS "team_landing_content_staff_write" ON public.team_landing_content;
CREATE POLICY "team_landing_content_staff_write" ON public.team_landing_content
    FOR ALL
    TO authenticated
    USING (
        public.is_admin_check() OR public.is_team_staff((SELECT auth.uid()), team_id)
    )
    WITH CHECK (
        public.is_admin_check() OR public.is_team_staff((SELECT auth.uid()), team_id)
    );

-- Trigger para forzar aislamiento de inquilino
DROP TRIGGER IF EXISTS trg_enforce_tenant_team_landing_content ON public.team_landing_content;
CREATE TRIGGER trg_enforce_tenant_team_landing_content
    BEFORE INSERT OR UPDATE ON public.team_landing_content
    FOR EACH ROW EXECUTE FUNCTION public.trg_enforce_tenant_team_id();

-- Permisos de tabla
REVOKE ALL ON TABLE public.team_landing_content FROM PUBLIC, anon;
GRANT SELECT ON TABLE public.team_landing_content TO anon, authenticated, service_role;
GRANT INSERT, UPDATE, DELETE ON TABLE public.team_landing_content TO authenticated, service_role;

-- Población inicial para equipos existentes
INSERT INTO public.team_landing_content (team_id, hero_title, hero_subtitle, hero_image_url)
SELECT 
    t.id,
    COALESCE(ls.hero_title, 'La Tribu Insular Vive en la Fan Zone Oficial'),
    COALESCE(ls.hero_subtitle, 'Gana perlitas exclusivas respondiendo trivias y canjeándolas por recompensas reales de ' || t.name || '.'),
    ls.hero_image_url
FROM public.teams t
LEFT JOIN public.landing_settings ls ON ls.id = 1
ON CONFLICT (team_id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 2. RPC pública: get_team_landing(p_slug TEXT)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_team_landing(p_slug TEXT)
RETURNS JSONB
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_clean_slug TEXT := lower(trim(COALESCE(p_slug, '')));
    v_team RECORD;
    v_caller_id UUID := auth.uid();
    v_follower_count INT := 0;
    v_is_following BOOLEAN := false;
    v_content JSONB;
    v_trivias JSONB := '[]'::jsonb;
    v_top_ranking JSONB := '[]'::jsonb;
    v_featured_products JSONB := '[]'::jsonb;
BEGIN
    IF v_clean_slug = '' THEN
        RETURN jsonb_build_object('status', 'not_found', 'message', 'Slug no proporcionado');
    END IF;

    SELECT id, name, slug, short_name, logo_url, primary_color, secondary_color, status
    INTO v_team
    FROM public.teams
    WHERE slug = v_clean_slug;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('status', 'not_found', 'message', 'Equipo no encontrado');
    END IF;

    -- Si el equipo está inactivo, retornar estado inactivo sin datos privados ni operativos
    IF v_team.status = 'inactive' THEN
        RETURN jsonb_build_object(
            'status', 'inactive',
            'team', jsonb_build_object(
                'id', v_team.id,
                'name', v_team.name,
                'slug', v_team.slug,
                'status', 'inactive'
            )
        );
    END IF;

    -- Conteo de seguidores verificados / activos
    SELECT COUNT(*)::INT INTO v_follower_count
    FROM public.team_follows tf
    JOIN public.profiles p ON p.id = tf.user_id
    WHERE tf.team_id = v_team.id AND p.status = 'active';

    -- ¿El usuario actual lo sigue?
    IF v_caller_id IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1 FROM public.team_follows
            WHERE team_id = v_team.id AND user_id = v_caller_id
        ) INTO v_is_following;
    END IF;

    -- Contenido de la landing
    SELECT jsonb_build_object(
        'hero_title', c.hero_title,
        'hero_subtitle', c.hero_subtitle,
        'hero_image_url', c.hero_image_url,
        'sections', COALESCE(c.sections, '[]'::jsonb),
        'updated_at', c.updated_at
    )
    INTO v_content
    FROM public.team_landing_content c
    WHERE c.team_id = v_team.id;

    IF v_content IS NULL THEN
        v_content := jsonb_build_object(
            'hero_title', 'Fan Zone Oficial ' || v_team.name,
            'hero_subtitle', 'Gana perlitas respondiendo trivias y canjea premios oficiales de ' || v_team.name || '.',
            'hero_image_url', NULL,
            'sections', '[]'::jsonb,
            'updated_at', now()
        );
    END IF;

    -- Trivias activas (resumen público, sin preguntas ni respuestas correctas)
    SELECT COALESCE(jsonb_agg(sub.item), '[]'::jsonb)
    INTO v_trivias
    FROM (
        SELECT jsonb_build_object(
            'id', t.id,
            'title', t.title,
            'description', t.description,
            'category', t.category,
            'reward_pearls', t.reward_pearls,
            'starts_at', t.starts_at,
            'expires_at', t.expires_at
        ) AS item
        FROM public.trivias t
        WHERE t.team_id = v_team.id
          AND t.status = 'active'
          AND t.is_published = true
          AND (t.expires_at IS NULL OR t.expires_at > now())
        ORDER BY t.created_at DESC
        LIMIT 6
    ) sub;

    -- Ranking público del equipo (solo display_name, avatar_url y puntos, sin email/teléfono/datos privados)
    SELECT COALESCE(jsonb_agg(sub.item), '[]'::jsonb)
    INTO v_top_ranking
    FROM (
        SELECT jsonb_build_object(
            'rank', ROW_NUMBER() OVER (ORDER BY w.balance_cache DESC),
            'display_name', COALESCE(p.display_name, 'Fanático'),
            'avatar_url', p.avatar_url,
            'points', w.balance_cache
        ) AS item
        FROM public.wallets w
        JOIN public.profiles p ON p.id = w.fan_id
        WHERE w.team_id = v_team.id
          AND p.status = 'active'
          AND w.balance_cache > 0
        ORDER BY w.balance_cache DESC
        LIMIT 10
    ) sub;

    -- Productos destacados de la tienda del equipo
    SELECT COALESCE(jsonb_agg(sub.item), '[]'::jsonb)
    INTO v_featured_products
    FROM (
        SELECT jsonb_build_object(
            'id', pr.id,
            'name', pr.name,
            'description', pr.description,
            'cost_pearls', pr.cost_pearls,
            'image_url', pr.image_url,
            'category', pr.category,
            'stock', pr.stock
        ) AS item
        FROM public.products pr
        WHERE pr.team_id = v_team.id
          AND pr.is_active = true
          AND pr.stock > 0
        ORDER BY pr.created_at DESC
        LIMIT 6
    ) sub;

    RETURN jsonb_build_object(
        'status', 'active',
        'team', jsonb_build_object(
            'id', v_team.id,
            'name', v_team.name,
            'slug', v_team.slug,
            'short_name', v_team.short_name,
            'logo_url', v_team.logo_url,
            'primary_color', v_team.primary_color,
            'secondary_color', v_team.secondary_color,
            'status', v_team.status
        ),
        'follower_count', v_follower_count,
        'is_following', v_is_following,
        'content', v_content,
        'active_trivias', v_trivias,
        'top_ranking', v_top_ranking,
        'featured_products', v_featured_products
    );
END;
$function$;

-- ----------------------------------------------------------------------------
-- 3. RPC pública: get_platform_landing()
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_platform_landing()
RETURNS JSONB
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_teams JSONB := '[]'::jsonb;
    v_caller_id UUID := auth.uid();
    v_total_teams INT := 0;
    v_total_fans INT := 0;
    v_total_trivias_played INT := 0;
    v_total_rewards_claimed INT := 0;
BEGIN
    -- Equipos activos ordenados por popularidad
    SELECT COALESCE(jsonb_agg(sub.item), '[]'::jsonb)
    INTO v_teams
    FROM (
        SELECT jsonb_build_object(
            'id', t.id,
            'name', t.name,
            'slug', t.slug,
            'short_name', t.short_name,
            'logo_url', t.logo_url,
            'primary_color', t.primary_color,
            'secondary_color', t.secondary_color,
            'follower_count', COALESCE(fc.cnt, 0)::INT,
            'is_following', (v_caller_id IS NOT NULL AND EXISTS (
                SELECT 1 FROM public.team_follows tf
                WHERE tf.team_id = t.id AND tf.user_id = v_caller_id
            ))
        ) AS item
        FROM public.teams t
        LEFT JOIN (
            SELECT tf_sub.team_id, COUNT(*)::INT AS cnt
            FROM public.team_follows tf_sub
            JOIN public.profiles p_sub ON p_sub.id = tf_sub.user_id
            WHERE p_sub.status = 'active'
            GROUP BY tf_sub.team_id
        ) fc ON fc.team_id = t.id
        WHERE t.status = 'active'
        ORDER BY COALESCE(fc.cnt, 0) DESC, t.name ASC
    ) sub;

    -- Totales agregados de la plataforma
    SELECT COUNT(*)::INT INTO v_total_teams
    FROM public.teams
    WHERE status = 'active';

    SELECT COUNT(*)::INT INTO v_total_fans
    FROM public.profiles
    WHERE status = 'active';

    SELECT COUNT(*)::INT INTO v_total_trivias_played
    FROM public.trivia_attempts;

    SELECT COUNT(*)::INT INTO v_total_rewards_claimed
    FROM public.redemptions
    WHERE status IN ('delivered', 'approved');

    RETURN jsonb_build_object(
        'teams', v_teams,
        'totals', jsonb_build_object(
            'total_teams', v_total_teams,
            'total_fans', v_total_fans,
            'total_trivias_played', v_total_trivias_played,
            'total_rewards_claimed', v_total_rewards_claimed
        )
    );
END;
$function$;

-- ----------------------------------------------------------------------------
-- 4. RPC autenticada: update_team_landing_content
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_team_landing_content(
    p_team_id UUID,
    p_hero_title TEXT,
    p_hero_subtitle TEXT,
    p_hero_image_url TEXT DEFAULT NULL,
    p_sections JSONB DEFAULT '[]'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid UUID := auth.uid();
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'No autenticado' USING ERRCODE = '42501';
    END IF;

    IF NOT (public.is_admin_check() OR public.is_team_staff(v_uid, p_team_id)) THEN
        RAISE EXCEPTION 'No autorizado para editar la landing de este equipo' USING ERRCODE = '42501';
    END IF;

    INSERT INTO public.team_landing_content (team_id, hero_title, hero_subtitle, hero_image_url, sections, updated_at)
    VALUES (
        p_team_id,
        trim(COALESCE(p_hero_title, 'Fan Zone Oficial')),
        trim(COALESCE(p_hero_subtitle, '')),
        p_hero_image_url,
        COALESCE(p_sections, '[]'::jsonb),
        now()
    )
    ON CONFLICT (team_id) DO UPDATE SET
        hero_title = EXCLUDED.hero_title,
        hero_subtitle = EXCLUDED.hero_subtitle,
        hero_image_url = EXCLUDED.hero_image_url,
        sections = EXCLUDED.sections,
        updated_at = now();

    RETURN jsonb_build_object('success', true, 'team_id', p_team_id);
END;
$function$;

-- ----------------------------------------------------------------------------
-- 5. Permisos de Ejecución (Seguridad Mínima)
-- ----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.get_team_landing(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_team_landing(TEXT) TO anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public.get_platform_landing() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_platform_landing() TO anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public.update_team_landing_content(UUID, TEXT, TEXT, TEXT, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_team_landing_content(UUID, TEXT, TEXT, TEXT, JSONB) TO authenticated, service_role;
