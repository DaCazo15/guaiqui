-- Migration: 20261009000020_grant_all_rpcs.sql
-- Description: Grant execute permissions on all public RPC functions to authenticated and anon roles

GRANT USAGE ON SCHEMA public TO anon, authenticated;

-- Grant EXECUTE on specific RPC functions used by Web and Staff/Admin apps
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO anon;

-- Explicitly ensure public RPCs have proper GRANT EXECUTE
GRANT EXECUTE ON FUNCTION public.home_summary() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.wallet_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.wallet_ledger(INT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_leaderboard(INT, INT, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.staff_redemption_queue(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.parse_instagram_shortcode(TEXT) TO authenticated, anon;

-- Admin & Staff helper RPCs
GRANT EXECUTE ON FUNCTION public.admin_upsert_product(JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_trivia(JSONB, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_publish_trivia(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_duplicate_trivia(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_game(JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_game(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.adjust_stock(UUID, INT, TEXT) TO authenticated;
