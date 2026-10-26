-- Migration: 20261025000001_create_hall_of_fame_tables.sql
-- Description:
-- 1. Create hall_of_fame_jerseys, hall_of_fame_legends, and hall_of_fame_championships tables.
-- 2. Configure RLS with public read for published records and full admin CRUD access.
-- 3. Seed real historical data for Guaiqueríes de Margarita.

-- 1. Table: hall_of_fame_jerseys (Dorsales Retirados)
CREATE TABLE IF NOT EXISTS public.hall_of_fame_jerseys (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    jersey_number INT NOT NULL,
    player_name TEXT NOT NULL,
    nickname TEXT,
    position TEXT,
    years_active TEXT,
    titles_count INT DEFAULT 1 NOT NULL,
    titles_badge TEXT,
    highlight TEXT,
    description TEXT,
    badge_icon TEXT DEFAULT 'bi-star-fill' NOT NULL,
    order_index INT DEFAULT 0 NOT NULL,
    is_published BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT hall_of_fame_jerseys_pkey PRIMARY KEY (id)
);

-- 2. Table: hall_of_fame_legends (Leyendas Inmortales)
CREATE TABLE IF NOT EXISTS public.hall_of_fame_legends (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    name TEXT NOT NULL,
    nickname TEXT,
    role TEXT DEFAULT 'player' NOT NULL,
    category TEXT DEFAULT 'gold_era' NOT NULL,
    era TEXT,
    position TEXT,
    titles TEXT[] DEFAULT '{}' NOT NULL,
    achievements TEXT[] DEFAULT '{}' NOT NULL,
    bio TEXT,
    image_url TEXT,
    order_index INT DEFAULT 0 NOT NULL,
    is_published BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT hall_of_fame_legends_pkey PRIMARY KEY (id)
);

-- 3. Table: hall_of_fame_championships (Palmarés y Trofeos)
CREATE TABLE IF NOT EXISTS public.hall_of_fame_championships (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    year INT NOT NULL,
    tournament TEXT NOT NULL,
    runner_up TEXT,
    highlight TEXT,
    is_hexa BOOLEAN DEFAULT false NOT NULL,
    order_index INT DEFAULT 0 NOT NULL,
    is_published BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT hall_of_fame_championships_pkey PRIMARY KEY (id)
);

-- 4. Enable RLS
ALTER TABLE public.hall_of_fame_jerseys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hall_of_fame_legends ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hall_of_fame_championships ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies
-- Jerseys
CREATE POLICY "Jerseys Public Read" ON public.hall_of_fame_jerseys
    FOR SELECT TO public
    USING ((is_published = true));

CREATE POLICY "Jerseys Admin All" ON public.hall_of_fame_jerseys
    FOR ALL TO authenticated
    USING (is_admin_check());

-- Legends
CREATE POLICY "Legends Public Read" ON public.hall_of_fame_legends
    FOR SELECT TO public
    USING ((is_published = true));

CREATE POLICY "Legends Admin All" ON public.hall_of_fame_legends
    FOR ALL TO authenticated
    USING (is_admin_check());

-- Championships
CREATE POLICY "Championships Public Read" ON public.hall_of_fame_championships
    FOR SELECT TO public
    USING ((is_published = true));

CREATE POLICY "Championships Admin All" ON public.hall_of_fame_championships
    FOR ALL TO authenticated
    USING (is_admin_check());

-- 6. Grants
GRANT SELECT ON public.hall_of_fame_jerseys TO anon, authenticated;
GRANT SELECT ON public.hall_of_fame_legends TO anon, authenticated;
GRANT SELECT ON public.hall_of_fame_championships TO anon, authenticated;

GRANT ALL ON public.hall_of_fame_jerseys TO authenticated, service_role;
GRANT ALL ON public.hall_of_fame_legends TO authenticated, service_role;
GRANT ALL ON public.hall_of_fame_championships TO authenticated, service_role;

