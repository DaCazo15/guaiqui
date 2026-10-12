-- =============================================================
-- TEST SUITE: Trivias Segment Persistence & Duplicate
-- =============================================================

BEGIN;
SELECT plan(4);

-- Setup: Admin user and test segment
DO $$
DECLARE
    v_admin UUID := 'a2900000-0000-0000-0000-000000000001';
    v_seg UUID := 's2900000-0000-0000-0000-000000000001';
BEGIN
    INSERT INTO auth.users (id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token)
    VALUES
        (v_admin, 'authenticated', 'authenticated', 'admin_segment_test@test.com', crypt('Admin123!', gen_salt('bf')), '{"provider":"email"}'::jsonb, '{}'::jsonb, NOW(), NOW(), '')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO profiles (id, display_name, status) VALUES
        (v_admin, 'Admin Segment Test', 'active')
    ON CONFLICT (id) DO UPDATE SET display_name = EXCLUDED.display_name;

    INSERT INTO staff_members (user_id, role, active)
    VALUES (v_admin, 'admin', true)
    ON CONFLICT (user_id) DO UPDATE SET role = 'admin', active = true;

    INSERT INTO segments (id, name, filters)
    VALUES (v_seg, 'Segmento VIP Test', '{"municipality": "Mariño"}'::jsonb)
    ON CONFLICT (id) DO NOTHING;
END $$;


-- TEST 1: Crear trivia con segmento -> se guarda
DO $$
DECLARE
    v_admin UUID := 'a2900000-0000-0000-0000-000000000001';
    v_seg UUID := 's2900000-0000-0000-0000-000000000001';
    v_res JSONB;
    v_trivia_id UUID;
    v_saved_seg UUID;
BEGIN
    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "a2900000-0000-0000-0000-000000000001", "role": "authenticated"}';

    v_res := public.admin_upsert_trivia(
        jsonb_build_object(
            'title', 'Trivia Con Segmento Test',
            'description', 'Prueba de guardado de segmento',
            'starts_at', NOW(),
            'ends_at', NOW() + interval '1 day',
            'target_segment_id', v_seg::text
        ),
        '[]'::jsonb
    );

    v_trivia_id := (v_res->>'id')::UUID;
    SELECT target_segment_id INTO v_saved_seg FROM public.trivias WHERE id = v_trivia_id;

    IF v_saved_seg = v_seg THEN
        PERFORM ok(true, 'Crear trivia con segmento guarda target_segment_id correctamente.');
    ELSE
        PERFORM ok(false, 'Crear trivia con segmento NO guardó target_segment_id.');
    END IF;
END $$;


-- TEST 2: Editar sin enviar la clave target_segment_id -> se conserva el valor existente
DO $$
DECLARE
    v_admin UUID := 'a2900000-0000-0000-0000-000000000001';
    v_seg UUID := 's2900000-0000-0000-0000-000000000001';
    v_trivia_id UUID;
    v_saved_seg UUID;
BEGIN
    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "a2900000-0000-0000-0000-000000000001", "role": "authenticated"}';

    SELECT id INTO v_trivia_id FROM public.trivias WHERE title = 'Trivia Con Segmento Test' LIMIT 1;

    -- Editar enviando solo título y descripción (sin la clave target_segment_id)
    PERFORM public.admin_upsert_trivia(
        jsonb_build_object(
            'id', v_trivia_id::text,
            'title', 'Trivia Con Segmento Test Editada',
            'description', 'Descripción actualizada sin tocar segmento'
        )
    );

    SELECT target_segment_id INTO v_saved_seg FROM public.trivias WHERE id = v_trivia_id;

    IF v_saved_seg = v_seg THEN
        PERFORM ok(true, 'Editar sin enviar la clave target_segment_id conserva el segmento.');
    ELSE
        PERFORM ok(false, 'Editar sin enviar target_segment_id perdió el valor previo.');
    END IF;
END $$;


-- TEST 3: Editar con null / vacío -> se limpia el segmento
DO $$
DECLARE
    v_admin UUID := 'a2900000-0000-0000-0000-000000000001';
    v_trivia_id UUID;
    v_saved_seg UUID;
BEGIN
    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "a2900000-0000-0000-0000-000000000001", "role": "authenticated"}';

    SELECT id INTO v_trivia_id FROM public.trivias WHERE title = 'Trivia Con Segmento Test Editada' LIMIT 1;

    -- Editar enviando target_segment_id: null
    PERFORM public.admin_upsert_trivia(
        jsonb_build_object(
            'id', v_trivia_id::text,
            'title', 'Trivia Sin Segmento Ahora',
            'target_segment_id', null
        )
    );

    SELECT target_segment_id INTO v_saved_seg FROM public.trivias WHERE id = v_trivia_id;

    IF v_saved_seg IS NULL THEN
        PERFORM ok(true, 'Editar con target_segment_id = null limpia el segmento correctamente.');
    ELSE
        PERFORM ok(false, 'Editar con target_segment_id = null NO limpió el segmento.');
    END IF;
END $$;


-- TEST 4: Duplicar trivia -> la copia conserva el target_segment_id
DO $$
DECLARE
    v_admin UUID := 'a2900000-0000-0000-0000-000000000001';
    v_seg UUID := 's2900000-0000-0000-0000-000000000001';
    v_orig_id UUID;
    v_res_dup JSONB;
    v_dup_id UUID;
    v_dup_seg UUID;
BEGIN
    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub": "a2900000-0000-0000-0000-000000000001", "role": "authenticated"}';

    -- Restaurar segmento a la trivia original
    SELECT id INTO v_orig_id FROM public.trivias WHERE title = 'Trivia Sin Segmento Ahora' LIMIT 1;
    UPDATE public.trivias SET target_segment_id = v_seg WHERE id = v_orig_id;

    -- Duplicar trivia
    v_res_dup := public.admin_duplicate_trivia(v_orig_id);
    v_dup_id := (v_res_dup->>'id')::UUID;

    SELECT target_segment_id INTO v_dup_seg FROM public.trivias WHERE id = v_dup_id;

    IF v_dup_seg = v_seg THEN
        PERFORM ok(true, 'admin_duplicate_trivia conserva target_segment_id en la trivia copiada.');
    ELSE
        PERFORM ok(false, 'admin_duplicate_trivia NO conservó target_segment_id.');
    END IF;
END $$;

SELECT * FROM finish();
ROLLBACK;
