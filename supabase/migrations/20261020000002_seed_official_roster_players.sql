-- ============================================================================
-- Migration: 20261020000002_seed_official_roster_players.sql
-- Description: Seeds the official Guaiqueríes de Margarita roster (synchronized with Sofascore)
--              into public.players so that fans can select their favorite player in profile and registration.
-- ============================================================================

INSERT INTO public.players (id, name, jersey_number, position, height, age, nationality, bio, is_active, is_star)
VALUES
('11111111-1111-1111-1111-111111111111', 'Heissler Guillent', 10, 'Base (PG)', '1.86 m', 37, 'Venezuela', 'El Sastre. Director de orquesta legendario del baloncesto venezolano y conductor de la tribu.', true, true),
('22222222-2222-2222-2222-222222222222', 'Windi Graterol', 14, 'Pívot (C)', '2.05 m', 38, 'Venezuela', 'Muralla defensiva en la pintura y campeón insular de la SPB.', true, true),
('33333333-3333-3333-3333-333333333333', 'Pedro Chourio', 7, 'Escolta / Alero (SG/SF)', '1.86 m', 34, 'Venezuela', 'Capitán y referente perimetral de Guaiqueríes y la selección nacional de Venezuela.', true, true),
('44444444-4444-4444-4444-444444444444', 'Juan Guerrero', 2, 'Ala-Pívot (PF)', '2.05 m', 31, 'República Dominicana', 'Potencia ofensiva y reboteadora en la pintura para Guaiqueríes.', true, true),
('55555555-5555-5555-5555-555555555555', 'Tavario Miller', 0, 'Pívot (C)', '2.03 m', 30, 'Bahamas', 'Pívot atlético con gran capacidad de bloqueo y finalización sobre el aro.', true, true),
('66666666-6666-6666-6666-666666666666', 'Nahziah Carter', 1, 'Alero (SF)', '1.98 m', 25, 'Estados Unidos', 'Alero estadounidense de gran agilidad y capacidad de tiro perimetral.', true, false),
('77777777-7777-7777-7777-777777777777', 'Francisco Centeno', 12, 'Ala-Pívot (PF)', '2.03 m', 39, 'Venezuela', 'Veterano guerrero del tabloncillo margariteño con amplia trayectoria en la liga.', true, false),
('88888888-8888-8888-8888-888888888888', 'Tulio Cobos', 6, 'Ala-Pívot (PF)', '1.98 m', 38, 'Venezuela', 'Fuerza física y experiencia en los tableros.', true, false),
('99999999-9999-9999-9999-999999999999', 'Gary McGhee', 11, 'Pívot (C)', '2.11 m', 36, 'Estados Unidos', 'Centro dominante con experiencia internacional en ligas de Europa y América.', true, false),
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'José Sojo', 5, 'Base (PG)', '1.82 m', 28, 'Venezuela', 'Velocidad, visión de cancha y conducción táctica de la segunda unidad.', true, false),
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Kender Urbina', 3, 'Base (PG)', '1.80 m', 20, 'Venezuela', 'Joven talento con tremenda explosividad y descaro ofensivo.', true, false),
('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Gendry Correa', 8, 'Escolta (SG)', '1.91 m', 28, 'Venezuela', 'Especialista perimetral y gran defensor perimetral de la tribu.', true, false),
('dddddddd-dddd-dddd-dddd-dddddddddddd', 'Jose Bracho', 9, 'Base / Escolta (PG/SG)', '1.90 m', 26, 'Venezuela', 'Versatilidad ofensiva y control de ritmo en la cancha.', true, false),
('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'Hector Diaz', 13, 'Alero (SF)', '1.92 m', 32, 'Venezuela', 'Alero sólido con buen tiro de media y larga distancia.', true, false),
('ffffffff-ffff-ffff-ffff-ffffffffffff', 'Eliezer Montano', 23, 'Pívot (C)', '2.06 m', 33, 'Venezuela', 'Envergadura y protección del aro en el poste bajo.', true, false),
('a1000000-0000-0000-0000-000000000015', 'Ezequiel Garcia', 15, 'Alero (SF)', '1.95 m', 19, 'Venezuela', 'Promesa insular de desarrollo de la cantera de Guaiqueríes.', true, false),
('a1000000-0000-0000-0000-000000000004', 'Jhon Brito', 4, 'Base (PG)', '1.85 m', 23, 'Venezuela', 'Base rápido y dinámico con gran presión de balón.', true, false),
('a1000000-0000-0000-0000-000000000017', 'Valentine Garcia', 17, 'Alero (SF)', '1.93 m', 22, 'Venezuela', 'Intensidad física y versatilidad en los aleros.', true, false),
('a1000000-0000-0000-0000-000000000024', 'Luis Valera', 24, 'Ala-Pívot (PF)', '2.02 m', 36, 'Venezuela', 'Experiencia y tiro exterior desde la posición de ala-pívot.', true, false),
('a1000000-0000-0000-0000-000000000016', 'Jerime Anderson', 16, 'Base (PG)', '1.88 m', 35, 'Estados Unidos', 'Base armador internacional con gran capacidad de creación de juego.', true, false),
('a1000000-0000-0000-0000-000000000025', 'Miguel Ruiz', 25, 'Ala-Pívot / Pívot (PF/C)', '2.02 m', 34, 'Venezuela', 'El rey del rebote. Guerrero incansable bajo los aros y miembro de la Selección Nacional.', true, true),
('a1000000-0000-0000-0000-000000000033', 'Ali Mata', 33, 'Pívot (C)', '2.05 m', 27, 'Venezuela', 'Pívot de relevo con presencia física en el tablero.', true, false)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    jersey_number = EXCLUDED.jersey_number,
    position = EXCLUDED.position,
    height = EXCLUDED.height,
    age = EXCLUDED.age,
    nationality = EXCLUDED.nationality,
    bio = EXCLUDED.bio,
    is_active = EXCLUDED.is_active,
    is_star = EXCLUDED.is_star;
