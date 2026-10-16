-- Migration: 20261009000019_landing_hero_and_settings.sql
-- Description: Landing Hero settings and theme configuration table

CREATE TABLE IF NOT EXISTS public.landing_settings (
    id INT PRIMARY KEY DEFAULT 1,
    hero_title TEXT NOT NULL DEFAULT 'La Tribu Insular Vive en la Fan Zone Oficial',
    hero_subtitle TEXT NOT NULL DEFAULT 'Gana perlitas exclusivas respondiendo trivias, participando en dinámicas de cancha y canjeándolas por recompensas reales de Guaiqueríes.',
    cta_primary_text TEXT NOT NULL DEFAULT 'Únete a la Tribu Gratis',
    cta_primary_url TEXT NOT NULL DEFAULT '/register',
    cta_secondary_text TEXT NOT NULL DEFAULT 'Explorar Premios',
    cta_secondary_url TEXT NOT NULL DEFAULT '#premios',
    dark_mode_enabled BOOLEAN NOT NULL DEFAULT true,
    theme_color TEXT NOT NULL DEFAULT '#059669',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT single_row CHECK (id = 1)
);

-- Enable RLS
ALTER TABLE public.landing_settings ENABLE ROW LEVEL SECURITY;

-- Public read access
DROP POLICY IF EXISTS "Landing Settings Public Read" ON public.landing_settings;
CREATE POLICY "Landing Settings Public Read" ON public.landing_settings FOR SELECT USING (true);

-- Admin management access
DROP POLICY IF EXISTS "Landing Settings Admin All" ON public.landing_settings;
CREATE POLICY "Landing Settings Admin All" ON public.landing_settings FOR ALL USING (public.is_admin_check());

-- Insert default row
INSERT INTO public.landing_settings (id, hero_title, hero_subtitle, cta_primary_text, cta_primary_url, cta_secondary_text, cta_secondary_url, dark_mode_enabled, theme_color)
VALUES (
    1,
    'La Tribu Insular Vive en la Fan Zone Oficial',
    'Gana perlitas exclusivas respondiendo trivias, participando en dinámicas de cancha y canjeándolas por recompensas reales de Guaiqueríes.',
    'Únete a la Tribu Gratis',
    '/register',
    'Explorar Premios',
    '#premios',
    true,
    '#059669'
)
ON CONFLICT (id) DO NOTHING;
