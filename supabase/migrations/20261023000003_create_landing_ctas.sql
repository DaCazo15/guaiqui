-- ============================================================================
-- Migration: Create landing_ctas table, RLS policies, and activation RPC
-- Allows admin to manage multiple CTAs (Container vs Phrase mode) with
-- customizable typography, letter-spacing, and media (logo, icon, image).
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.landing_ctas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(120) NOT NULL,
    type VARCHAR(30) NOT NULL DEFAULT 'container' CHECK (type IN ('container', 'phrase')),
    is_active BOOLEAN NOT NULL DEFAULT false,
    is_published BOOLEAN NOT NULL DEFAULT true,
    
    -- Container mode fields
    badge_text VARCHAR(100),
    heading TEXT,
    subtitle TEXT,
    button_text VARCHAR(100),
    button_url VARCHAR(255),
    bg_gradient VARCHAR(255) DEFAULT 'from-guaiqui-primary-dark via-emerald-900 to-slate-950',
    
    -- Phrase mode fields
    phrase_text TEXT,
    font_family VARCHAR(80) DEFAULT 'Barlow Condensed',
    font_size VARCHAR(50) DEFAULT '5xl',
    letter_spacing VARCHAR(50) DEFAULT 'tracking-tight',
    font_weight VARCHAR(50) DEFAULT 'font-extrabold',
    text_color VARCHAR(50) DEFAULT 'text-white',
    media_type VARCHAR(30) DEFAULT 'none' CHECK (media_type IN ('none', 'logo', 'icon', 'image')),
    media_value TEXT,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.landing_ctas ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Landing CTAs Admin All" ON public.landing_ctas;
DROP POLICY IF EXISTS "Landing CTAs Public Read" ON public.landing_ctas;

-- Policies
CREATE POLICY "Landing CTAs Admin All" ON public.landing_ctas
    FOR ALL TO authenticated
    USING (public.is_admin_check())
    WITH CHECK (public.is_admin_check());

CREATE POLICY "Landing CTAs Public Read" ON public.landing_ctas
    FOR SELECT TO public
    USING (is_published = true);

-- Function to atomically activate a specific CTA
CREATE OR REPLACE FUNCTION public.activate_landing_cta(p_id UUID)
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
BEGIN ATOMIC
    UPDATE public.landing_ctas
    SET is_active = (id = p_id),
        updated_at = now()
    WHERE public.is_admin_check();
END;

REVOKE ALL ON FUNCTION public.activate_landing_cta(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.activate_landing_cta(UUID) TO authenticated, service_role;

-- Insert initial active CTA with current production values so existing landing retains its state
INSERT INTO public.landing_ctas (
    name,
    type,
    is_active,
    is_published,
    badge_text,
    heading,
    subtitle,
    button_text,
    button_url,
    bg_gradient
)
SELECT
    'Llamado Oficial de Registro',
    'container',
    true,
    true,
    '¡Únete a la Tribu Hoy!',
    '¿Listo para ganar tu primer premio?',
    'El registro toma menos de 1 minuto y recibirás un bono de bienvenida de +100 puntos para comenzar.',
    'Crear mi Cuenta Gratis',
    '/registro',
    'from-guaiqui-primary-dark via-emerald-900 to-slate-950'
WHERE NOT EXISTS (
    SELECT 1 FROM public.landing_ctas WHERE is_active = true
);
