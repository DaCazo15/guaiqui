-- =============================================================
-- TEST SUITE: Trivias Segment Persistence & Duplicate
-- =============================================================

BEGIN;
SELECT plan(4);

-- Setup: Admin user and test segment
DO $$
DECLARE
    v_admin UUID := 'a2900000-0000-0000-0000-000000000001';
    v_seg UUID := 'e2900000-0000-0000-0000-000000000001';
BEGIN
    INSERT INTO auth.users (id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_confirmed_at)
    VALUES
        (v_admin, 'authenticated', 'authenticated', 'admin_segment_test@test.com', crypt('Admin123!', gen_salt('bf')), '{"provider":"email"}'::jsonb, '{}'::jsonb, NOW(), NOW(), '', NOW())
    ON CONFLICT (id) DO UPDATE SET email_confirmed_at = NOW();

    INSERT INTO profiles (id, display_name, status, terms_accepted_at, privacy_accepted_at, pearls_rules_accepted_at) VALUES
        (v_admin, 'Admin Segment Test', 'active', NOW(), NOW(), NOW())
    ON CONFLICT (id) DO UPDATE SET display_name = EXCLUDED.display_name, terms_accepted_at = NOW(), privacy_accepted_at = NOW(), pearls_rules_accepted_at = NOW();

    INSERT INTO staff_members (user_id, team_id, role, active)
    VALUES (v_admin, 'a0000000-0000-0000-0000-000000000001', 'admin', true)
    ON CONFLICT (user_id) DO UPDATE SET team_id = 'a0000000-0000-0000-0000-000000000001', role = 'admin', active = true;

    INSERT INTO segments (id, team_id, name, filters)
    VALUES (v_seg, 'a0000000-0000-0000-0000-000000000001', 'Segmento VIP Test', '{"municipality": "Mariño"}'::jsonb)
    ON CONFLICT (id) DO NOTHING;
END $$;


-- TEST 1: Crear trivia con segmento -> se guarda
DO $$
DECLARE
    v_seg UUID := 'e2900000-0000-0000-0000-000000000001';
BEGIN
    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "a2900000-0000-0000-0000-000000000001", "role": "authenticated", "aal": "aal2"}';

    PERFORM public.admin_upsert_trivia(
        jsonb_build_object(
            'team_id', 'a0000000-0000-0000-0000-000000000001',
            'title', 'Trivia Con Segmento Test',
            'description', 'Prueba de guardado de segmento',
            'starts_at', NOW(),
            'ends_at', NOW() + interval '1 day',
            'target_segment_id', v_seg::text
        ),
        '[]'::jsonb
    );
END $$;

SELECT is(
    (SELECT target_segment_id FROM public.trivias WHERE title = 'Trivia Con Segmento Test' LIMIT 1),
    'e2900000-0000-0000-0000-000000000001'::uuid,
    'TEST 1: Crear trivia con segmento guarda target_segment_id correctamente.'
);


-- TEST 2: Editar sin enviar la clave target_segment_id -> se conserva el valor existente
DO $$
DECLARE
    v_trivia_id UUID;
BEGIN
    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "a2900000-0000-0000-0000-000000000001", "role": "authenticated", "aal": "aal2"}';

    SELECT id INTO v_trivia_id FROM public.trivias WHERE title = 'Trivia Con Segmento Test' LIMIT 1;

    PERFORM public.admin_upsert_trivia(
        jsonb_build_object(
            'id', v_trivia_id::text,
            'title', 'Trivia Con Segmento Test Editada',
            'description', 'Descripción actualizada sin tocar segmento'
        )
    );
END $$;

SELECT is(
    (SELECT target_segment_id FROM public.trivias WHERE title = 'Trivia Con Segmento Test Editada' LIMIT 1),
    'e2900000-0000-0000-0000-000000000001'::uuid,
    'TEST 2: Editar sin enviar la clave target_segment_id conserva el segmento.'
);


-- TEST 3: Editar con null / vacío -> se limpia el segmento
DO $$
DECLARE
    v_trivia_id UUID;
BEGIN
    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "a2900000-0000-0000-0000-000000000001", "role": "authenticated", "aal": "aal2"}';

    SELECT id INTO v_trivia_id FROM public.trivias WHERE title = 'Trivia Con Segmento Test Editada' LIMIT 1;

    PERFORM public.admin_upsert_trivia(
        jsonb_build_object(
            'id', v_trivia_id::text,
            'title', 'Trivia Sin Segmento Ahora',
            'target_segment_id', null
        )
    );
END $$;

SELECT ok(
    (SELECT target_segment_id FROM public.trivias WHERE title = 'Trivia Sin Segmento Ahora' LIMIT 1) IS NULL,
    'TEST 3: Editar con target_segment_id = null limpia el segmento correctamente.'
);


-- TEST 4: Duplicar trivia -> la copia conserva el target_segment_id
DO $$
DECLARE
    v_seg UUID := 'e2900000-0000-0000-0000-000000000001';
    v_orig_id UUID;
BEGIN
    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "a2900000-0000-0000-0000-000000000001", "role": "authenticated", "aal": "aal2"}';

    -- Restaurar segmento a la trivia original
    SELECT id INTO v_orig_id FROM public.trivias WHERE title = 'Trivia Sin Segmento Ahora' LIMIT 1;
    UPDATE public.trivias SET target_segment_id = v_seg WHERE id = v_orig_id;

    -- Duplicar trivia
    PERFORM public.admin_duplicate_trivia(v_orig_id);
END $$;

SELECT is(
    (SELECT target_segment_id FROM public.trivias WHERE title LIKE 'Copia de Trivia%' ORDER BY created_at DESC LIMIT 1),
    'e2900000-0000-0000-0000-000000000001'::uuid,
    'TEST 4: admin_duplicate_trivia conserva target_segment_id en la trivia copiada.'
);

SELECT * FROM finish();
ROLLBACK;
