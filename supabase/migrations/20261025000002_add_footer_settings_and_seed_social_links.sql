-- Migration: 20261025000002_add_footer_settings_and_seed_social_links.sql
-- Description:
-- 1. Add footer text configuration columns to public.landing_settings.
-- 2. Seed default official social links in public.social_links.
-- 3. Reload PostgREST schema cache.

-- 1. Add columns to landing_settings
ALTER TABLE public.landing_settings
    ADD COLUMN IF NOT EXISTS footer_brand_description TEXT DEFAULT 'Plataforma oficial de fidelización de Guaiqueríes de Margarita. Fan Zone 2026.',
    ADD COLUMN IF NOT EXISTS footer_location TEXT DEFAULT 'Gimnasio Ciudad de La Asunción, Nueva Esparta',
    ADD COLUMN IF NOT EXISTS footer_support_text TEXT DEFAULT '¿Tienes alguna duda sobre tus puntos o tu canje?',
    ADD COLUMN IF NOT EXISTS footer_support_hours TEXT DEFAULT 'Atención presencial en días de juego: 4:00 PM a 9:00 PM.',
    ADD COLUMN IF NOT EXISTS footer_support_url TEXT DEFAULT '/contacto',
    ADD COLUMN IF NOT EXISTS footer_copyright TEXT DEFAULT '© 2026 Guaiqueríes de Margarita. Todos los derechos reservados.',
    ADD COLUMN IF NOT EXISTS footer_disclaimer TEXT DEFAULT 'Sin pagos con dinero real • 100% Fidelización Gratuita';

-- 2. Seed initial official social media links
INSERT INTO public.social_links (platform, label, url, icon, order_index, is_published)
SELECT 'instagram', 'Instagram Oficial', 'https://www.instagram.com/guaiqueriesbbc/', 'bi-instagram', 1, true
WHERE NOT EXISTS (SELECT 1 FROM public.social_links WHERE platform = 'instagram');

INSERT INTO public.social_links (platform, label, url, icon, order_index, is_published)
SELECT 'x', 'X (Twitter)', 'https://twitter.com/Guaiqueries_bbc', 'bi-twitter-x', 2, true
WHERE NOT EXISTS (SELECT 1 FROM public.social_links WHERE platform = 'x');

INSERT INTO public.social_links (platform, label, url, icon, order_index, is_published)
SELECT 'facebook', 'Facebook', 'https://www.facebook.com/guaiqueriesbbc/', 'bi-facebook', 3, true
WHERE NOT EXISTS (SELECT 1 FROM public.social_links WHERE platform = 'facebook');

INSERT INTO public.social_links (platform, label, url, icon, order_index, is_published)
SELECT 'youtube', 'YouTube Oficial', 'https://www.youtube.com/@guaiqueriesbbc', 'bi-youtube', 4, true
WHERE NOT EXISTS (SELECT 1 FROM public.social_links WHERE platform = 'youtube');

INSERT INTO public.social_links (platform, label, url, icon, order_index, is_published)
SELECT 'tiktok', 'TikTok', 'https://www.tiktok.com/@guaiqueriesbbc', 'bi-tiktok', 5, true
WHERE NOT EXISTS (SELECT 1 FROM public.social_links WHERE platform = 'tiktok');

-- 3. Reload schema cache
NOTIFY pgrst, 'reload schema';
