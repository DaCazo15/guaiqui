-- ==============================================================================
-- Migration: Add enhanced fields to hero_carousel_slides
-- Allows secondary CTA, badge tag styling, floating highlight card, and image layout
-- ==============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'hero_carousel_slides' 
          AND column_name = 'cta_secondary_text'
    ) THEN
        ALTER TABLE public.hero_carousel_slides ADD COLUMN cta_secondary_text VARCHAR(80) DEFAULT NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'hero_carousel_slides' 
          AND column_name = 'cta_secondary_url'
    ) THEN
        ALTER TABLE public.hero_carousel_slides ADD COLUMN cta_secondary_url VARCHAR(255) DEFAULT NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'hero_carousel_slides' 
          AND column_name = 'tag_variant'
    ) THEN
        ALTER TABLE public.hero_carousel_slides ADD COLUMN tag_variant VARCHAR(30) DEFAULT 'primary';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'hero_carousel_slides' 
          AND column_name = 'highlight_title'
    ) THEN
        ALTER TABLE public.hero_carousel_slides ADD COLUMN highlight_title VARCHAR(120) DEFAULT NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'hero_carousel_slides' 
          AND column_name = 'highlight_subtitle'
    ) THEN
        ALTER TABLE public.hero_carousel_slides ADD COLUMN highlight_subtitle VARCHAR(200) DEFAULT NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'hero_carousel_slides' 
          AND column_name = 'highlight_badge'
    ) THEN
        ALTER TABLE public.hero_carousel_slides ADD COLUMN highlight_badge VARCHAR(50) DEFAULT NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'hero_carousel_slides' 
          AND column_name = 'image_layout'
    ) THEN
        ALTER TABLE public.hero_carousel_slides ADD COLUMN image_layout VARCHAR(30) DEFAULT 'background';
    END IF;
END $$;
