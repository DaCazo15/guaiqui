-- Seed Data for Local Development & Testing

-- 1. Initial Economy Settings
INSERT INTO economy_settings (daily_pearl_cap, weekly_pearl_cap, streak_bonus_config)
VALUES (1000, 5000, '{"streak_3_days": 100, "streak_7_days": 300}'::jsonb);

-- 2. Players
INSERT INTO players (id, name, jersey_number, position, height, age, nationality, is_active, is_star) VALUES
('11111111-1111-1111-1111-111111111111', 'Heissler Guillent', 10, 'Base (PG)', '1.86 m', 37, 'Venezuela', true, true),
('22222222-2222-2222-2222-222222222222', 'Windi Graterol', 14, 'Pívot (C)', '2.05 m', 38, 'Venezuela', true, true),
('33333333-3333-3333-3333-333333333333', 'Pedro Chourio', 7, 'Escolta (SG)', '1.86 m', 34, 'Venezuela', true, false),
('44444444-4444-4444-4444-444444444444', 'Edgar Martínez', 21, 'Alero (SF)', '1.93 m', 27, 'Venezuela', true, false);

-- 3. Games
INSERT INTO games (opponent, location, game_date, is_home, status) VALUES
('Marinos de Anzoátegui', 'Gimnasio Ciudad de La Asunción', NOW() + INTERVAL '2 hours', true, 'scheduled'),
('Trotamundos de Carabobo', 'Gimnasio Ciudad de La Asunción', NOW() + INTERVAL '2 days', true, 'scheduled'),
('Cocodrilos de Caracas', 'Gimnasio José Beracasa, Caracas', NOW() + INTERVAL '5 days', false, 'scheduled');

-- 4. Published Trivia & Questions
INSERT INTO trivias (id, title, description, status, starts_at, ends_at, time_limit_seconds, reward_rules, max_attempts) VALUES
('a1111111-1111-1111-1111-111111111111', 'Trivia del Clásico Oriental', 'Demuestra tus conocimientos en el duelo contra Marinos', 'published', NOW() - INTERVAL '1 hour', NOW() + INTERVAL '24 hours', 60, '{"per_correct_pearls": 50, "perfect_score_bonus": 100}'::jsonb, 1);

INSERT INTO trivia_questions (id, trivia_id, question_text, points, order_index) VALUES
('c1111111-1111-1111-1111-111111111111', 'a1111111-1111-1111-1111-111111111111', '¿En qué año fue fundado el equipo Guaiqueríes de Margarita?', 50, 1),
('c2222222-2222-2222-2222-222222222222', 'a1111111-1111-1111-1111-111111111111', '¿Cuántos títulos de liga ha conquistado la tribu verde?', 50, 2);

INSERT INTO trivia_options (question_id, option_text, is_correct) VALUES
('c1111111-1111-1111-1111-111111111111', '1977', true),
('c1111111-1111-1111-1111-111111111111', '1985', false),
('c1111111-1111-1111-1111-111111111111', '1991', false),
('c2222222-2222-2222-2222-222222222222', '9 Títulos', true),
('c2222222-2222-2222-2222-222222222222', '5 Títulos', false),
('c2222222-2222-2222-2222-222222222222', '12 Títulos', false);

-- 5. Products Catalog
INSERT INTO products (id, name, description, category, cost_pearls, stock, active) VALUES
('b1111111-1111-1111-1111-111111111111', 'Camiseta Oficial Guaiqueríes 2026', 'Camiseta oficial verde de la tribu insular', 'physical', 4500, 15, true),
('b2222222-2222-2222-2222-222222222222', 'Bandana Verde Guaiquerí Original', 'Bandana tradicional con diseño exclusivo', 'physical', 1200, 40, true),
('b3333333-3333-3333-3333-333333333333', 'Pase VIP Entrenamiento Abierto', 'Entrada preferencial para conocer a la plantilla', 'experience', 2800, 8, true);