-- 7. Seed Real Data: Dorsales Retirados
INSERT INTO public.hall_of_fame_jerseys (jersey_number, player_name, nickname, position, years_active, titles_count, titles_badge, highlight, description, badge_icon, order_index, is_published)
SELECT 5, 'Luis Lairet', 'Pilar Fundacional', 'Alero', '1977 - 1982', 6, '6 títulos', 'Pieza vital en los 6 campeonatos consecutivos (1977-1982)', 'Uno de los pilares fundacionales de la franquicia y pieza vital en la histórica hazaña de los 6 campeonatos consecutivos entre 1977 y 1982.', 'bi-star-fill', 1, true
WHERE NOT EXISTS (SELECT 1 FROM public.hall_of_fame_jerseys WHERE jersey_number = 5);

INSERT INTO public.hall_of_fame_jerseys (jersey_number, player_name, nickname, position, years_active, titles_count, titles_badge, highlight, description, badge_icon, order_index, is_published)
SELECT 13, 'Cruz Lairet', 'Anotador Implacable', 'Ala-Pívot', '1977 - 1982', 6, '6 títulos', 'Referente histórico del hexacampeonato original de la Tribu', 'Hermano de Luis, anotador implacable y otro gran referente histórico del hexacampeonato original de la Tribu.', 'bi-fire', 2, true
WHERE NOT EXISTS (SELECT 1 FROM public.hall_of_fame_jerseys WHERE jersey_number = 13);

INSERT INTO public.hall_of_fame_jerseys (jersey_number, player_name, nickname, position, years_active, titles_count, titles_badge, highlight, description, badge_icon, order_index, is_published)
SELECT 12, 'Luis Sosa', 'Muralla Insular', 'Pívot', '1977 - 1985', 6, '6 títulos', 'Gran centro defensivo de la época dorada de los 70 y 80', 'El gran centro defensivo de la época dorada de los 70 y 80. Su número también está retirado por Marinos como muestra de su tremenda huella en el país.', 'bi-shield-fill-check', 3, true
WHERE NOT EXISTS (SELECT 1 FROM public.hall_of_fame_jerseys WHERE jersey_number = 12);

INSERT INTO public.hall_of_fame_jerseys (jersey_number, player_name, nickname, position, years_active, titles_count, titles_badge, highlight, description, badge_icon, order_index, is_published)
SELECT 8, 'Álexander Quiroz', 'Chocolate', 'Base', '1991 - 2009', 1, '2017', '19 temporadas, líder en asistencias y capitán en el título de 1997', 'Defendió la camiseta verde durante 19 temporadas (1991-2009). Líder en asistencias, velocidad y capitán en el título obtenido en la temporada de 1997. Retirado en 2017.', 'bi-lightning-charge-fill', 4, true
WHERE NOT EXISTS (SELECT 1 FROM public.hall_of_fame_jerseys WHERE jersey_number = 8);

INSERT INTO public.hall_of_fame_jerseys (jersey_number, player_name, nickname, position, years_active, titles_count, titles_badge, highlight, description, badge_icon, order_index, is_published)
SELECT 17, 'Richard Medina', 'Pundonor Verde', 'Ala-Pívot', '1990 - 2001', 1, '2017', '11 temporadas consecutivas y figura clave para alzar el título de 1997', 'Jugó 11 temporadas consecutivas en Margarita con un pundonor inolvidable. Fue una de las figuras criollas clave para alzar el campeonato de 1997. Retirado en 2017.', 'bi-bullseye', 5, true
WHERE NOT EXISTS (SELECT 1 FROM public.hall_of_fame_jerseys WHERE jersey_number = 17);

INSERT INTO public.hall_of_fame_jerseys (jersey_number, player_name, nickname, position, years_active, titles_count, titles_badge, highlight, description, badge_icon, order_index, is_published)
SELECT 11, 'Carl Herrera', 'Héroe de Portland', 'Ala-Pívot', '2003 - 2004', 1, '2017', 'Primer venezolano NBA y homenaje institucional en 2017', 'El histórico primer venezolano en la NBA y miembro de los "Héroes de Portland". Jugó con la Tribu en las temporadas 2003 y 2004; la directiva retiró su número en 2017 como homenaje institucional a su gigantesca leyenda.', 'bi-award-fill', 6, true
WHERE NOT EXISTS (SELECT 1 FROM public.hall_of_fame_jerseys WHERE jersey_number = 11);

