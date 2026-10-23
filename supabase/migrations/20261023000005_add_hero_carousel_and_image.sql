-- ============================================================================
-- Migration: Add hero image, hero carousel toggle, and hero_carousel_slides table
-- Allows uploading a hero background image and managing up to 5 posts in the Hero carousel.
-- ============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'landing_settings' 
          AND column_name = 'hero_image_url'
    ) THEN
        ALTER TABLE public.landing_settings ADD COLUMN hero_image_url TEXT DEFAULT NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'landing_settings' 
          AND column_name = 'hero_carousel_enabled'
    ) THEN
        ALTER TABLE public.landing_settings ADD COLUMN hero_carousel_enabled BOOLEAN NOT NULL DEFAULT false;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'landing_settings' 
          AND column_name = 'hero_card_color'
    ) THEN
        ALTER TABLE public.landing_settings ADD COLUMN hero_card_color TEXT DEFAULT NULL;
    END IF;
END $$;

-- Create table for Hero Carousel posts (up to 5 posts)
CREATE TABLE IF NOT EXISTS public.hero_carousel_slides (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(200) NOT NULL,
    tag VARCHAR(80),
    subtitle TEXT,
    image_url TEXT,
    cta_text VARCHAR(80),
    cta_url VARCHAR(255),
    order_index INT NOT NULL DEFAULT 1 CHECK (order_index >= 1 AND order_index <= 5),
    is_published BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.hero_carousel_slides ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Hero Carousel Public Read" ON public.hero_carousel_slides;
DROP POLICY IF EXISTS "Hero Carousel Admin All" ON public.hero_carousel_slides;

-- Policies
CREATE POLICY "Hero Carousel Public Read" ON public.hero_carousel_slides
    FOR SELECT TO public
    USING (is_published = true);

CREATE POLICY "Hero Carousel Admin All" ON public.hero_carousel_slides
    FOR ALL TO authenticated
    USING (public.is_admin_check())
    WITH CHECK (public.is_admin_check());
