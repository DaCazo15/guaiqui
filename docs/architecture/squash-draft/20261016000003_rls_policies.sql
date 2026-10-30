-- ============================================================================
-- Migration: 20261016000003_rls_policies.sql
-- Description: Consolidated, hardened Row Level Security (RLS) policies for all
--              tables and storage objects. Uses (SELECT auth.uid()) for InitPlan
--              optimization, seals trivia_options data leakage, and ensures
--              symmetric WITH CHECK on mutations.
-- ============================================================================

-- Enable RLS on all public tables
ALTER TABLE public.players ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ledger_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ledger_hold_resolutions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.games ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trivias ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trivia_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trivia_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trivia_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.redemptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.redemption_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scan_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.economy_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.risk_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.risk_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_outbox ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.site_announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.carousel_slides ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.history_milestones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.site_team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.faqs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.site_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.social_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.policy_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.standings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.captcha_passes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rate_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.instagram_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocked_identities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fraud_telemetry ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.birthday_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.landing_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_secrets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_usage_tracker ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mfa_recovery_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.display_name_change_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.login_modal_slides ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ad_reward_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ad_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ad_daily_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ad_reconciliation ENABLE ROW LEVEL SECURITY;

-- Enable RLS on storage.objects
DO $$
BEGIN
  IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid = 'storage.objects'::regclass) THEN
    EXECUTE 'ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY';
  END IF;
END $$;

-- ----------------------------------------------------------------------------
-- Policies for public.ad_reconciliation
-- ----------------------------------------------------------------------------
CREATE POLICY "AdReconciliation Admin Read" ON public.ad_reconciliation
    FOR SELECT TO authenticated
    USING (is_admin_check())
;

-- ----------------------------------------------------------------------------
-- Policies for public.ad_reward_tiers
-- ----------------------------------------------------------------------------
CREATE POLICY "AdRewardTiers Admin Write" ON public.ad_reward_tiers
    FOR ALL TO authenticated
    USING (is_admin_check())
;

CREATE POLICY "AdRewardTiers Public Read" ON public.ad_reward_tiers
    FOR SELECT TO anon,authenticated
    USING (true)
;

-- ----------------------------------------------------------------------------
-- Policies for public.audit_log
-- ----------------------------------------------------------------------------
CREATE POLICY "Admin views audit log" ON public.audit_log
    FOR SELECT TO authenticated
    USING (is_admin((SELECT auth.uid())))
;

-- ----------------------------------------------------------------------------
-- Policies for public.birthday_settings
-- ----------------------------------------------------------------------------
CREATE POLICY "BirthdaySettings Admin Write" ON public.birthday_settings
    FOR ALL TO authenticated
    USING (is_admin_check())
;

CREATE POLICY "BirthdaySettings Public Read" ON public.birthday_settings
    FOR SELECT TO anon,authenticated
    USING (true)
;

-- ----------------------------------------------------------------------------
-- Policies for public.carousel_slides
-- ----------------------------------------------------------------------------
CREATE POLICY "Carousel Admin All" ON public.carousel_slides
    FOR ALL TO authenticated
    USING (is_admin_check())
;

CREATE POLICY "Carousel Public Read" ON public.carousel_slides
    FOR SELECT TO public
    USING (((is_published = true) AND (starts_at <= now()) AND ((ends_at IS NULL) OR (ends_at >= now()))))
;

-- ----------------------------------------------------------------------------
-- Policies for public.economy_settings
-- ----------------------------------------------------------------------------
CREATE POLICY "Admin manages economy settings" ON public.economy_settings
    FOR ALL TO authenticated
    USING (is_admin((SELECT auth.uid())))
;

-- ----------------------------------------------------------------------------
-- Policies for public.faqs
-- ----------------------------------------------------------------------------
CREATE POLICY "FAQs Admin All" ON public.faqs
    FOR ALL TO authenticated
    USING (is_admin_check())
;

CREATE POLICY "FAQs Public Read" ON public.faqs
    FOR SELECT TO public
    USING ((is_published = true))
;

-- ----------------------------------------------------------------------------
-- Policies for public.games
-- ----------------------------------------------------------------------------
CREATE POLICY "Admin manages games" ON public.games
    FOR ALL TO authenticated
    USING (is_admin((SELECT auth.uid())))
;

CREATE POLICY "Public reads games schedule" ON public.games
    FOR SELECT TO anon,authenticated
    USING (true)
;

-- ----------------------------------------------------------------------------
-- Policies for public.history_milestones
-- ----------------------------------------------------------------------------
CREATE POLICY "History Admin All" ON public.history_milestones
    FOR ALL TO authenticated
    USING (is_admin_check())
;

CREATE POLICY "History Public Read" ON public.history_milestones
    FOR SELECT TO public
    USING ((is_published = true))
;

