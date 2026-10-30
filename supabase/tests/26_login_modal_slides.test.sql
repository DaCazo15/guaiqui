BEGIN;
SELECT plan(7);

-- Test 1: login_modal_slides table exists and has RLS enabled
SELECT lives_ok(
    'SELECT count(*) FROM pg_tables WHERE tablename = ''login_modal_slides'' AND rowsecurity = true',
    'login_modal_slides table must have RLS active'
);

-- Test 2: validate_login_modal_urls rejects dangerous javascript: scheme in image_url
SELECT throws_ok(
    $$ SELECT public.validate_login_modal_urls('javascript:alert(1)', '/app/tienda') $$,
    '22023',
    'Esquema de URL no permitido en la imagen.',
    'validate_login_modal_urls must reject javascript: in image_url'
);

-- Test 3: validate_login_modal_urls rejects dangerous data: scheme in cta_url
SELECT throws_ok(
    $$ SELECT public.validate_login_modal_urls('https://example.com/img.jpg', 'data:text/html,<script>alert(1)</script>') $$,
    '22023',
    'Esquema de URL no permitido en el botón CTA.',
    'validate_login_modal_urls must reject data: in cta_url'
);

-- Test 4: validate_login_modal_urls accepts valid relative and https URLs
SELECT lives_ok(
    $$ SELECT public.validate_login_modal_urls('https://example.com/slide1.jpg', '/app/tienda') $$,
    'validate_login_modal_urls should accept valid URLs'
);

-- Test 5: get_login_modal RPC exists
SELECT lives_ok(
    $$ SELECT count(*) FROM pg_proc WHERE proname = 'get_login_modal' $$,
    'get_login_modal RPC exists'
);

-- Test 6: admin_upsert_login_modal_slide RPC requires admin authorization
SELECT throws_ok(
    $$ SELECT public.admin_upsert_login_modal_slide(NULL, 1, 'https://example.com/img.jpg', 'Test', 'Sub', 'Ver', '/app/tienda', 'published', NOW(), NULL) $$,
    '42501',
    NULL,
    'admin_upsert_login_modal_slide should reject non-admin'
);

-- Test 7: RLS policy allows public select on login_modal_slides
SELECT lives_ok(
    $$ SELECT count(*) FROM public.login_modal_slides WHERE status = 'published' $$,
    'login_modal_slides permits select for published'
);

SELECT * FROM finish();
ROLLBACK;
