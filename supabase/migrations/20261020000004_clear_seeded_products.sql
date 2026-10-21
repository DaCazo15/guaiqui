-- ============================================================================
-- Migration: 20261020000004_clear_seeded_products.sql
-- Description: Removes seeded products from public.products so the catalog reflects
--              only real products created by staff or administrators.
-- ============================================================================

DELETE FROM public.products
WHERE id IN (
  'c1000000-0000-0000-0000-000000000001',
  'c1000000-0000-0000-0000-000000000002',
  'c1000000-0000-0000-0000-000000000003',
  'c1000000-0000-0000-0000-000000000004',
  'c1000000-0000-0000-0000-000000000005',
  'c1000000-0000-0000-0000-000000000006'
);
