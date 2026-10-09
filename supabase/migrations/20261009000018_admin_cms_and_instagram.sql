-- Migration: 20261009000018_admin_cms_and_instagram.sql
-- Description: Instagram Feed Posts, League Standings, Trivia Segmentation, and Staff Audit Location Enhancements

-- 1. Instagram Posts Table (Max 8 Mosaic items)
CREATE TABLE IF NOT EXISTS public.instagram_posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_url TEXT NOT NULL,
    shortcode TEXT,
    image_url TEXT,
    caption TEXT,
    order_index INT NOT NULL DEFAULT 0,
    is_published BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. League Standings Table (Tabla de Posiciones SPB)
CREATE TABLE IF NOT EXISTS public.standings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_name TEXT NOT NULL,
    logo_url TEXT,
    games_played INT NOT NULL DEFAULT 0,
    wins INT NOT NULL DEFAULT 0,
    losses INT NOT NULL DEFAULT 0,
    points INT NOT NULL DEFAULT 0,
    order_index INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Add target_segment_id to Trivias table if not exists
ALTER TABLE public.trivias ADD COLUMN IF NOT EXISTS target_segment_id UUID REFERENCES public.segments(id) ON DELETE SET NULL;

-- Enable RLS
ALTER TABLE public.instagram_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.standings ENABLE ROW LEVEL SECURITY;

-- Public Read Policies
DROP POLICY IF EXISTS "Instagram Public Read" ON public.instagram_posts;
CREATE POLICY "Instagram Public Read" ON public.instagram_posts FOR SELECT USING (is_published = true);

DROP POLICY IF EXISTS "Standings Public Read" ON public.standings;
CREATE POLICY "Standings Public Read" ON public.standings FOR SELECT USING (true);

-- Admin Management Policies
DROP POLICY IF EXISTS "Instagram Admin All" ON public.instagram_posts;
CREATE POLICY "Instagram Admin All" ON public.instagram_posts FOR ALL USING (public.is_admin_check());

DROP POLICY IF EXISTS "Standings Admin All" ON public.standings;
CREATE POLICY "Standings Admin All" ON public.standings FOR ALL USING (public.is_admin_check());

-- RPC Helper: Parse Instagram Shortcode from URL
CREATE OR REPLACE FUNCTION public.parse_instagram_shortcode(p_url TEXT)
RETURNS TEXT AS $$
DECLARE
    v_parts TEXT[];
    v_idx INT;
BEGIN
    IF p_url IS NULL THEN RETURN NULL; END IF;
    IF p_url LIKE '%/p/%' THEN
        v_parts := string_to_array(p_url, '/p/');
        IF array_length(v_parts, 1) >= 2 THEN
            RETURN split_part(v_parts[2], '/', 1);
        END IF;
    ELSIF p_url LIKE '%/reel/%' THEN
        v_parts := string_to_array(p_url, '/reel/');
        IF array_length(v_parts, 1) >= 2 THEN
            RETURN split_part(v_parts[2], '/', 1);
        END IF;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Seed default initial Standings & Instagram sample data
INSERT INTO public.standings (team_name, games_played, wins, losses, points, order_index)
VALUES 
    ('Guaiqueríes de Margarita', 12, 10, 2, 22, 1),
    ('Gaiteros del Zulia', 12, 8, 4, 20, 2),
    ('Trotamundos de Carabobo', 12, 7, 5, 19, 3),
    ('Marinos de Anzoátegui', 12, 6, 6, 18, 4),
    ('Cocodrilos de Caracas', 12, 5, 7, 17, 5)
ON CONFLICT DO NOTHING;

INSERT INTO public.instagram_posts (post_url, shortcode, image_url, caption, order_index)
VALUES 
    ('https://www.instagram.com/p/C12345/', 'C12345', 'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=600&auto=format&fit=crop', '¡Victoria de la Tribu Verde en la Asunción! 🏀🔥', 1),
    ('https://www.instagram.com/p/C67890/', 'C67890', 'https://images.unsplash.com/photo-1519861531473-9200262188bf?w=600&auto=format&fit=crop', 'Entrenamiento matutino con la plantilla oficial 💪', 2)
ON CONFLICT DO NOTHING;
