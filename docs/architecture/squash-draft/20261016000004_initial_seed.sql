-- ============================================================================
-- Migration: 20261016000004_initial_seed.sql
-- Description: Baseline system configuration seed data (Economy, Risk,
--              Landing settings, Birthday, Policies, Standings, Ad Tiers).
-- ============================================================================

-- Seed for economy_settings
INSERT INTO public.economy_settings (id, block_size, created_at, ads_enabled, ad_min_seconds, daily_ad_views, daily_pearl_cap, weekly_pearl_cap, streak_bonus_config, ad_min_account_age_days, ad_min_trivias_completed)
VALUES ('3c1b2b75-b534-4109-a16f-aa23790281d2', 10, '2026-10-11T22:32:58.733827+00:00', true, 6, 50, 500, 2500, '{"streak_3_days":100,"streak_7_days":300}'::jsonb, 0, 0)
ON CONFLICT DO NOTHING;

-- Seed for risk_settings
INSERT INTO public.risk_settings (id, key, value, updated_at, description)
VALUES ('789f7b52-1177-4588-9e77-7ffd00f8bc79', 'timing_implausible_seconds', 3, '2026-10-11T19:00:41.188267+00:00', 'Umbral mínimo de tiempo de trivia (segundos)')
ON CONFLICT DO NOTHING;

INSERT INTO public.risk_settings (id, key, value, updated_at, description)
VALUES ('b9a09682-2091-47b6-aeb4-067aba88580b', 'high_value_product_pearls', 3000, '2026-10-11T19:00:41.188267+00:00', 'Umbral de costo para exigir fricción proporcional')
ON CONFLICT DO NOTHING;

INSERT INTO public.risk_settings (id, key, value, updated_at, description)
VALUES ('5ecb3d7e-45ce-4510-bbed-85dde6a8aae5', 'min_account_age_days', 7, '2026-10-11T19:00:41.188267+00:00', 'Antigüedad mínima de cuenta para canjes de alto valor')
ON CONFLICT DO NOTHING;

INSERT INTO public.risk_settings (id, key, value, updated_at, description)
VALUES ('b63acadb-06b2-4829-8e66-b01a9dcb512f', 'min_trivias_completed', 3, '2026-10-11T19:00:41.188267+00:00', 'Mínimo de trivias para canjes de alto valor')
ON CONFLICT DO NOTHING;

-- Seed for birthday_settings
INSERT INTO public.birthday_settings (id, title, enabled, message, image_url, send_hour, grace_days, updated_at, bonus_pearls)
VALUES (1, '¡Feliz Cumpleaños, Guaiquerí!', true, '¡En nombre de todos los que formamos parte de los **Guaiqueríes de Margarita**, te deseamos un feliz cumpleaños, {nombre}!\n\nGracias por tu pasión y por ser parte fundamental de nuestra tribu.', NULL, 9, 3, '2026-10-11T19:55:59.946331+00:00', 0)
ON CONFLICT DO NOTHING;

-- Seed for landing_settings
INSERT INTO public.landing_settings (id, hero_title, updated_at, theme_color, hero_subtitle, cta_primary_url, cta_primary_text, cta_secondary_url, dark_mode_enabled, cta_secondary_text)
VALUES (1, 'La Tribu Insular Vive en la Fan Zone Oficial', '2026-10-11T19:02:48.260989+00:00', '#059669', 'Gana perlitas exclusivas respondiendo trivias, participando en dinámicas de cancha y canjeándolas por recompensas reales de Guaiqueríes.', '/register', 'Únete a la Tribu Gratis', '#premios', true, 'Explorar Premios')
ON CONFLICT DO NOTHING;

-- Seed for ad_reward_tiers
INSERT INTO public.ad_reward_tiers (pearls, updated_at, block_number)
VALUES (5, '2026-10-12T19:37:36.569652+00:00', 1)
ON CONFLICT DO NOTHING;

INSERT INTO public.ad_reward_tiers (pearls, updated_at, block_number)
VALUES (10, '2026-10-12T19:37:36.569652+00:00', 2)
ON CONFLICT DO NOTHING;

INSERT INTO public.ad_reward_tiers (pearls, updated_at, block_number)
VALUES (15, '2026-10-12T19:37:36.569652+00:00', 3)
ON CONFLICT DO NOTHING;

INSERT INTO public.ad_reward_tiers (pearls, updated_at, block_number)
VALUES (20, '2026-10-12T19:37:36.569652+00:00', 4)
ON CONFLICT DO NOTHING;

INSERT INTO public.ad_reward_tiers (pearls, updated_at, block_number)
VALUES (25, '2026-10-12T19:37:36.569652+00:00', 5)
ON CONFLICT DO NOTHING;

-- Seed for policy_documents
INSERT INTO public.policy_documents (id, slug, version, is_active, created_at, updated_at, published_at, content_markdown)
VALUES ('f883c0b2-e382-43f9-9caa-d43628036039', 'terminos', 'v1.0', true, '2026-10-11T19:02:47.159609+00:00', '2026-10-11T19:58:09.129032+00:00', '2026-10-11T19:02:47.159609+00:00', '# Términos y Condiciones Oficiales\n\nBienvenido a Guaiqueríes Fan Zone. Al registrarte y utilizar nuestra plataforma aceptas las normas aquí descritas.')
ON CONFLICT DO NOTHING;

INSERT INTO public.policy_documents (id, slug, version, is_active, created_at, updated_at, published_at, content_markdown)
VALUES ('ebde7243-fd0e-43d7-a9c3-ff4a595e5682', 'perlitas', 'v1.0', true, '2026-10-11T19:02:47.159609+00:00', '2026-10-11T19:58:09.129032+00:00', '2026-10-11T19:02:47.159609+00:00', '# Reglas del Programa de Perlitas\n\nLas perlitas son puntos de fidelidad virtuales sin valor monetario real. Se ganan jugando trivias y se canjean por recompensas.')
ON CONFLICT DO NOTHING;

