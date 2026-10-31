-- ============================================================================
-- Migration: 20261028000015_fase6_team_landing_subdomains_and_cms.sql
-- Description: Fase 6 — Landing pública por equipo y resolución por subdominio.
--              1. Agrega columnas de perfil/landing y subdominio a public.teams.
--              2. Actualiza la vista de proyección pública public.teams_public.
--              3. Configura datos oficiales para Guaiqueríes de Margarita.
--              4. Implementa función RPC atómica public.get_team_landing_data(p_identifier)
--                 optimizada para anon y authenticated con cero waterfalls.
--              5. Implementa RPC public.admin_update_team_landing_profile() con RLS.
-- ============================================================================

-- 1. Agregar columnas a public.teams
ALTER TABLE public.teams
    ADD COLUMN IF NOT EXISTS subdomain TEXT,
    ADD COLUMN IF NOT EXISTS arena_name TEXT,
    ADD COLUMN IF NOT EXISTS city TEXT,
    ADD COLUMN IF NOT EXISTS bio TEXT,
    ADD COLUMN IF NOT EXISTS founded_year INT,
    ADD COLUMN IF NOT EXISTS championships_summary TEXT,
    ADD COLUMN IF NOT EXISTS cover_url TEXT,
    ADD COLUMN IF NOT EXISTS social_links JSONB NOT NULL DEFAULT '{}'::jsonb,
    ADD COLUMN IF NOT EXISTS landing_config JSONB NOT NULL DEFAULT '{}'::jsonb;

-- Asegurar restricción de formato y unicidad para subdominio
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'teams_subdomain_format_check'
    ) THEN
        ALTER TABLE public.teams
            ADD CONSTRAINT teams_subdomain_format_check
            CHECK (subdomain IS NULL OR (subdomain ~ '^[a-z0-9-]+$' AND length(subdomain) >= 2 AND length(subdomain) <= 50));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'teams_subdomain_unique'
    ) THEN
        ALTER TABLE public.teams
            ADD CONSTRAINT teams_subdomain_unique UNIQUE (subdomain);
    END IF;
END$$;

CREATE INDEX IF NOT EXISTS teams_subdomain_idx ON public.teams (subdomain);

-- Backfill subdominio desde slug si es nulo
UPDATE public.teams
SET subdomain = slug
WHERE subdomain IS NULL;

-- 2. Trigger para sincronizar subdominio por defecto si no se especifica
CREATE OR REPLACE FUNCTION public.trg_teams_default_subdomain()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.subdomain IS NULL OR trim(NEW.subdomain) = '' THEN
        NEW.subdomain := NEW.slug;
    ELSE
        NEW.subdomain := lower(trim(NEW.subdomain));
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_teams_default_subdomain_ins ON public.teams;
CREATE TRIGGER trg_teams_default_subdomain_ins
    BEFORE INSERT ON public.teams
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_teams_default_subdomain();

-- 3. Actualizar datos oficiales de Guaiqueríes de Margarita (id génesis)
UPDATE public.teams
SET
    subdomain = 'guaiqueries',
    arena_name = 'Gimnasio Ciudad de La Asunción',
    city = 'La Asunción, Nueva Esparta',
    bio = 'Orgullo del baloncesto insular venezolano. La Tribu de Margarita representa la pasión, historia y garra del estado Nueva Esparta.',
    founded_year = 1977,
    championships_summary = '8 Campeonatos Nacionales (1977, 1978, 1979, 1980, 1981, 1982, 1997, 2007)',
    cover_url = 'https://images.unsplash.com/photo-1546519638-68e109498ffc?auto=format&fit=crop&w=1920&q=80',
    social_links = '{
        "instagram": "https://instagram.com/guaiqueries_oficial",
        "twitter": "https://twitter.com/guaiqueries_bbc",
        "website": "https://guaiqueries.com"
    }'::jsonb,
    landing_config = '{
        "hero_tagline": "El Orgullo del Baloncesto Insular",
        "hero_cta_text": "Únete a La Tribu",
        "show_roster": true,
        "show_trivias": true,
        "show_store": true,
        "show_history": true,
        "show_faqs": true
    }'::jsonb
WHERE id = 'a0000000-0000-0000-0000-000000000001'::uuid;

