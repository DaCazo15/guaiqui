-- ============================================================================
-- Migration: 20261021000003_clear_seeded_players.sql
-- Description: Removes all hardcoded / seeded players so the official roster
--              is solely managed from the admin panel with zero fake seeds.
-- ============================================================================

-- Delete all seeded players (foreign keys in profiles set to null automatically via ON DELETE SET NULL)
DELETE FROM public.players;
