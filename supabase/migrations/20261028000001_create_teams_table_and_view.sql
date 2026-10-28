-- ============================================================================
-- Migration: 20261028000001_create_teams_table_and_view.sql
-- Description: Multi-tenant Step 1 (teams).
--              Creates public.teams table with CHECK constraint on slug,
--              team_status enum ('active', 'inactive'), timestamps, and billing metadata.
--              Creates public.teams_public secure view (security_invoker = true)
--              for anonymous and authenticated fan clients, projecting only active teams
--              without sensitive billing/subscription fields.
--              Seeds official genesis team #1: Guaiqueríes de Margarita.
-- ============================================================================

-- 1. Create team_status enum if not exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'team_status') THEN
        CREATE TYPE public.team_status AS ENUM ('active', 'inactive');
    END IF;
END$$;

-- 2. Create public.teams table
CREATE TABLE IF NOT EXISTS public.teams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    short_name TEXT,
    logo_url TEXT,
    primary_color TEXT DEFAULT '#005A36',
    secondary_color TEXT DEFAULT '#E31B23',
    status public.team_status NOT NULL DEFAULT 'active',
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    paid_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT teams_slug_format_check CHECK (slug ~ '^[a-z0-9-]+$' AND length(slug) >= 2 AND length(slug) <= 50),
    CONSTRAINT teams_name_not_empty_check CHECK (trim(name) <> '')
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS teams_slug_idx ON public.teams (slug);
CREATE INDEX IF NOT EXISTS teams_status_idx ON public.teams (status);

-- 3. Enable Row-Level Security
ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies for public.teams
CREATE POLICY "teams_admin_all" ON public.teams
    FOR ALL
    TO authenticated
    USING (public.is_admin_check())
    WITH CHECK (public.is_admin_check());

CREATE POLICY "teams_public_read_active" ON public.teams
    FOR SELECT
    TO anon, authenticated
    USING (status = 'active');

-- Table permissions
REVOKE ALL ON TABLE public.teams FROM PUBLIC;
GRANT SELECT ON TABLE public.teams TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.teams TO authenticated;
GRANT ALL ON TABLE public.teams TO service_role;

-- 5. Secure Public Projection View
CREATE OR REPLACE VIEW public.teams_public
WITH (security_invoker = true)
AS
SELECT
    id,
    name,
    slug,
    short_name,
    logo_url,
    primary_color,
    secondary_color,
    status,
    joined_at
FROM public.teams
WHERE status = 'active';

COMMENT ON VIEW public.teams_public IS 'Vista segura de proyección pública de equipos activos para clientes web y PWA (excluye campos comerciales como paid_until).';

REVOKE ALL ON TABLE public.teams_public FROM PUBLIC;
GRANT SELECT ON TABLE public.teams_public TO anon, authenticated, service_role;

-- 6. Seed official team #1: Guaiqueríes de Margarita
INSERT INTO public.teams (
    id,
    name,
    slug,
    short_name,
    logo_url,
    primary_color,
    secondary_color,
    status,
    joined_at
)
VALUES (
    'a0000000-0000-0000-0000-000000000001',
    'Guaiqueríes de Margarita',
    'guaiqueries',
    'La Tribu',
    'https://raw.githubusercontent.com/DaCazo15/guaiqui/main/apps/web/public/logo.png',
    '#005A36',
    '#E31B23',
    'active',
    '1977-03-01 00:00:00+00'
)
ON CONFLICT (slug) DO UPDATE SET
    name = EXCLUDED.name,
    short_name = EXCLUDED.short_name,
    logo_url = EXCLUDED.logo_url,
    primary_color = EXCLUDED.primary_color,
    secondary_color = EXCLUDED.secondary_color,
    status = EXCLUDED.status,
    updated_at = now();