-- 4. Recrear public.teams_public proyectando los nuevos campos de landing
CREATE OR REPLACE VIEW public.teams_public
WITH (security_invoker = true)
AS
SELECT
    id,
    name,
    slug,
    subdomain,
    short_name,
    logo_url,
    cover_url,
    primary_color,
    secondary_color,
    sport,
    arena_name,
    city,
    bio,
    founded_year,
    championships_summary,
    social_links,
    landing_config,
    status,
    joined_at
FROM public.teams
WHERE status = 'active';

COMMENT ON VIEW public.teams_public IS 'Vista segura de proyección pública de equipos activos con campos de perfil y landing.';

REVOKE ALL ON TABLE public.teams_public FROM PUBLIC;
GRANT SELECT ON TABLE public.teams_public TO anon, authenticated, service_role;

-- 5. RPC public.get_team_landing_data: carga atómica del landing para un subdominio o slug
CREATE OR REPLACE FUNCTION public.get_team_landing_data(
    p_identifier TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_clean_id TEXT;
    v_team RECORD;
    v_announcement JSONB;
    v_hero_slides JSONB;
    v_roster JSONB;
    v_trivias JSONB;
    v_products JSONB;
    v_milestones JSONB;
    v_faqs JSONB;
BEGIN
    v_clean_id := lower(trim(COALESCE(p_identifier, '')));
    IF v_clean_id = '' THEN
        RETURN jsonb_build_object('found', false, 'error', 'Identificador de equipo requerido.');
    END IF;

    -- Localizar el equipo activo por slug o subdominio
    SELECT
        id,
        name,
        slug,
        subdomain,
        short_name,
        logo_url,
        cover_url,
        primary_color,
        secondary_color,
        sport,
        arena_name,
        city,
        bio,
        founded_year,
        championships_summary,
        social_links,
        landing_config,
        status,
        joined_at
    INTO v_team
    FROM public.teams
    WHERE status = 'active'
      AND (lower(slug) = v_clean_id OR lower(COALESCE(subdomain, '')) = v_clean_id)
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('found', false, 'error', 'Equipo no encontrado o inactivo.');
    END IF;

    -- Anuncio público más reciente
    SELECT to_jsonb(a)
    INTO v_announcement
    FROM (
        SELECT id, message, starts_at, expires_at, created_at
        FROM public.site_announcements
        WHERE team_id = v_team.id
          AND is_published = true
          AND (starts_at IS NULL OR starts_at <= now())
          AND (expires_at IS NULL OR expires_at > now())
        ORDER BY created_at DESC
        LIMIT 1
    ) a;

    -- Hero carousel slides
    SELECT COALESCE(jsonb_agg(to_jsonb(s)), '[]'::jsonb)
    INTO v_hero_slides
    FROM (
        SELECT id, title, subtitle, image_url, cta_text, cta_link, sort_order
        FROM public.hero_carousel_slides
        WHERE team_id = v_team.id
          AND is_active = true
        ORDER BY sort_order ASC, created_at ASC
        LIMIT 5
    ) s;

    -- Plantilla / Roster de jugadores activos
    SELECT COALESCE(jsonb_agg(to_jsonb(p)), '[]'::jsonb)
    INTO v_roster
    FROM (
        SELECT id, first_name, last_name, display_name, jersey_number, position, photo_url, height_cm, birth_date, is_captain
        FROM public.players
        WHERE team_id = v_team.id
          AND is_active = true
        ORDER BY jersey_number ASC NULLS LAST, last_name ASC
        LIMIT 12
    ) p;

    -- Trivias publicadas activas
    SELECT COALESCE(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
    INTO v_trivias
    FROM (
        SELECT id, title, description, category, reward_pearls, time_limit_seconds, available_from, available_until
        FROM public.trivias
        WHERE team_id = v_team.id
          AND status = 'published'
          AND (available_from IS NULL OR available_from <= now())
          AND (available_until IS NULL OR available_until > now())
        ORDER BY created_at DESC
        LIMIT 4
    ) t;

    -- Productos activos de la tienda
    SELECT COALESCE(jsonb_agg(to_jsonb(pr)), '[]'::jsonb)
    INTO v_products
    FROM (
        SELECT id, name, description, category, price_pearls, image_url, stock
        FROM public.products
        WHERE team_id = v_team.id
          AND status = 'active'
          AND stock > 0
        ORDER BY created_at DESC
        LIMIT 4
    ) pr;

    -- Hitos históricos
    SELECT COALESCE(jsonb_agg(to_jsonb(m)), '[]'::jsonb)
    INTO v_milestones
    FROM (
        SELECT id, year, title, description, image_url
        FROM public.history_milestones
        WHERE team_id = v_team.id
        ORDER BY year ASC
        LIMIT 10
    ) m;

    -- Preguntas frecuentes (FAQs)
    SELECT COALESCE(jsonb_agg(to_jsonb(f)), '[]'::jsonb)
    INTO v_faqs
    FROM (
        SELECT id, question, answer, category, sort_order
        FROM public.faqs
        WHERE team_id = v_team.id
          AND is_published = true
        ORDER BY sort_order ASC, created_at ASC
        LIMIT 8
    ) f;

    -- Ensamblar respuesta atómica
    RETURN jsonb_build_object(
        'found', true,
        'team', jsonb_build_object(
            'id', v_team.id,
            'name', v_team.name,
            'slug', v_team.slug,
            'subdomain', v_team.subdomain,
            'short_name', v_team.short_name,
            'logo_url', v_team.logo_url,
            'cover_url', v_team.cover_url,
            'primary_color', v_team.primary_color,
            'secondary_color', v_team.secondary_color,
            'sport', v_team.sport,
            'arena_name', v_team.arena_name,
            'city', v_team.city,
            'bio', v_team.bio,
            'founded_year', v_team.founded_year,
            'championships_summary', v_team.championships_summary,
            'social_links', v_team.social_links,
            'landing_config', v_team.landing_config,
            'joined_at', v_team.joined_at
        ),
        'announcement', v_announcement,
        'hero_slides', v_hero_slides,
        'roster_preview', v_roster,
        'trivias_preview', v_trivias,
        'products_preview', v_products,
        'milestones', v_milestones,
        'faqs', v_faqs
    );
END;
$$;

-- Permisos seguros para get_team_landing_data
REVOKE ALL ON FUNCTION public.get_team_landing_data(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_team_landing_data(TEXT) TO anon, authenticated, service_role;

-- 6. RPC para que el staff o admin del equipo actualice la información del landing
CREATE OR REPLACE FUNCTION public.admin_update_team_landing_profile(
    p_team_id UUID,
    p_arena_name TEXT DEFAULT NULL,
    p_city TEXT DEFAULT NULL,
    p_bio TEXT DEFAULT NULL,
    p_founded_year INT DEFAULT NULL,
    p_championships_summary TEXT DEFAULT NULL,
    p_cover_url TEXT DEFAULT NULL,
    p_social_links JSONB DEFAULT NULL,
    p_landing_config JSONB DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_is_platform_admin BOOLEAN;
    v_is_team_staff BOOLEAN;
BEGIN
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
    END IF;

    v_is_platform_admin := public.is_admin_check();
    v_is_team_staff := public.is_team_staff(p_team_id);

    IF NOT (v_is_platform_admin OR v_is_team_staff) THEN
        RAISE EXCEPTION 'No autorizado para actualizar la información de este equipo' USING ERRCODE = '42501';
    END IF;

    UPDATE public.teams
    SET
        arena_name = COALESCE(p_arena_name, arena_name),
        city = COALESCE(p_city, city),
        bio = COALESCE(p_bio, bio),
        founded_year = COALESCE(p_founded_year, founded_year),
        championships_summary = COALESCE(p_championships_summary, championships_summary),
        cover_url = COALESCE(p_cover_url, cover_url),
        social_links = COALESCE(p_social_links, social_links),
        landing_config = COALESCE(p_landing_config, landing_config),
        updated_at = now()
    WHERE id = p_team_id;

    RETURN jsonb_build_object('success', true, 'team_id', p_team_id);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_update_team_landing_profile(UUID, TEXT, TEXT, TEXT, INT, TEXT, TEXT, JSONB, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_update_team_landing_profile(UUID, TEXT, TEXT, TEXT, INT, TEXT, TEXT, JSONB, JSONB) TO authenticated, service_role;
