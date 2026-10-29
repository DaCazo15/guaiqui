-- ============================================================================
-- Test Suite: 32_teams_multi_tenant.test.sql
-- Description: Tests for Step 1 Multi-Tenant:
--              1. Schema integrity of public.teams
--              2. RLS activation on public.teams
--              3. Secure projection view public.teams_public
--              4. Slug format constraint enforcement
--              5. Official seed validation for Guaiqueríes de Margarita
-- ============================================================================

BEGIN;

SELECT plan(10);

-- Test 1: teams table exists
SELECT has_table('public', 'teams', 'TEST 1: La tabla public.teams debe existir');

-- Test 2: RLS is active on public.teams
SELECT is(
    (SELECT relrowsecurity FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relname = 'teams'),
    true,
    'TEST 2: RLS debe estar habilitado en public.teams'
);

-- Test 3: Essential columns exist on teams
SELECT columns_are(
    'public',
    'teams',
    ARRAY['id', 'name', 'slug', 'short_name', 'logo_url', 'primary_color', 'secondary_color', 'status', 'joined_at', 'paid_until', 'created_at', 'updated_at'],
    'TEST 3: La tabla teams debe contener todas las columnas requeridas'
);

-- Test 4: teams_public view exists
SELECT has_view('public', 'teams_public', 'TEST 4: La vista public.teams_public debe existir');

-- Test 5: teams_public view does NOT expose sensitive paid_until column
SELECT columns_are(
    'public',
    'teams_public',
    ARRAY['id', 'name', 'slug', 'short_name', 'logo_url', 'primary_color', 'secondary_color', 'status', 'joined_at'],
    'TEST 5: La vista teams_public solo expone atributos públicos y no paid_until'
);

-- Test 6: Official team Guaiqueríes de Margarita is seeded
SELECT is(
    (SELECT name FROM public.teams WHERE slug = 'guaiqueries'),
    'Guaiqueríes de Margarita',
    'TEST 6: El equipo oficial Guaiqueríes de Margarita debe estar registrado'
);

-- Test 7: Guaiqueríes has active status
SELECT is(
    (SELECT status::text FROM public.teams WHERE slug = 'guaiqueries'),
    'active',
    'TEST 7: El equipo Guaiqueríes debe tener status active'
);

-- Test 8: Guaiqueríes is visible in teams_public view
SELECT is(
    (SELECT slug FROM public.teams_public WHERE slug = 'guaiqueries'),
    'guaiqueries',
    'TEST 8: Guaiqueríes debe ser proyectado por la vista teams_public'
);

-- Test 9: Slug check constraint rejects uppercase letters and spaces
SELECT throws_ok(
    $$ INSERT INTO public.teams (name, slug) VALUES ('Invalid Team', 'INVALID SLUG!') $$,
    '23514',
    NULL,
    'TEST 9: Slug con mayúsculas, espacios o caracteres inválidos debe violar el CHECK'
);

-- Test 10: Slug check constraint rejects slugs shorter than 2 characters
SELECT throws_ok(
    $$ INSERT INTO public.teams (name, slug) VALUES ('Short Team', 'a') $$,
    '23514',
    NULL,
    'TEST 10: Slug de menos de 2 caracteres debe violar el CHECK'
);

SELECT * FROM finish();
ROLLBACK;
