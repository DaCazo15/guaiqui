-- ============================================================================
-- Migration: 20261020000003_add_cover_url_and_sync_official_data.sql
-- Description:
-- 1. Adds cover_url to public.profiles for Facebook-style cover banners.
-- 2. Synchronizes official Sofascore games into public.games table.
-- 3. Synchronizes official fidelity products into public.products table.
-- ============================================================================

-- 1. Add cover_url to profiles if not exists
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS cover_url text;

-- 2. Seed official games from Sofascore
INSERT INTO public.games (id, opponent, location, game_date, is_home, status, our_score, opponent_score)
VALUES
('b1000000-0000-0000-0000-000000000001', 'Marinos de Anzoátegui', 'Gimnasio Ciudad de La Asunción', '2026-09-18T19:30:00Z', true, 'finished', 81, 78),
('b1000000-0000-0000-0000-000000000002', 'Marinos de Anzoátegui', 'Gimnasio Ciudad de La Asunción', '2026-09-16T19:30:00Z', true, 'finished', 75, 72),
('b1000000-0000-0000-0000-000000000003', 'Marinos de Anzoátegui', 'Gimnasio Luis Ramos, Puerto La Cruz', '2026-09-13T19:00:00Z', false, 'finished', 79, 84),
('b1000000-0000-0000-0000-000000000004', 'Marinos de Anzoátegui', 'Gimnasio Luis Ramos, Puerto La Cruz', '2026-09-11T19:00:00Z', false, 'finished', 74, 69),
('b1000000-0000-0000-0000-000000000005', 'Cocodrilos de Caracas', 'Gimnasio Ciudad de La Asunción', '2026-09-05T19:30:00Z', true, 'finished', 87, 82),
('b1000000-0000-0000-0000-000000000006', 'Marinos de Anzoátegui', 'Gimnasio Luis Ramos, Puerto La Cruz', '2026-10-24T19:30:00Z', false, 'scheduled', 0, 0),
('b1000000-0000-0000-0000-000000000007', 'Gladiadores de Anzoátegui', 'Gimnasio Ciudad de La Asunción', '2026-10-28T19:30:00Z', true, 'scheduled', 0, 0),
('b1000000-0000-0000-0000-000000000008', 'Trotamundos de Carabobo', 'Forum de Valencia, Valencia', '2026-11-04T19:00:00Z', false, 'scheduled', 0, 0)
ON CONFLICT (id) DO UPDATE SET
    opponent = EXCLUDED.opponent,
    location = EXCLUDED.location,
    game_date = EXCLUDED.game_date,
    is_home = EXCLUDED.is_home,
    status = EXCLUDED.status,
    our_score = EXCLUDED.our_score,
    opponent_score = EXCLUDED.opponent_score;

-- 3. Seed official club products into public.products
INSERT INTO public.products (id, name, description, category, cost_pearls, stock, variants, active, valid_from, images)
VALUES
('c1000000-0000-0000-0000-000000000001', 'Camiseta Oficial 2026', 'Camiseta oficial de juego de Guaiqueríes de Margarita edición SPB 2026.', 'physical', 4500, 15, '{"tallas": ["S", "M", "L", "XL"]}'::jsonb, true, now(), ARRAY['/products/camiseta-2026.webp']),
('c1000000-0000-0000-0000-000000000002', 'Bandana Verde Guaiquerí Original', 'Bandana emblemática de la Tribu insular confeccionada en microfibra transpirable.', 'physical', 1200, 40, '{"color": ["Verde Insular"]}'::jsonb, true, now(), ARRAY['/products/bandana-verde.webp']),
('c1000000-0000-0000-0000-000000000003', 'Gorra Oficial de la Tribu', 'Gorra snapback con bordado 3D del escudo de Guaiqueríes de Margarita.', 'physical', 1800, 25, '{"ajuste": ["Snapback"]}'::jsonb, true, now(), ARRAY['/products/gorra-tribu.webp']),
('c1000000-0000-0000-0000-000000000004', 'Balón Oficial Autografiado SPB', 'Balón oficial Molten SPB autografiado por la plantilla completa de Guaiqueríes.', 'physical', 8500, 5, '{}'::jsonb, true, now(), ARRAY['/products/balon-autografiado.webp']),
('c1000000-0000-0000-0000-000000000005', 'Saludo en Video Personalizado de Jugador', 'Video exclusivo personalizado y dedicado por el capitán o jugador de tu preferencia.', 'experience', 2800, 10, '{}'::jsonb, true, now(), ARRAY['/products/saludo-video.webp']),
('c1000000-0000-0000-0000-000000000006', 'Entrada Preferencial Abono 1 Partido', 'Acceso preferencial para 1 partido oficial en el Gimnasio Ciudad de La Asunción.', 'experience', 3500, 20, '{}'::jsonb, true, now(), ARRAY['/products/entrada-preferencial.webp'])
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    category = EXCLUDED.category,
    cost_pearls = EXCLUDED.cost_pearls,
    stock = EXCLUDED.stock,
    variants = EXCLUDED.variants,
    active = EXCLUDED.active,
    images = EXCLUDED.images;
