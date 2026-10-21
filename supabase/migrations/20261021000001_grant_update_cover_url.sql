-- ============================================================================
-- Migration: 20261021000001_grant_update_cover_url.sql
-- Description: Grants UPDATE privilege on column cover_url of public.profiles
--              to the authenticated role.
-- ============================================================================

GRANT UPDATE (cover_url) ON public.profiles TO authenticated;