-- ----------------------------------------------------------------------------
-- Policies for public.instagram_posts
-- ----------------------------------------------------------------------------
CREATE POLICY "Instagram Admin All" ON public.instagram_posts
    FOR ALL TO authenticated
    USING (is_admin_check())
;

CREATE POLICY "Instagram Public Read" ON public.instagram_posts
    FOR SELECT TO public
    USING ((is_published = true))
;

-- ----------------------------------------------------------------------------
-- Policies for public.landing_settings
-- ----------------------------------------------------------------------------
CREATE POLICY "Landing Settings Admin All" ON public.landing_settings
    FOR ALL TO authenticated
    USING (is_admin_check())
;

CREATE POLICY "Landing Settings Public Read" ON public.landing_settings
    FOR SELECT TO public
    USING (true)
;

-- ----------------------------------------------------------------------------
-- Policies for public.ledger_entries
-- ----------------------------------------------------------------------------
CREATE POLICY "Admin manages ledger" ON public.ledger_entries
    FOR ALL TO authenticated
    USING (is_admin((SELECT auth.uid())))
;

CREATE POLICY "Fan reads own ledger entries" ON public.ledger_entries
    FOR SELECT TO authenticated
    USING (((fan_id = (SELECT auth.uid())) OR is_staff_or_admin((SELECT auth.uid()))))
;

-- ----------------------------------------------------------------------------
-- Policies for public.login_modal_slides
-- ----------------------------------------------------------------------------
CREATE POLICY "LoginModalSlides Admin All" ON public.login_modal_slides
    FOR ALL TO authenticated
    USING (is_admin_check())
;

CREATE POLICY "LoginModalSlides Fan Read" ON public.login_modal_slides
    FOR SELECT TO anon,authenticated
    USING (((status = 'published'::text) AND (starts_at <= now()) AND ((ends_at IS NULL) OR (ends_at >= now()))))
;

-- ----------------------------------------------------------------------------
-- Policies for public.notifications
-- ----------------------------------------------------------------------------
CREATE POLICY "notifications_select_policy" ON public.notifications
    FOR SELECT TO authenticated
    USING (((SELECT auth.uid()) = user_id))
;

CREATE POLICY "notifications_update_policy" ON public.notifications
    FOR UPDATE TO authenticated
    USING (((SELECT auth.uid()) = user_id))
    WITH CHECK (((SELECT auth.uid()) = user_id))
;

-- ----------------------------------------------------------------------------
-- Policies for public.players
-- ----------------------------------------------------------------------------
CREATE POLICY "Admin manages players" ON public.players
    FOR ALL TO authenticated
    USING (is_admin((SELECT auth.uid())))
;

CREATE POLICY "Public reads active players" ON public.players
    FOR SELECT TO anon,authenticated
    USING (((is_active = true) OR is_staff_or_admin((SELECT auth.uid()))))
;

-- ----------------------------------------------------------------------------
-- Policies for public.policy_documents
-- ----------------------------------------------------------------------------
CREATE POLICY "PolicyDocs Admin All" ON public.policy_documents
    FOR ALL TO authenticated
    USING (is_admin_check())
;

CREATE POLICY "PolicyDocs Public Read" ON public.policy_documents
    FOR SELECT TO public
    USING ((is_active = true))
;

-- ----------------------------------------------------------------------------
-- Policies for public.products
-- ----------------------------------------------------------------------------
CREATE POLICY "Admin manages products" ON public.products
    FOR ALL TO authenticated
    USING (is_admin((SELECT auth.uid())))
;

CREATE POLICY "Public reads active products" ON public.products
    FOR SELECT TO anon,authenticated
    USING (((active = true) OR is_staff_or_admin((SELECT auth.uid()))))
;

CREATE POLICY "Staff manages product stock" ON public.products
    FOR UPDATE TO authenticated
    USING (is_staff_or_admin((SELECT auth.uid())))
;

-- ----------------------------------------------------------------------------
-- Policies for public.profiles
-- ----------------------------------------------------------------------------
CREATE POLICY "Admin manages all profiles" ON public.profiles
    FOR ALL TO authenticated
    USING (is_admin((SELECT auth.uid())))
;

CREATE POLICY "Fan reads own profile" ON public.profiles
    FOR SELECT TO authenticated
    USING (((id = (SELECT auth.uid())) OR is_staff_or_admin((SELECT auth.uid()))))
;

CREATE POLICY "Fan updates own profile" ON public.profiles
    FOR UPDATE TO authenticated
    USING ((id = (SELECT auth.uid())))
    WITH CHECK ((id = (SELECT auth.uid())))
;