-- 8. Seed Real Data: Leyendas Inmortales
INSERT INTO public.hall_of_fame_legends (name, nickname, role, category, era, position, titles, achievements, bio, image_url, order_index, is_published)
SELECT 'Sam Shepherd', 'El Mago de La Asunción', 'player', 'gold_era', '1977 - 1985', 'Base Armador', ARRAY['1977', '1978', '1979', '1980', '1981', '1982'], ARRAY['Base del Hexacampeonato', 'Líder histórico en asistencias', 'Nacionalizado venezolano'], 'El arquitecto ofensivo que hizo soñar a toda Margarita. Su visión de juego y control del ritmo marcaron la época más gloriosa del baloncesto en Venezuela.', '/images/historia/san-shepherd.png', 1, true
WHERE NOT EXISTS (SELECT 1 FROM public.hall_of_fame_legends WHERE name = 'Sam Shepherd');

INSERT INTO public.hall_of_fame_legends (name, nickname, role, category, era, position, titles, achievements, bio, image_url, order_index, is_published)
SELECT 'Alexander Quiroz', 'Palito', 'player', 'modern_era', '1995 - 2008', 'Base Armador', ARRAY['1997', '2007'], ARRAY['Bicampeón LPB', 'Capitán de la era moderna', 'Más de 500 juegos con la franquicia'], 'Orgullo de Nueva Esparta y referente insular. Guió a la Tribu a reconquistar la gloria en las finales de 1997 y 2007.', '/images/historia/alexander-quiroz.jpg', 2, true
WHERE NOT EXISTS (SELECT 1 FROM public.hall_of_fame_legends WHERE name = 'Alexander Quiroz');

INSERT INTO public.hall_of_fame_legends (name, nickname, role, category, era, position, titles, achievements, bio, image_url, order_index, is_published)
SELECT 'Askia Jones', 'El Francotirador', 'player', 'modern_era', '1996 - 2001', 'Escolta', ARRAY['1997'], ARRAY['MVP de la Final 1997', 'Récord de triples en postemporada', 'Ex-jugador NBA (Timberwolves)'], 'Anotador prolífico con puntería legendaria. Encestó triples decisivos para sellar la séptima estrella del equipo ante Cocodrilos.', '/images/historia/askia-jones.jpg', 3, true
WHERE NOT EXISTS (SELECT 1 FROM public.hall_of_fame_legends WHERE name = 'Askia Jones');

INSERT INTO public.hall_of_fame_legends (name, nickname, role, category, era, position, titles, achievements, bio, image_url, order_index, is_published)
SELECT 'Francisco Díez', 'Paco', 'coach', 'builder', '1977 - 1983', 'Director Técnico', ARRAY['1977', '1978', '1979', '1980', '1981', '1982'], ARRAY['Estratega del Hexacampeonato', 'Leyenda del banquillo'], 'El maestro táctico detrás de la dinastía más imponente en la historia del deporte venezolano. Forjó el carácter guerrero de la Tribu.', '/images/historia/francisco.jpg', 4, true
WHERE NOT EXISTS (SELECT 1 FROM public.hall_of_fame_legends WHERE name = 'Francisco Díez');

INSERT INTO public.hall_of_fame_legends (name, nickname, role, category, era, position, titles, achievements, bio, image_url, order_index, is_published)
SELECT 'Julio Toro', 'El Sabio de Puerto Rico', 'coach', 'builder', '1997', 'Director Técnico', ARRAY['1997'], ARRAY['Campeón LPB 1997', 'Entrenador mundialista'], 'Con su temperamento ganador y mística caribeña, llevó a Guaiqueríes a levantar el trofeo en 1997 terminando una sequía de quince años.', '/images/historia/julio-toro.jpg', 5, true
WHERE NOT EXISTS (SELECT 1 FROM public.hall_of_fame_legends WHERE name = 'Julio Toro');

INSERT INTO public.hall_of_fame_legends (name, nickname, role, category, era, position, titles, achievements, bio, image_url, order_index, is_published)
SELECT 'Heissler Guillent', 'El Sastre', 'player', 'modern_era', '2021 - 2023', 'Base Armador', ARRAY['2021 (Copa Superliga)'], ARRAY['MVP Copa Superliga 2021', 'Base de la Selección Nacional'], 'Comandó la conquista de la Copa Superliga 2021 con actuaciones magistrales en el Gimnasio Ciudad de La Asunción.', '/images/historia/heissler-guillent.jpg', 6, true
WHERE NOT EXISTS (SELECT 1 FROM public.hall_of_fame_legends WHERE name = 'Heissler Guillent');

