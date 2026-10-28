-- ============================================================================
-- Migration: 20261028000003_add_team_id_to_team_tables.sql
-- Description: Multi-tenant Step 4:
--              Adds team_id NOT NULL DEFAULT to all 45+ team entities and child tables.
--              Defaults to Guaiqueríes de Margarita ('a0000000-0000-0000-0000-000000000001'),
--              establishing foreign keys to public.teams(id) and performance indexes.
-- ============================================================================

DO $$
DECLARE
    v_tbl TEXT;
    v_team_tables TEXT[] := ARRAY[
        -- Entidades Principales de Contenido y Operación
        'trivias', 'products', 'redemptions', 'games', 'players', 'segments',
        'site_announcements', 'carousel_slides', 'hero_carousel_slides',
        'history_milestones', 'site_team_members', 'faqs', 'site_stats',
        'social_links', 'landing_settings', 'landing_ctas', 'birthday_settings',
        'login_modal_slides', 'scan_events', 'standings', 'instagram_posts',
        'notification_templates', 'hall_of_fame_championships', 'hall_of_fame_jerseys',
        'hall_of_fame_legends', 'guess_player_challenges', 'trivia_polls',
        'over_under_predictions', 'mystery_play_challenges', 'score_predictions',
        'flash_trivia_challenges', 'progressive_clue_challenges',
        -- Tablas Hijas y Subtablas Operativas
        'trivia_questions', 'trivia_options', 'flash_trivia_questions',
        'trivia_poll_options', 'trivia_attempts', 'flash_trivia_attempts',
        'trivia_poll_votes', 'guess_player_votes', 'over_under_votes',
        'mystery_play_votes', 'score_prediction_votes', 'progressive_clue_votes',
        'redemption_history'
    ];
BEGIN
    FOREACH v_tbl IN ARRAY v_team_tables LOOP
        IF EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' AND table_name = v_tbl
        ) THEN
            -- Add team_id column with FK and default to official team
            EXECUTE format(
                'ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS team_id UUID NOT NULL DEFAULT %L REFERENCES public.teams(id) ON DELETE RESTRICT',
                v_tbl,
                'a0000000-0000-0000-0000-000000000001'
            );
            -- Create index for high performance tenant filtering
            EXECUTE format(
                'CREATE INDEX IF NOT EXISTS %I ON public.%I(team_id)',
                v_tbl || '_team_id_idx',
                v_tbl
            );
        END IF;
    END LOOP;
END$$;