-- ----------------------------------------------------------------------------
-- Policies for public.redemption_history
-- ----------------------------------------------------------------------------
CREATE POLICY "Fan reads own redemption history" ON public.redemption_history
    FOR SELECT TO authenticated
    USING (((EXISTS ( SELECT 1
   FROM redemptions r
  WHERE ((r.id = redemption_history.redemption_id) AND (r.fan_id = (SELECT auth.uid()))))) OR is_staff_or_admin((SELECT auth.uid()))))
;

CREATE POLICY "Staff reads redemption history" ON public.redemption_history
    FOR SELECT TO authenticated
    USING (is_staff_or_admin((SELECT auth.uid())))
;

-- ----------------------------------------------------------------------------
-- Policies for public.redemptions
-- ----------------------------------------------------------------------------
CREATE POLICY "Fan reads own redemptions" ON public.redemptions
    FOR SELECT TO authenticated
    USING (((fan_id = (SELECT auth.uid())) OR is_staff_or_admin((SELECT auth.uid()))))
;

CREATE POLICY "Staff manages redemptions" ON public.redemptions
    FOR ALL TO authenticated
    USING (is_staff_or_admin((SELECT auth.uid())))
;

-- ----------------------------------------------------------------------------
-- Policies for public.risk_flags
-- ----------------------------------------------------------------------------
CREATE POLICY "Admin manages risk flags" ON public.risk_flags
    FOR ALL TO authenticated
    USING (is_admin((SELECT auth.uid())))
;

-- ----------------------------------------------------------------------------
-- Policies for public.scan_events
-- ----------------------------------------------------------------------------
CREATE POLICY "Staff logs scan events" ON public.scan_events
    FOR ALL TO authenticated
    USING (is_staff_or_admin((SELECT auth.uid())))
;

-- ----------------------------------------------------------------------------
-- Policies for public.segments
-- ----------------------------------------------------------------------------
CREATE POLICY "Admin manages segments" ON public.segments
    FOR ALL TO authenticated
    USING (is_admin((SELECT auth.uid())))
;

-- ----------------------------------------------------------------------------
-- Policies for public.site_announcements
-- ----------------------------------------------------------------------------
CREATE POLICY "Announcements Admin All" ON public.site_announcements
    FOR ALL TO authenticated
    USING (is_admin_check())
;

CREATE POLICY "Announcements Public Read" ON public.site_announcements
    FOR SELECT TO public
    USING (((is_published = true) AND (starts_at <= now()) AND ((ends_at IS NULL) OR (ends_at >= now()))))
;

-- ----------------------------------------------------------------------------
-- Policies for public.site_stats
-- ----------------------------------------------------------------------------
CREATE POLICY "Stats Admin All" ON public.site_stats
    FOR ALL TO authenticated
    USING (is_admin_check())
;

CREATE POLICY "Stats Public Read" ON public.site_stats
    FOR SELECT TO public
    USING ((is_published = true))
;

-- ----------------------------------------------------------------------------
-- Policies for public.site_team_members
-- ----------------------------------------------------------------------------
CREATE POLICY "SiteTeam Admin All" ON public.site_team_members
    FOR ALL TO authenticated
    USING (is_admin_check())
;

CREATE POLICY "SiteTeam Public Read" ON public.site_team_members
    FOR SELECT TO public
    USING ((is_published = true))
;

-- ----------------------------------------------------------------------------
-- Policies for public.social_links
-- ----------------------------------------------------------------------------
CREATE POLICY "SocialLinks Admin All" ON public.social_links
    FOR ALL TO authenticated
    USING (is_admin_check())
;

CREATE POLICY "SocialLinks Public Read" ON public.social_links
    FOR SELECT TO public
    USING ((is_published = true))
;

-- ----------------------------------------------------------------------------
-- Policies for public.staff_members
-- ----------------------------------------------------------------------------
CREATE POLICY "Admin manages staff members" ON public.staff_members
    FOR ALL TO authenticated
    USING (is_admin((SELECT auth.uid())))
;

CREATE POLICY "Staff reads staff directory" ON public.staff_members
    FOR SELECT TO authenticated
    USING (is_staff_or_admin((SELECT auth.uid())))
;

-- ----------------------------------------------------------------------------
-- Policies for public.standings
-- ----------------------------------------------------------------------------
CREATE POLICY "Standings Admin All" ON public.standings
    FOR ALL TO authenticated
    USING (is_admin_check())
;

CREATE POLICY "Standings Public Read" ON public.standings
    FOR SELECT TO public
    USING (true)
;

-- ----------------------------------------------------------------------------
-- Policies for public.system_alerts
-- ----------------------------------------------------------------------------
CREATE POLICY system_alerts_admin_select ON public.system_alerts
    FOR SELECT TO authenticated
    USING (public.is_admin((SELECT auth.uid())));

CREATE POLICY system_alerts_admin_update ON public.system_alerts
    FOR UPDATE TO authenticated
    USING (public.is_admin((SELECT auth.uid())))
    WITH CHECK (public.is_admin((SELECT auth.uid())));

