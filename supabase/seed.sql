-- Baseline seed data for local environment
-- STRICT COMPLIANCE: Zero hardcoded mock users, players, games, trivias or products (AGENTS.md Rule 9).
-- All operational data is fetched live from Supabase / official club APIs.

-- Baseline economy configuration (if table exists)
INSERT INTO public.economy_settings (daily_pearl_cap, weekly_pearl_cap, streak_bonus_config)
VALUES (1000, 5000, '{"streak_3_days": 100, "streak_7_days": 300}'::jsonb)
ON CONFLICT DO NOTHING;
