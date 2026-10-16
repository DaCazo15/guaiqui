-- Migration: 20261009000014_fase9b_landing_content.sql
-- Description: Database tables, RLS policies, storage bucket, and legal policy version control for Landing Page & Admin Management (Fase 9B)

-- 1. Site Announcements
CREATE TABLE IF NOT EXISTS public.site_announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message TEXT NOT NULL,
    link_url TEXT,
    is_published BOOLEAN NOT NULL DEFAULT true,
    starts_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ends_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Carousel Slides
CREATE TABLE IF NOT EXISTS public.carousel_slides (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tag TEXT,
    title TEXT NOT NULL,
    subtitle TEXT,
    cta_text TEXT,
    cta_url TEXT,
    image_url TEXT,
    bg_gradient TEXT DEFAULT 'from-emerald-900 via-guaiqui-primary-dark to-slate-900',
    badge_variant TEXT DEFAULT 'primary',
    order_index INT NOT NULL DEFAULT 0,
    is_published BOOLEAN NOT NULL DEFAULT true,
    starts_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ends_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. History Milestones
CREATE TABLE IF NOT EXISTS public.history_milestones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    year TEXT NOT NULL,
    title TEXT NOT NULL,
    text TEXT NOT NULL,
    image_url TEXT,
    order_index INT NOT NULL DEFAULT 0,
    is_published BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Site Team Members (Directiva, Cuerpo Técnico, Mascota)
CREATE TABLE IF NOT EXISTS public.site_team_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    role TEXT NOT NULL,
    group_category TEXT NOT NULL CHECK (group_category IN ('directiva', 'tecnico', 'logistica')),
    photo_url TEXT,
    order_index INT NOT NULL DEFAULT 0,
    is_published BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. FAQs
CREATE TABLE IF NOT EXISTS public.faqs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    question TEXT NOT NULL,
    answer TEXT NOT NULL,
    order_index INT NOT NULL DEFAULT 0,
    is_published BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. Site Stats and Sponsors
CREATE TABLE IF NOT EXISTS public.site_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    label TEXT NOT NULL,
    value TEXT NOT NULL,
    note TEXT,
    is_sponsor BOOLEAN NOT NULL DEFAULT false,
    logo_url TEXT,
    order_index INT NOT NULL DEFAULT 0,
    is_published BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. Social Links & Footer
CREATE TABLE IF NOT EXISTS public.social_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    platform TEXT NOT NULL,
    label TEXT NOT NULL,
    url TEXT NOT NULL,
    icon TEXT,
    order_index INT NOT NULL DEFAULT 0,
    is_published BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 8. Policy Documents (Términos, Privacidad, Perlitas, Canjes)
CREATE TABLE IF NOT EXISTS public.policy_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug TEXT NOT NULL CHECK (slug IN ('terminos', 'privacidad', 'perlitas', 'canjes')),
    version TEXT NOT NULL,
    content_markdown TEXT NOT NULL,
    published_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS on all content tables
ALTER TABLE public.site_announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.carousel_slides ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.history_milestones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.site_team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.faqs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.site_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.social_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.policy_documents ENABLE ROW LEVEL SECURITY;

-- Helper function to check if current caller is Admin
CREATE OR REPLACE FUNCTION public.is_admin_check()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.staff_members
        WHERE user_id = auth.uid() AND role = 'admin' AND active = true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- RLS Public Read Policies
DROP POLICY IF EXISTS "Announcements Public Read" ON public.site_announcements;
CREATE POLICY "Announcements Public Read" ON public.site_announcements
    FOR SELECT USING (
        is_published = true AND
        (starts_at <= NOW()) AND
        (ends_at IS NULL OR ends_at >= NOW())
    );

DROP POLICY IF EXISTS "Carousel Public Read" ON public.carousel_slides;
CREATE POLICY "Carousel Public Read" ON public.carousel_slides
    FOR SELECT USING (
        is_published = true AND
        (starts_at <= NOW()) AND
        (ends_at IS NULL OR ends_at >= NOW())
    );

DROP POLICY IF EXISTS "History Public Read" ON public.history_milestones;
CREATE POLICY "History Public Read" ON public.history_milestones
    FOR SELECT USING (is_published = true);

DROP POLICY IF EXISTS "SiteTeam Public Read" ON public.site_team_members;
CREATE POLICY "SiteTeam Public Read" ON public.site_team_members
    FOR SELECT USING (is_published = true);

DROP POLICY IF EXISTS "FAQs Public Read" ON public.faqs;
CREATE POLICY "FAQs Public Read" ON public.faqs
    FOR SELECT USING (is_published = true);

DROP POLICY IF EXISTS "Stats Public Read" ON public.site_stats;
CREATE POLICY "Stats Public Read" ON public.site_stats
    FOR SELECT USING (is_published = true);

DROP POLICY IF EXISTS "SocialLinks Public Read" ON public.social_links;
CREATE POLICY "SocialLinks Public Read" ON public.social_links
    FOR SELECT USING (is_published = true);

DROP POLICY IF EXISTS "PolicyDocs Public Read" ON public.policy_documents;
CREATE POLICY "PolicyDocs Public Read" ON public.policy_documents
    FOR SELECT USING (is_active = true);

-- RLS Admin All Access Policies
DROP POLICY IF EXISTS "Announcements Admin All" ON public.site_announcements;
CREATE POLICY "Announcements Admin All" ON public.site_announcements
    FOR ALL USING (public.is_admin_check());

DROP POLICY IF EXISTS "Carousel Admin All" ON public.carousel_slides;
CREATE POLICY "Carousel Admin All" ON public.carousel_slides
    FOR ALL USING (public.is_admin_check());

DROP POLICY IF EXISTS "History Admin All" ON public.history_milestones;
CREATE POLICY "History Admin All" ON public.history_milestones
    FOR ALL USING (public.is_admin_check());

DROP POLICY IF EXISTS "SiteTeam Admin All" ON public.site_team_members;
CREATE POLICY "SiteTeam Admin All" ON public.site_team_members
    FOR ALL USING (public.is_admin_check());

DROP POLICY IF EXISTS "FAQs Admin All" ON public.faqs;
CREATE POLICY "FAQs Admin All" ON public.faqs
    FOR ALL USING (public.is_admin_check());

DROP POLICY IF EXISTS "Stats Admin All" ON public.site_stats;
CREATE POLICY "Stats Admin All" ON public.site_stats
    FOR ALL USING (public.is_admin_check());

DROP POLICY IF EXISTS "SocialLinks Admin All" ON public.social_links;
CREATE POLICY "SocialLinks Admin All" ON public.social_links
    FOR ALL USING (public.is_admin_check());

DROP POLICY IF EXISTS "PolicyDocs Admin All" ON public.policy_documents;
CREATE POLICY "PolicyDocs Admin All" ON public.policy_documents
    FOR ALL USING (public.is_admin_check());

-- Storage Bucket 'site-media'
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'site-media',
    'site-media',
    true,
    5242880, -- 5 MB
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/svg+xml']
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/svg+xml'];

DROP POLICY IF EXISTS "SiteMedia Public Read" ON storage.objects;
CREATE POLICY "SiteMedia Public Read" ON storage.objects
    FOR SELECT USING (bucket_id = 'site-media');

DROP POLICY IF EXISTS "SiteMedia Admin Insert" ON storage.objects;
CREATE POLICY "SiteMedia Admin Insert" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'site-media' AND public.is_admin_check()
    );

