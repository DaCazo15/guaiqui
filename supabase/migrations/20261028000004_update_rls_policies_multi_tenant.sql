-- ============================================================================
-- Migration: 20261028000004_update_rls_policies_multi_tenant.sql
-- Description: Multi-tenant Step 5:
--              Updates Row Level Security (RLS) policies across team tables
--              to enforce tenant isolation via is_team_staff(auth.uid(), team_id)
--              and is_team_admin(auth.uid(), team_id), while preserving platform
--              administrator global access.
-- ============================================================================

-- 1. Staff Members Management Policy
DROP POLICY IF EXISTS "Admin manages staff members" ON public.staff_members;
CREATE POLICY "staff_members_manage" ON public.staff_members
    FOR ALL TO authenticated
    USING (
        public.is_admin_check() OR 
        (team_id IS NOT NULL AND public.is_team_admin((SELECT auth.uid()), team_id))
    )
    WITH CHECK (
        public.is_admin_check() OR 
        (team_id IS NOT NULL AND public.is_team_admin((SELECT auth.uid()), team_id))
    );

-- 2. Products Policy
DROP POLICY IF EXISTS "Admin manages products" ON public.products;
CREATE POLICY "products_team_staff_manage" ON public.products
    FOR ALL TO authenticated
    USING (public.is_team_staff((SELECT auth.uid()), team_id))
    WITH CHECK (public.is_team_staff((SELECT auth.uid()), team_id));

-- 3. Trivias Policy
DROP POLICY IF EXISTS "Admin manages trivias" ON public.trivias;
CREATE POLICY "trivias_team_staff_manage" ON public.trivias
    FOR ALL TO authenticated
    USING (public.is_team_staff((SELECT auth.uid()), team_id))
    WITH CHECK (public.is_team_staff((SELECT auth.uid()), team_id));

-- 4. Games Policy
DROP POLICY IF EXISTS "Games Admin All" ON public.games;
CREATE POLICY "games_team_staff_manage" ON public.games
    FOR ALL TO authenticated
    USING (public.is_team_staff((SELECT auth.uid()), team_id))
    WITH CHECK (public.is_team_staff((SELECT auth.uid()), team_id));

-- 5. Players Policy
DROP POLICY IF EXISTS "Admin manages players" ON public.players;
CREATE POLICY "players_team_staff_manage" ON public.players
    FOR ALL TO authenticated
    USING (public.is_team_staff((SELECT auth.uid()), team_id))
    WITH CHECK (public.is_team_staff((SELECT auth.uid()), team_id));

-- 6. Redemptions Staff Policy
DROP POLICY IF EXISTS "Staff manages redemptions" ON public.redemptions;
CREATE POLICY "redemptions_team_staff_manage" ON public.redemptions
    FOR ALL TO authenticated
    USING (public.is_team_staff((SELECT auth.uid()), team_id))
    WITH CHECK (public.is_team_staff((SELECT auth.uid()), team_id));

-- 7. Scan Events Policy
DROP POLICY IF EXISTS "Staff logs scan events" ON public.scan_events;
CREATE POLICY "scan_events_team_staff_manage" ON public.scan_events
    FOR ALL TO authenticated
    USING (public.is_team_staff((SELECT auth.uid()), team_id))
    WITH CHECK (public.is_team_staff((SELECT auth.uid()), team_id));

-- 8. Segments Policy
DROP POLICY IF EXISTS "Admin manages segments" ON public.segments;
CREATE POLICY "segments_team_staff_manage" ON public.segments
    FOR ALL TO authenticated
    USING (public.is_team_staff((SELECT auth.uid()), team_id))
    WITH CHECK (public.is_team_staff((SELECT auth.uid()), team_id));

-- 9. Landing & CMS Tables Policies (Updating Admin policies to allow Team Staff)
DO $$
DECLARE
    v_cms_tables TEXT[] := ARRAY[
        'site_announcements', 'carousel_slides', 'hero_carousel_slides',
        'history_milestones', 'site_team_members', 'faqs', 'site_stats',
        'social_links', 'landing_settings', 'landing_ctas', 'birthday_settings',
        'login_modal_slides', 'standings', 'instagram_posts', 'notification_templates',
        'hall_of_fame_championships', 'hall_of_fame_jerseys', 'hall_of_fame_legends',
        'guess_player_challenges', 'trivia_polls', 'over_under_predictions',
        'mystery_play_challenges', 'score_predictions', 'flash_trivia_challenges',
        'progressive_clue_challenges'
    ];
    v_tbl TEXT;
    v_pol RECORD;
BEGIN
    FOREACH v_tbl IN ARRAY v_cms_tables LOOP
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = v_tbl) THEN
            -- Drop existing admin policy if found
            FOR v_pol IN (
                SELECT policyname FROM pg_policies 
                WHERE schemaname = 'public' AND tablename = v_tbl AND policyname ILIKE '%admin%'
            ) LOOP
                EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', v_pol.policyname, v_tbl);
            END LOOP;

            -- Create tenant-scoped staff management policy
            EXECUTE format(
                'CREATE POLICY %I ON public.%I FOR ALL TO authenticated USING (public.is_team_staff((SELECT auth.uid()), team_id)) WITH CHECK (public.is_team_staff((SELECT auth.uid()), team_id))',
                v_tbl || '_team_staff_manage',
                v_tbl
            );
        END IF;
    END LOOP;
END$$;
