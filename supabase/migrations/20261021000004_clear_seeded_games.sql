-- ============================================================================
-- Migration: 20261021000004_clear_seeded_games.sql
-- Description: Removes all hardcoded / seeded games so that the match calendar
--              is solely managed from the admin panel with zero fake seeds.
-- ============================================================================

-- Delete all seeded games
DELETE FROM public.games;