DROP POLICY IF EXISTS "SiteMedia Admin Update" ON storage.objects;
CREATE POLICY "SiteMedia Admin Update" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'site-media' AND public.is_admin_check()
    );

DROP POLICY IF EXISTS "SiteMedia Admin Delete" ON storage.objects;
CREATE POLICY "SiteMedia Admin Delete" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'site-media' AND public.is_admin_check()
    );

-- RPC Admin Publish Policy Document (Versión nueva que desactualiza las anteriores)
CREATE OR REPLACE FUNCTION public.admin_publish_policy(
    p_slug TEXT,
    p_version TEXT,
    p_content TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_new_id UUID;
BEGIN
    PERFORM public.assert_admin();

    IF p_slug NOT IN ('terminos', 'privacidad', 'perlitas', 'canjes') THEN
        RAISE EXCEPTION 'Slug de política inválido: %', p_slug;
    END IF;

    IF p_version IS NULL OR trim(p_version) = '' THEN
        RAISE EXCEPTION 'La versión de la política es obligatoria.';
    END IF;

    IF p_content IS NULL OR trim(p_content) = '' THEN
        RAISE EXCEPTION 'El contenido de la política en Markdown no puede estar vacío.';
    END IF;

    -- Deactivate current active policy for this slug
    UPDATE public.policy_documents
    SET is_active = false
    WHERE slug = p_slug AND is_active = true;

    -- Insert new active policy version
    INSERT INTO public.policy_documents (
        slug, version, content_markdown, published_at, is_active
    ) VALUES (
        p_slug, p_version, p_content, NOW(), true
    ) RETURNING id INTO v_new_id;

    -- Audit log
    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'publish_policy_document', 'policy_documents', v_new_id::text,
        jsonb_build_object('slug', p_slug, 'version', p_version)
    );

    RETURN jsonb_build_object('id', v_new_id, 'slug', p_slug, 'version', p_version, 'status', 'published');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.admin_publish_policy(TEXT, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_publish_policy(TEXT, TEXT, TEXT) TO authenticated, service_role;

-- RPC Get Active Legal Versions (Para verificación en middleware)
CREATE OR REPLACE FUNCTION public.get_active_legal_versions()
RETURNS JSONB AS $$
DECLARE
    v_res JSONB;
BEGIN
    SELECT jsonb_object_agg(slug, version)
    INTO v_res
    FROM (
        SELECT slug, version
        FROM public.policy_documents
        WHERE is_active = true
    ) sub;

    RETURN COALESCE(v_res, '{"terminos": "v1.0", "privacidad": "v1.0", "perlitas": "v1.0", "canjes": "v1.0"}'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

GRANT EXECUTE ON FUNCTION public.get_active_legal_versions() TO PUBLIC, anon, authenticated, service_role;

-- Initial Seed Data for Legal Policies (v1.0)
INSERT INTO public.policy_documents (slug, version, content_markdown, is_active)
VALUES
  ('terminos', 'v1.0', '# Términos y Condiciones Oficiales\n\nBienvenido a Guaiqueríes Fan Zone. Al registrarte y utilizar nuestra plataforma aceptas las normas aquí descritas.', true),
  ('privacidad', 'v1.0', '# Política de Privacidad\n\nNos tomamos muy en serio la protección de tus datos personales. No comercializamos tu información.', true),
  ('perlitas', 'v1.0', '# Reglas del Programa de Perlitas\n\nLas perlitas son puntos de fidelidad virtuales sin valor monetario real. Se ganan jugando trivias y se canjean por recompensas.', true),
  ('canjes', 'v1.0', '# Políticas de Canje de Premios\n\nLos canjes se realizan mediante códigos QR presentados en taquilla. Los productos no tienen devolución monetaria.', true)
ON CONFLICT DO NOTHING;
