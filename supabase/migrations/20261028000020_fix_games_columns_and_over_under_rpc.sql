-- ============================================================================
-- Migration: 20261028000020_fix_games_columns_and_over_under_rpc.sql
-- Description:
--   1. Add opponent_name generated column and opponent_logo_url to games table
--      to support score_predictions, mystery_plays, and over_under RPCs.
--   2. Add alias RPC get_active_over_under_challenges() mapping to
--      get_active_over_under_predictions().
--   3. Set local logo_url '/logo.png' for guaiqueries team.
-- ============================================================================

-- 1. Ensure columns exist on games
ALTER TABLE public.games ADD COLUMN IF NOT EXISTS opponent_name TEXT GENERATED ALWAYS AS (opponent) STORED;
ALTER TABLE public.games ADD COLUMN IF NOT EXISTS opponent_logo_url TEXT;

-- 2. Update default guaiqueries logo_url to /logo.png
UPDATE public.teams 
SET logo_url = '/logo.png' 
WHERE slug = 'guaiqueries' AND logo_url LIKE '%raw.githubusercontent.com%';

-- 3. Create alias RPC for get_active_over_under_challenges
CREATE OR REPLACE FUNCTION public.get_active_over_under_challenges()
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $$
  SELECT public.get_active_over_under_predictions();
$$;

REVOKE ALL ON FUNCTION public.get_active_over_under_challenges() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_active_over_under_challenges() TO authenticated;
