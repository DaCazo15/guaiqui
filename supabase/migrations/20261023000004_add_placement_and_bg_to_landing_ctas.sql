-- ============================================================================
-- Migration: Add placement and custom bg_color to landing_ctas
-- Allows admins to place CTAs 'after_hero' or 'before_footer' and select
-- a custom background color or preset palette for both container and phrase modes.
-- ============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'landing_ctas' 
          AND column_name = 'placement'
    ) THEN
        ALTER TABLE public.landing_ctas 
        ADD COLUMN placement VARCHAR(30) NOT NULL DEFAULT 'before_footer' 
        CHECK (placement IN ('before_footer', 'after_hero'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'landing_ctas' 
          AND column_name = 'bg_color'
    ) THEN
        ALTER TABLE public.landing_ctas 
        ADD COLUMN bg_color VARCHAR(100) DEFAULT NULL;
    END IF;
END $$;

-- Update activate_landing_cta to activate per placement slot
CREATE OR REPLACE FUNCTION public.activate_landing_cta(p_id UUID)
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
BEGIN ATOMIC
    UPDATE public.landing_ctas AS target
    SET is_active = (target.id = p_id),
        updated_at = now()
    FROM (SELECT placement FROM public.landing_ctas WHERE id = p_id) AS current_item
    WHERE target.placement = current_item.placement
      AND public.is_admin_check();
END;

REVOKE ALL ON FUNCTION public.activate_landing_cta(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.activate_landing_cta(UUID) TO authenticated, service_role;
