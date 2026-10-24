-- ==============================================================================
-- Migration: Add customizable guarantees and options to hero_carousel_slides
-- Allows editing trust badges, visibility, and text alignment per slide
-- ==============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'hero_carousel_slides' 
          AND column_name = 'guarantee_1'
    ) THEN
        ALTER TABLE public.hero_carousel_slides ADD COLUMN guarantee_1 VARCHAR(80) DEFAULT '100% Gratuito';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'hero_carousel_slides' 
          AND column_name = 'guarantee_2'
    ) THEN
        ALTER TABLE public.hero_carousel_slides ADD COLUMN guarantee_2 VARCHAR(80) DEFAULT 'Sin tarjetas ni pagos';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'hero_carousel_slides' 
          AND column_name = 'guarantee_3'
    ) THEN
        ALTER TABLE public.hero_carousel_slides ADD COLUMN guarantee_3 VARCHAR(80) DEFAULT 'Recompensas Reales';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'hero_carousel_slides' 
          AND column_name = 'show_guarantees'
    ) THEN
        ALTER TABLE public.hero_carousel_slides ADD COLUMN show_guarantees BOOLEAN NOT NULL DEFAULT true;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'hero_carousel_slides' 
          AND column_name = 'text_align'
    ) THEN
        ALTER TABLE public.hero_carousel_slides ADD COLUMN text_align VARCHAR(20) NOT NULL DEFAULT 'left';
    END IF;
END $$;

-- Populate default values for existing slides
UPDATE public.hero_carousel_slides
SET guarantee_1 = COALESCE(guarantee_1, '100% Gratuito'),
    guarantee_2 = COALESCE(guarantee_2, 'Sin tarjetas ni pagos'),
    guarantee_3 = COALESCE(guarantee_3, 'Recompensas Reales'),
    show_guarantees = COALESCE(show_guarantees, true),
    text_align = COALESCE(text_align, 'left');
