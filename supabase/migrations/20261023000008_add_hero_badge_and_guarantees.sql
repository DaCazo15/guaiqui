-- ==============================================================================
-- Migration: Add hero badge and customizable guarantees to landing_settings
-- Enables editing top badge and guarantee labels directly from the admin panel
-- ==============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'landing_settings' 
          AND column_name = 'hero_badge_text'
    ) THEN
        ALTER TABLE public.landing_settings ADD COLUMN hero_badge_text VARCHAR(120) DEFAULT 'Fan Zone Oficial • Temporada 2026';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'landing_settings' 
          AND column_name = 'hero_guarantee_1'
    ) THEN
        ALTER TABLE public.landing_settings ADD COLUMN hero_guarantee_1 VARCHAR(80) DEFAULT '100% Gratuito';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'landing_settings' 
          AND column_name = 'hero_guarantee_2'
    ) THEN
        ALTER TABLE public.landing_settings ADD COLUMN hero_guarantee_2 VARCHAR(80) DEFAULT 'Sin tarjetas ni pagos';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'landing_settings' 
          AND column_name = 'hero_guarantee_3'
    ) THEN
        ALTER TABLE public.landing_settings ADD COLUMN hero_guarantee_3 VARCHAR(80) DEFAULT 'Premios y Perlitas Reales';
    END IF;
END $$;

-- Set hero_carousel_enabled = true and default values
UPDATE public.landing_settings
SET hero_carousel_enabled = true,
    hero_badge_text = COALESCE(hero_badge_text, 'Fan Zone Oficial • Temporada 2026'),
    hero_guarantee_1 = COALESCE(hero_guarantee_1, '100% Gratuito'),
    hero_guarantee_2 = COALESCE(hero_guarantee_2, 'Sin tarjetas ni pagos'),
    hero_guarantee_3 = COALESCE(hero_guarantee_3, 'Premios y Perlitas Reales')
WHERE id = 1;