-- ----------------------------------------------------------------------------
-- Policies for public.trivia_attempts
-- ----------------------------------------------------------------------------
CREATE POLICY "Admin manages attempts" ON public.trivia_attempts
    FOR ALL TO authenticated
    USING (is_admin((SELECT auth.uid())))
;

CREATE POLICY "Fan reads own attempts" ON public.trivia_attempts
    FOR SELECT TO authenticated
    USING (((fan_id = (SELECT auth.uid())) OR is_staff_or_admin((SELECT auth.uid()))))
;

-- ----------------------------------------------------------------------------
-- Policies for public.trivia_options
-- ----------------------------------------------------------------------------
CREATE POLICY "Trivia Options Staff Manage" ON public.trivia_options
    FOR ALL TO authenticated
    USING (public.is_staff_or_admin((SELECT auth.uid())))
    WITH CHECK (public.is_staff_or_admin((SELECT auth.uid())));

-- ----------------------------------------------------------------------------
-- Policies for public.trivia_questions
-- ----------------------------------------------------------------------------
CREATE POLICY "Admin manages questions" ON public.trivia_questions
    FOR ALL TO authenticated
    USING (is_admin((SELECT auth.uid())))
;

CREATE POLICY "Public reads trivia questions" ON public.trivia_questions
    FOR SELECT TO anon,authenticated
    USING (true)
;

-- ----------------------------------------------------------------------------
-- Policies for public.trivias
-- ----------------------------------------------------------------------------
CREATE POLICY "Admin manages trivias" ON public.trivias
    FOR ALL TO authenticated
    USING (is_admin((SELECT auth.uid())))
;

CREATE POLICY "Public reads published trivias" ON public.trivias
    FOR SELECT TO anon,authenticated
    USING (((status = ANY (ARRAY['published'::trivia_status, 'archived'::trivia_status])) OR is_staff_or_admin((SELECT auth.uid()))))
;

-- ----------------------------------------------------------------------------
-- Policies for public.wallets
-- ----------------------------------------------------------------------------
CREATE POLICY "Admin manages wallets" ON public.wallets
    FOR ALL TO authenticated
    USING (is_admin((SELECT auth.uid())))
;

CREATE POLICY "Fan reads own wallet" ON public.wallets
    FOR SELECT TO authenticated
    USING (((fan_id = (SELECT auth.uid())) OR is_staff_or_admin((SELECT auth.uid()))))
;

-- ----------------------------------------------------------------------------
-- Policies for storage.objects
-- ----------------------------------------------------------------------------
CREATE POLICY "ProductImages Public Select" ON storage.objects
    FOR SELECT TO public
    USING (bucket_id = 'product-images');

CREATE POLICY "ProductImages Admin Insert" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'product-images' AND public.is_admin((SELECT auth.uid())));

CREATE POLICY "ProductImages Admin Update" ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'product-images' AND public.is_admin((SELECT auth.uid())))
    WITH CHECK (bucket_id = 'product-images' AND public.is_admin((SELECT auth.uid())));

CREATE POLICY "ProductImages Admin Delete" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'product-images' AND public.is_admin((SELECT auth.uid())));

CREATE POLICY "SiteMedia Public Select" ON storage.objects
    FOR SELECT TO public
    USING (bucket_id = 'site-media');

CREATE POLICY "SiteMedia Admin Insert" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'site-media' AND public.is_admin((SELECT auth.uid())));

CREATE POLICY "SiteMedia Admin Update" ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'site-media' AND public.is_admin((SELECT auth.uid())))
    WITH CHECK (bucket_id = 'site-media' AND public.is_admin((SELECT auth.uid())));

CREATE POLICY "SiteMedia Admin Delete" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'site-media' AND public.is_admin((SELECT auth.uid())));

CREATE POLICY "Avatars Public Select" ON storage.objects
    FOR SELECT TO public
    USING (bucket_id = 'avatars');

CREATE POLICY "Avatars User Insert" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'avatars' AND
        (storage.foldername(name))[1] = (SELECT auth.uid())::text
    );

CREATE POLICY "Avatars User Update" ON storage.objects
    FOR UPDATE TO authenticated
    USING (
        bucket_id = 'avatars' AND
        (storage.foldername(name))[1] = (SELECT auth.uid())::text
    )
    WITH CHECK (
        bucket_id = 'avatars' AND
        (storage.foldername(name))[1] = (SELECT auth.uid())::text
    );

CREATE POLICY "Avatars User Delete" ON storage.objects
    FOR DELETE TO authenticated
    USING (
        bucket_id = 'avatars' AND
        (storage.foldername(name))[1] = (SELECT auth.uid())::text
    );

NOTIFY pgrst, 'reload schema';