INSERT INTO public.policy_documents (id, slug, version, is_active, created_at, updated_at, published_at, content_markdown)
VALUES ('b792a519-410b-4c39-aa9e-6dcbf6551876', 'canjes', 'v1.0', true, '2026-10-11T19:02:47.159609+00:00', '2026-10-11T19:58:09.129032+00:00', '2026-10-11T19:02:47.159609+00:00', '# Políticas de Canje de Premios\n\nLos canjes se realizan mediante códigos QR presentados en taquilla. Los productos no tienen devolución monetaria.')
ON CONFLICT DO NOTHING;

INSERT INTO public.policy_documents (id, slug, version, is_active, created_at, updated_at, published_at, content_markdown)
VALUES ('2508a77b-b1df-456f-80f7-db6e33cfcef1', 'privacidad', 'v1.0', false, '2026-10-11T19:02:47.159609+00:00', '2026-10-11T19:58:09.129032+00:00', '2026-10-11T19:02:47.159609+00:00', '# Política de Privacidad\n\nNos tomamos muy en serio la protección de tus datos personales. No comercializamos tu información.')
ON CONFLICT DO NOTHING;

INSERT INTO public.policy_documents (id, slug, version, is_active, created_at, updated_at, published_at, content_markdown)
VALUES ('0d0aeb11-ac97-442d-a132-fe2d2d4664ba', 'privacidad', 'v1.1', false, '2026-10-11T19:58:09.129032+00:00', '2026-10-11T19:58:56.432987+00:00', '2026-10-11T19:58:09.129032+00:00', '# Política de Privacidad y Uso de Analítica (v1.1)

Nos tomamos muy en serio la protección de tus datos personales. 

## 1. Recolección de Datos y Analítica
Utilizamos **Google Analytics 4 (GA4)** y **PostHog** de forma anónima únicamente cuando otorgas tu consentimiento explícito a través del banner de privacidad de nuestra Fan Zone.

### 2. Lo que Medimos (Sin Datos Personales)
- Interacciones de navegación e inicio de sesión.
- Participación en trivias y canjes en la tienda oficial.
- Rendimiento y clics en elementos de la plataforma.

### 3. Lo que NUNCA Recolectamos ni Enviamos
- Tu dirección de correo electrónico, nombre, fecha de nacimiento o municipio.
- Tu saldo de perlitas o información financiera.
- Ninguna información personal identificable (PII).

### 4. Cómo Retirar tu Consentimiento
Puedes modificar o retirar tu consentimiento en cualquier momento haciendo clic en **"Configuración de Cookies"** en el pie de página de la aplicación web o desde la sección de **Ajustes**. Al rechazar la analítica, se detendrá el envío de eventos y se eliminarán automáticamente las cookies asociadas a Google Analytics (`_ga`).')
ON CONFLICT DO NOTHING;

INSERT INTO public.policy_documents (id, slug, version, is_active, created_at, updated_at, published_at, content_markdown)
VALUES ('ef9d1896-e254-4fba-b598-ff6442ccbc4e', 'privacidad', '18.0', true, '2026-10-11T19:58:56.432987+00:00', '2026-10-11T19:58:56.432987+00:00', '2026-10-11T19:58:56.432987+00:00', '# Política de Privacidad (v18.0)

Actualización Fase 18: Recopilación y procesamiento de datos para anuncios de terceros con Google Ad Manager y Google Publisher Tag (GPT), cookies publicitarias no personalizadas y registro auditado de sesiones de recompensa.')
ON CONFLICT DO NOTHING;

-- Seed for standings
INSERT INTO public.standings (id, wins, losses, points, logo_url, team_name, created_at, order_index, games_played)
VALUES ('8947635b-fc5c-44c3-af02-d495cd54be61', 10, 2, 22, NULL, 'Guaiqueríes de Margarita', '2026-10-11T19:02:47.979409+00:00', 1, 12)
ON CONFLICT DO NOTHING;

INSERT INTO public.standings (id, wins, losses, points, logo_url, team_name, created_at, order_index, games_played)
VALUES ('cccb7749-5ff5-4165-9732-786e1c8ee0b3', 8, 4, 20, NULL, 'Gaiteros del Zulia', '2026-10-11T19:02:47.979409+00:00', 2, 12)
ON CONFLICT DO NOTHING;

INSERT INTO public.standings (id, wins, losses, points, logo_url, team_name, created_at, order_index, games_played)
VALUES ('34cc3886-25a4-4f4e-9c62-562ac091e38c', 7, 5, 19, NULL, 'Trotamundos de Carabobo', '2026-10-11T19:02:47.979409+00:00', 3, 12)
ON CONFLICT DO NOTHING;

INSERT INTO public.standings (id, wins, losses, points, logo_url, team_name, created_at, order_index, games_played)
VALUES ('b67d104c-b672-4fd6-93ce-ef12378bc67f', 6, 6, 18, NULL, 'Marinos de Anzoátegui', '2026-10-11T19:02:47.979409+00:00', 4, 12)
ON CONFLICT DO NOTHING;

INSERT INTO public.standings (id, wins, losses, points, logo_url, team_name, created_at, order_index, games_played)
VALUES ('9d8c31eb-65dd-4a57-947f-59789558a994', 5, 7, 17, NULL, 'Cocodrilos de Caracas', '2026-10-11T19:02:47.979409+00:00', 5, 12)
ON CONFLICT DO NOTHING;

