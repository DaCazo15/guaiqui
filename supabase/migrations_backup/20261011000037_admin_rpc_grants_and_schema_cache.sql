-- Migration: 20261011000037_admin_rpc_grants_and_schema_cache.sql
-- Description: Restores missing grants on admin/analytics RPCs, exposes CMS & settings tables to Data API, and reloads PostgREST schema cache.

-- 1. Expose settings tables to Data API (anon / authenticated) with strict RLS
GRANT SELECT ON TABLE public.landing_settings TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.landing_settings TO authenticated, service_role;

GRANT SELECT ON TABLE public.birthday_settings TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.birthday_settings TO authenticated, service_role;

GRANT SELECT ON TABLE public.economy_settings TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.economy_settings TO authenticated, service_role;

GRANT SELECT ON TABLE public.ad_reward_tiers TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.ad_reward_tiers TO authenticated, service_role;

-- 2. Ensure scan_events columns and table grants
ALTER TABLE public.scan_events ADD COLUMN IF NOT EXISTS latitude NUMERIC;
ALTER TABLE public.scan_events ADD COLUMN IF NOT EXISTS longitude NUMERIC;
GRANT SELECT, INSERT ON TABLE public.scan_events TO authenticated, service_role;

-- 3. Restore EXECUTE permissions on Analytics RPC functions
GRANT EXECUTE ON FUNCTION public.analytics_overview(TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.analytics_engagement_hours(TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.analytics_funnel(TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.analytics_economy() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.analytics_trivias(TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.analytics_products(TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.analytics_active_users(TIMESTAMPTZ, TIMESTAMPTZ, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.analytics_top_fans(INT, TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.analytics_demographics() TO authenticated, service_role;

-- 4. Restore EXECUTE permissions on Admin Management & Search RPC functions
GRANT EXECUTE ON FUNCTION public.admin_list_fans(TEXT, INT, INT, UUID, INT, user_status, TEXT, INT, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_risk_queue(BOOLEAN) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.audit_search(UUID, TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, INT, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.staff_redemption_queue(TEXT, TEXT, TIMESTAMPTZ, INT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_update_economy_settings(JSONB) TO authenticated, service_role;

-- 5. Restore EXECUTE permissions on Rewarded Ads Admin RPC functions
GRANT EXECUTE ON FUNCTION public.admin_update_ads_settings(JSONB) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.analytics_ads(TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.import_ad_report(DATE, INT, TEXT) TO authenticated, service_role;

-- 6. Enforce brand guidelines: Remove any emoji in birthday settings default message
UPDATE public.birthday_settings 
SET message = REPLACE(message, '🏀', '') 
WHERE message LIKE '%🏀%';

-- 7. Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