-- 9. Seed Real Data: Campeonatos y Trofeos
INSERT INTO public.hall_of_fame_championships (year, tournament, runner_up, highlight, is_hexa, order_index, is_published)
SELECT 1977, 'Liga Especial (Li-Es)', 'A bravejos de Yaracuy', 'Primer campeonato de la franquicia y nacimiento de la Tribu Verde.', true, 1, true
WHERE NOT EXISTS (SELECT 1 FROM public.hall_of_fame_championships WHERE year = 1977);

INSERT INTO public.hall_of_fame_championships (year, tournament, runner_up, highlight, is_hexa, order_index, is_published)
SELECT 1978, 'Liga Especial (Li-Es)', 'Panteras del Táchira', 'Consolidación del dominio insular con barrida en la serie final.', true, 2, true
WHERE NOT EXISTS (SELECT 1 FROM public.hall_of_fame_championships WHERE year = 1978);

INSERT INTO public.hall_of_fame_championships (year, tournament, runner_up, highlight, is_hexa, order_index, is_published)
SELECT 1979, 'Liga Especial (Li-Es)', 'Legisladores de Carabobo', 'Tricampeonato consecutivo con La Asunción convertida en fortín inexpugnable.', true, 3, true
WHERE NOT EXISTS (SELECT 1 FROM public.hall_of_fame_championships WHERE year = 1979);

INSERT INTO public.hall_of_fame_championships (year, tournament, runner_up, highlight, is_hexa, order_index, is_published)
SELECT 1980, 'Liga Especial (Li-Es)', 'Retadores de Caracas', 'Cuarta estrella consecutiva de la mano de Lairet y Cheíto Ramos.', true, 4, true
WHERE NOT EXISTS (SELECT 1 FROM public.hall_of_fame_championships WHERE year = 1980);

INSERT INTO public.hall_of_fame_championships (year, tournament, runner_up, highlight, is_hexa, order_index, is_published)
SELECT 1981, 'Liga Especial (Li-Es)', 'Telefonistas de Caracas', 'El pentacampeonato que asombró a toda Sudamérica.', true, 5, true
WHERE NOT EXISTS (SELECT 1 FROM public.hall_of_fame_championships WHERE year = 1981);

INSERT INTO public.hall_of_fame_championships (year, tournament, runner_up, highlight, is_hexa, order_index, is_published)
SELECT 1982, 'Liga Especial (Li-Es)', 'Panteras de Lara', 'Récord histórico insuperable: ¡6 campeonatos consecutivos seguidos!', true, 6, true
WHERE NOT EXISTS (SELECT 1 FROM public.hall_of_fame_championships WHERE year = 1982);

INSERT INTO public.hall_of_fame_championships (year, tournament, runner_up, highlight, is_hexa, order_index, is_published)
SELECT 1997, 'Liga Profesional (LPB)', 'Cocodrilos de Caracas', 'Regreso a la gloria tras 15 años de la mano de Julio Toro y Askia Jones.', false, 7, true
WHERE NOT EXISTS (SELECT 1 FROM public.hall_of_fame_championships WHERE year = 1997);

INSERT INTO public.hall_of_fame_championships (year, tournament, runner_up, highlight, is_hexa, order_index, is_published)
SELECT 2007, 'Liga Profesional (LPB)', 'Cocodrilos de Caracas', 'Octava corona en una vibrante serie a 7 juegos decidida en El Fortín.', false, 8, true
WHERE NOT EXISTS (SELECT 1 FROM public.hall_of_fame_championships WHERE year = 2007);

INSERT INTO public.hall_of_fame_championships (year, tournament, runner_up, highlight, is_hexa, order_index, is_published)
SELECT 2021, 'Copa Superliga de Baloncesto', 'Trotamundos de Carabobo', 'Novena estrella nacional con Heissler Guillent alzando la copa en casa.', false, 9, true
WHERE NOT EXISTS (SELECT 1 FROM public.hall_of_fame_championships WHERE year = 2021);
