-- Migration: 20261016000051_consolidate_and_fix_rls.sql
-- Description: Consolidate and repair RLS policies across trivia_options, system_alerts, landing CMS tables, and storage buckets; optimize RLS auth helpers as STABLE; fix search_path and trigger function execution leaks.

-- ============================================================================
-- 1. STABILIZE & OPTIMIZE RLS AUTH HELPERS (SINGLE SOURCE OF TRUTH)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.is_admin(user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    IF user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    RETURN EXISTS (
        SELECT 1 FROM public.staff_members 
        WHERE staff_members.user_id = is_admin.user_id 
          AND role = 'admin' 
          AND active = true
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

CREATE OR REPLACE FUNCTION public.is_staff_or_admin(user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    IF user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    RETURN EXISTS (
        SELECT 1 FROM public.staff_members 
        WHERE staff_members.user_id = is_staff_or_admin.user_id 
          AND active = true
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

CREATE OR REPLACE FUNCTION public.is_admin_check()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN public.is_admin(auth.uid());
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.is_admin(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_staff_or_admin(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_admin_check() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.is_admin(UUID) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.is_staff_or_admin(UUID) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.is_admin_check() TO authenticated, anon, service_role;


-- ============================================================================
-- 2. SECURE TRIVIA_OPTIONS (CLOSE CRITICAL DATA LEAKAGE OF is_correct)
-- ============================================================================

-- Drop all legacy, typo-named, or redundant policies
DROP POLICY IF EXISTS "Public reads trivia option text" ON public.trivia_options;
DROP POLICY IF EXISTS "Trivia Options Public Read" ON public.trivia_options;
DROP POLICY IF EXISTS "Admin manages options" ON public.trivia_options;
DROP POLICY IF EXISTS "Trivia Options Admin Select" ON public.trivia_options;
DROP POLICY IF EXISTS "Trivia Options Admin All" ON public.trivia_options;
DROP POLICY IF EXISTS "Trivia Options Staff Select" ON public.trivia_options;
DROP POLICY IF EXISTS "Trivia Options Staff All" ON public.trivia_options;

-- Single consolidated policy: only staff and admin can manage / read trivia options directly
CREATE POLICY "Trivia Options Staff Manage" ON public.trivia_options
    FOR ALL TO authenticated
    USING (public.is_staff_or_admin((SELECT auth.uid())))
    WITH CHECK (public.is_staff_or_admin((SELECT auth.uid())));


-- ============================================================================
-- 3. FIX SYSTEM_ALERTS RLS (PREVENT FATAL 42501 EXCEPTION CRASHES)
-- ============================================================================

DROP POLICY IF EXISTS system_alerts_admin_select ON public.system_alerts;
DROP POLICY IF EXISTS system_alerts_admin_update ON public.system_alerts;

CREATE POLICY system_alerts_admin_select ON public.system_alerts
    FOR SELECT TO authenticated
    USING (public.is_admin((SELECT auth.uid())));

CREATE POLICY system_alerts_admin_update ON public.system_alerts
    FOR UPDATE TO authenticated
    USING (public.is_admin((SELECT auth.uid())))
    WITH CHECK (public.is_admin((SELECT auth.uid())));


-- ============================================================================
-- 4. HARDEN STORAGE.OBJECTS RLS (BUCKETS: product-images & site-media)
-- ============================================================================

-- product-images
DROP POLICY IF EXISTS "ProductImages Admin Insert" ON storage.objects;
DROP POLICY IF EXISTS "ProductImages Admin Update" ON storage.objects;
DROP POLICY IF EXISTS "ProductImages Admin Delete" ON storage.objects;

CREATE POLICY "ProductImages Admin Insert" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'product-images' AND
        public.is_admin((SELECT auth.uid()))
    );

CREATE POLICY "ProductImages Admin Update" ON storage.objects
    FOR UPDATE TO authenticated
    USING (
        bucket_id = 'product-images' AND
        public.is_admin((SELECT auth.uid()))
    )
    WITH CHECK (
        bucket_id = 'product-images' AND
        public.is_admin((SELECT auth.uid()))
    );

CREATE POLICY "ProductImages Admin Delete" ON storage.objects
    FOR DELETE TO authenticated
    USING (
        bucket_id = 'product-images' AND
        public.is_admin((SELECT auth.uid()))
    );

-- site-media
DROP POLICY IF EXISTS "SiteMedia Admin Insert" ON storage.objects;
DROP POLICY IF EXISTS "SiteMedia Admin Update" ON storage.objects;
DROP POLICY IF EXISTS "SiteMedia Admin Delete" ON storage.objects;

CREATE POLICY "SiteMedia Admin Insert" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'site-media' AND
        public.is_admin((SELECT auth.uid()))
    );

CREATE POLICY "SiteMedia Admin Update" ON storage.objects
    FOR UPDATE TO authenticated
    USING (
        bucket_id = 'site-media' AND
        public.is_admin((SELECT auth.uid()))
    )
    WITH CHECK (
        bucket_id = 'site-media' AND
        public.is_admin((SELECT auth.uid()))
    );

CREATE POLICY "SiteMedia Admin Delete" ON storage.objects
    FOR DELETE TO authenticated
    USING (
        bucket_id = 'site-media' AND
        public.is_admin((SELECT auth.uid()))
    );


-- ============================================================================
-- 5. OPTIMIZE LANDING CMS ADMIN POLICIES (RESTRICT EVALUATION TO AUTHENTICATED)
-- ============================================================================

DROP POLICY IF EXISTS "Announcements Admin All" ON public.site_announcements;
CREATE POLICY "Announcements Admin All" ON public.site_announcements
    FOR ALL TO authenticated
    USING (public.is_admin((SELECT auth.uid())))
    WITH CHECK (public.is_admin((SELECT auth.uid())));

DROP POLICY IF EXISTS "Carousel Admin All" ON public.carousel_slides;
CREATE POLICY "Carousel Admin All" ON public.carousel_slides
    FOR ALL TO authenticated
    USING (public.is_admin((SELECT auth.uid())))
    WITH CHECK (public.is_admin((SELECT auth.uid())));

DROP POLICY IF EXISTS "History Admin All" ON public.history_milestones;
CREATE POLICY "History Admin All" ON public.history_milestones
    FOR ALL TO authenticated
    USING (public.is_admin((SELECT auth.uid())))
    WITH CHECK (public.is_admin((SELECT auth.uid())));

DROP POLICY IF EXISTS "SiteTeam Admin All" ON public.site_team_members;
CREATE POLICY "SiteTeam Admin All" ON public.site_team_members
    FOR ALL TO authenticated
    USING (public.is_admin((SELECT auth.uid())))
    WITH CHECK (public.is_admin((SELECT auth.uid())));

DROP POLICY IF EXISTS "FAQs Admin All" ON public.faqs;
CREATE POLICY "FAQs Admin All" ON public.faqs
    FOR ALL TO authenticated
    USING (public.is_admin((SELECT auth.uid())))
    WITH CHECK (public.is_admin((SELECT auth.uid())));

DROP POLICY IF EXISTS "Stats Admin All" ON public.site_stats;
CREATE POLICY "Stats Admin All" ON public.site_stats
    FOR ALL TO authenticated
    USING (public.is_admin((SELECT auth.uid())))
    WITH CHECK (public.is_admin((SELECT auth.uid())));

DROP POLICY IF EXISTS "SocialLinks Admin All" ON public.social_links;
CREATE POLICY "SocialLinks Admin All" ON public.social_links
    FOR ALL TO authenticated
    USING (public.is_admin((SELECT auth.uid())))
    WITH CHECK (public.is_admin((SELECT auth.uid())));

DROP POLICY IF EXISTS "PolicyDocs Admin All" ON public.policy_documents;
CREATE POLICY "PolicyDocs Admin All" ON public.policy_documents
    FOR ALL TO authenticated
    USING (public.is_admin((SELECT auth.uid())))
    WITH CHECK (public.is_admin((SELECT auth.uid())));

DROP POLICY IF EXISTS "Instagram Admin All" ON public.instagram_posts;
CREATE POLICY "Instagram Admin All" ON public.instagram_posts
    FOR ALL TO authenticated
    USING (public.is_admin((SELECT auth.uid())))
    WITH CHECK (public.is_admin((SELECT auth.uid())));

DROP POLICY IF EXISTS "Standings Admin All" ON public.standings;
CREATE POLICY "Standings Admin All" ON public.standings
    FOR ALL TO authenticated
    USING (public.is_admin((SELECT auth.uid())))
    WITH CHECK (public.is_admin((SELECT auth.uid())));

DROP POLICY IF EXISTS "Landing Settings Admin All" ON public.landing_settings;
CREATE POLICY "Landing Settings Admin All" ON public.landing_settings
    FOR ALL TO authenticated
    USING (public.is_admin((SELECT auth.uid())))
    WITH CHECK (public.is_admin((SELECT auth.uid())));


-- ============================================================================
-- 6. SECURITY HARDENING: SEARCH_PATH AND EXECUTE GRANTS ON INTERNAL / TRIGGERS
-- ============================================================================

-- Fix search_path mutable on ledger and audit log triggers
CREATE OR REPLACE FUNCTION public.prevent_ledger_mutation()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Financial Ledger entries are immutable. UPDATE and DELETE operations are forbidden.';
END;
$$ LANGUAGE plpgsql SET search_path = public, pg_temp;

CREATE OR REPLACE FUNCTION public.prevent_audit_log_mutation()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Audit Log entries are immutable. UPDATE and DELETE operations are forbidden.';
END;
$$ LANGUAGE plpgsql SET search_path = public, pg_temp;

CREATE OR REPLACE FUNCTION public.parse_instagram_shortcode(p_url TEXT)
RETURNS TEXT AS $$
DECLARE
    v_parts TEXT[];
BEGIN
    IF p_url IS NULL THEN RETURN NULL; END IF;
    IF p_url LIKE '%/p/%' THEN
        v_parts := string_to_array(p_url, '/p/');
        IF array_length(v_parts, 1) >= 2 THEN
            RETURN split_part(v_parts[2], '/', 1);
        END IF;
    ELSIF p_url LIKE '%/reel/%' THEN
        v_parts := string_to_array(p_url, '/reel/');
        IF array_length(v_parts, 1) >= 2 THEN
            RETURN split_part(v_parts[2], '/', 1);
        END IF;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql IMMUTABLE SET search_path = public, pg_temp;

-- Revoke execute from public / anon on trigger and administrative functions
REVOKE ALL ON FUNCTION public.assert_min_admins() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.check_max_5_published_login_modal_slides() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.purge_auth_identities(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.purge_auth_identities(UUID) TO service_role;

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
