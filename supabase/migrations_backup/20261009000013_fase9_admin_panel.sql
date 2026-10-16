-- Migration: 20261009000013_fase9_admin_panel.sql
-- Description: Backend RPC functions, storage configuration, audit triggers, and security definers for Admin Panel (Fase 9)

-- 1. Helper assert_admin()
CREATE OR REPLACE FUNCTION public.assert_admin()
RETURNS BOOLEAN AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_role staff_role;
    v_active BOOLEAN;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Usuario no autenticado' USING ERRCODE = '42501';
    END IF;

    SELECT role, active INTO v_role, v_active
    FROM public.staff_members
    WHERE user_id = v_uid;

    IF v_active IS NOT TRUE OR v_role != 'admin' THEN
        RAISE EXCEPTION 'Admin authorization required.' USING ERRCODE = '42501';
    END IF;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.assert_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.assert_admin() TO authenticated, service_role;

-- 2. Audit Log Immutable Trigger (No UPDATE, No DELETE)
CREATE OR REPLACE FUNCTION prevent_audit_log_mutation()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Audit Log entries are immutable. UPDATE and DELETE operations are forbidden.';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_prevent_audit_log_mutation ON public.audit_log;
CREATE TRIGGER trg_prevent_audit_log_mutation
BEFORE UPDATE OR DELETE ON public.audit_log
FOR EACH ROW EXECUTE FUNCTION prevent_audit_log_mutation();

-- 3. Storage Bucket product-images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'product-images',
    'product-images',
    true,
    5242880, -- 5 MB
    ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp'];

DROP POLICY IF EXISTS "ProductImages Public Read" ON storage.objects;
CREATE POLICY "ProductImages Public Read" ON storage.objects
    FOR SELECT USING (bucket_id = 'product-images');

DROP POLICY IF EXISTS "ProductImages Admin Insert" ON storage.objects;
CREATE POLICY "ProductImages Admin Insert" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'product-images' AND
        EXISTS (
            SELECT 1 FROM public.staff_members
            WHERE user_id = auth.uid() AND role = 'admin' AND active = true
        )
    );

DROP POLICY IF EXISTS "ProductImages Admin Update" ON storage.objects;
CREATE POLICY "ProductImages Admin Update" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'product-images' AND
        EXISTS (
            SELECT 1 FROM public.staff_members
            WHERE user_id = auth.uid() AND role = 'admin' AND active = true
        )
    );

DROP POLICY IF EXISTS "ProductImages Admin Delete" ON storage.objects;
CREATE POLICY "ProductImages Admin Delete" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'product-images' AND
        EXISTS (
            SELECT 1 FROM public.staff_members
            WHERE user_id = auth.uid() AND role = 'admin' AND active = true
        )
    );

-- 4. Trivias Management Functions
CREATE OR REPLACE FUNCTION public.admin_upsert_trivia(
    p_trivia JSONB,
    p_questions JSONB DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_trivia_id UUID;
    v_existing_status trivia_status;
    v_attempt_count INT := 0;
    v_q_elem JSONB;
    v_opt_elem JSONB;
    v_q_id UUID;
BEGIN
    PERFORM public.assert_admin();

    v_trivia_id := (p_trivia->>'id')::UUID;

    IF v_trivia_id IS NOT NULL THEN
        SELECT status INTO v_existing_status FROM public.trivias WHERE id = v_trivia_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Trivia no encontrada.';
        END IF;

        SELECT COUNT(*) INTO v_attempt_count FROM public.trivia_attempts WHERE trivia_id = v_trivia_id;

        IF v_attempt_count > 0 AND p_questions IS NOT NULL THEN
            RAISE EXCEPTION 'No se pueden modificar preguntas u opciones de una trivia con intentos registrados. Duplique o archive la trivia.';
        END IF;
    END IF;

    IF v_trivia_id IS NULL THEN
        INSERT INTO public.trivias (
            title, description, status, starts_at, ends_at, time_limit_seconds, reward_rules, max_attempts
        ) VALUES (
            p_trivia->>'title',
            p_trivia->>'description',
            COALESCE((p_trivia->>'status')::trivia_status, 'draft'),
            (p_trivia->>'starts_at')::TIMESTAMPTZ,
            (p_trivia->>'ends_at')::TIMESTAMPTZ,
            COALESCE((p_trivia->>'time_limit_seconds')::INT, 60),
            COALESCE(p_trivia->'reward_rules', '{"per_correct_pearls": 50, "perfect_score_bonus": 100}'::jsonb),
            COALESCE((p_trivia->>'max_attempts')::INT, 1)
        ) RETURNING id INTO v_trivia_id;
    ELSE
        UPDATE public.trivias SET
            title = COALESCE(p_trivia->>'title', title),
            description = COALESCE(p_trivia->>'description', description),
            status = COALESCE((p_trivia->>'status')::trivia_status, status),
            starts_at = COALESCE((p_trivia->>'starts_at')::TIMESTAMPTZ, starts_at),
            ends_at = COALESCE((p_trivia->>'ends_at')::TIMESTAMPTZ, ends_at),
            time_limit_seconds = COALESCE((p_trivia->>'time_limit_seconds')::INT, time_limit_seconds),
            reward_rules = COALESCE(p_trivia->'reward_rules', reward_rules),
            max_attempts = COALESCE((p_trivia->>'max_attempts')::INT, max_attempts)
        WHERE id = v_trivia_id;
    END IF;

    -- Upsert Questions & Options if allowed and provided
    IF p_questions IS NOT NULL AND v_attempt_count = 0 THEN
        DELETE FROM public.trivia_questions WHERE trivia_id = v_trivia_id;

        FOR v_q_elem IN SELECT * FROM jsonb_array_elements(p_questions)
        LOOP
            INSERT INTO public.trivia_questions (
                trivia_id, question_text, points, order_index
            ) VALUES (
                v_trivia_id,
                v_q_elem->>'question_text',
                COALESCE((v_q_elem->>'points')::INT, 50),
                COALESCE((v_q_elem->>'order_index')::INT, 0)
            ) RETURNING id INTO v_q_id;

            IF v_q_elem->'options' IS NOT NULL THEN
                FOR v_opt_elem IN SELECT * FROM jsonb_array_elements(v_q_elem->'options')
                LOOP
                    INSERT INTO public.trivia_options (
                        question_id, option_text, is_correct
                    ) VALUES (
                        v_q_id,
                        v_opt_elem->>'option_text',
                        COALESCE((v_opt_elem->>'is_correct')::BOOLEAN, false)
                    );
                END LOOP;
            END IF;
        END LOOP;
    END IF;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (v_admin_id, 'upsert_trivia', 'trivias', v_trivia_id::text, p_trivia);

    RETURN jsonb_build_object('id', v_trivia_id, 'status', 'success');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

CREATE OR REPLACE FUNCTION public.admin_publish_trivia(
    p_trivia_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_trivia public.trivias%ROWTYPE;
    v_q_count INT;
    v_invalid_q INT;
    v_per_correct INT;
    v_perfect_bonus INT;
    v_max_possible INT;
    v_daily_cap INT;
BEGIN
    PERFORM public.assert_admin();

    SELECT * INTO v_trivia FROM public.trivias WHERE id = p_trivia_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Trivia no encontrada.';
    END IF;

    IF v_trivia.starts_at >= v_trivia.ends_at THEN
        RAISE EXCEPTION 'La fecha de inicio debe ser anterior a la fecha de fin.';
    END IF;

    IF v_trivia.time_limit_seconds <= 0 THEN
        RAISE EXCEPTION 'El tiempo límite debe ser mayor a 0 segundos.';
    END IF;

    SELECT COUNT(*) INTO v_q_count FROM public.trivia_questions WHERE trivia_id = p_trivia_id;
    IF v_q_count < 1 THEN
        RAISE EXCEPTION 'La trivia debe tener al menos una pregunta para poder publicarse.';
    END IF;

    SELECT COUNT(*) INTO v_invalid_q
    FROM public.trivia_questions q
    WHERE q.trivia_id = p_trivia_id AND (
        SELECT COUNT(*) FROM public.trivia_options o WHERE o.question_id = q.id AND o.is_correct = true
    ) != 1;

    IF v_invalid_q > 0 THEN
        RAISE EXCEPTION 'Cada pregunta debe tener exactamente una opción correcta.';
    END IF;

    v_per_correct := COALESCE((v_trivia.reward_rules->>'per_correct_pearls')::INT, 0);
    v_perfect_bonus := COALESCE((v_trivia.reward_rules->>'perfect_score_bonus')::INT, 0);
    v_max_possible := (v_q_count * v_per_correct) + v_perfect_bonus;

    SELECT daily_pearl_cap INTO v_daily_cap FROM public.economy_settings ORDER BY created_at DESC LIMIT 1;
    IF v_daily_cap IS NOT NULL AND v_max_possible > v_daily_cap THEN
        RAISE EXCEPTION 'La recompensa máxima de la trivia (%) excede el cap diario de economía (%).', v_max_possible, v_daily_cap;
    END IF;

    UPDATE public.trivias SET status = 'published' WHERE id = p_trivia_id;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id)
    VALUES (v_admin_id, 'publish_trivia', 'trivias', p_trivia_id::text);

    RETURN jsonb_build_object('id', p_trivia_id, 'status', 'published');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

CREATE OR REPLACE FUNCTION public.admin_duplicate_trivia(
    p_trivia_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_orig public.trivias%ROWTYPE;
    v_new_id UUID;
    v_q RECORD;
    v_new_q_id UUID;
BEGIN
    PERFORM public.assert_admin();

    SELECT * INTO v_orig FROM public.trivias WHERE id = p_trivia_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Trivia original no encontrada.';
    END IF;

    INSERT INTO public.trivias (
        title, description, status, starts_at, ends_at, time_limit_seconds, reward_rules, max_attempts
    ) VALUES (
        v_orig.title || ' (Copia)',
        v_orig.description,
        'draft',
        v_orig.starts_at,
        v_orig.ends_at,
        v_orig.time_limit_seconds,
        v_orig.reward_rules,
        v_orig.max_attempts
    ) RETURNING id INTO v_new_id;

    FOR v_q IN SELECT * FROM public.trivia_questions WHERE trivia_id = p_trivia_id
    LOOP
        INSERT INTO public.trivia_questions (
            trivia_id, question_text, points, order_index
        ) VALUES (
            v_new_id, v_q.question_text, v_q.points, v_q.order_index
        ) RETURNING id INTO v_new_q_id;

        INSERT INTO public.trivia_options (question_id, option_text, is_correct)
        SELECT v_new_q_id, option_text, is_correct
        FROM public.trivia_options
        WHERE question_id = v_q.id;
    END LOOP;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (v_admin_id, 'duplicate_trivia', 'trivias', v_new_id::text, jsonb_build_object('source_id', p_trivia_id), jsonb_build_object('new_id', v_new_id));

    RETURN jsonb_build_object('id', v_new_id, 'status', 'draft');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

CREATE OR REPLACE FUNCTION public.admin_archive_trivia(
    p_trivia_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID := auth.uid();
BEGIN
    PERFORM public.assert_admin();

    UPDATE public.trivias SET status = 'archived' WHERE id = p_trivia_id;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id)
    VALUES (v_admin_id, 'archive_trivia', 'trivias', p_trivia_id::text);

    RETURN jsonb_build_object('id', p_trivia_id, 'status', 'archived');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.admin_upsert_trivia(JSONB, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_upsert_trivia(JSONB, JSONB) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_publish_trivia(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_publish_trivia(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_duplicate_trivia(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_duplicate_trivia(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_archive_trivia(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_archive_trivia(UUID) TO authenticated, service_role;

-- 5. Products Management Functions
CREATE OR REPLACE FUNCTION public.admin_upsert_product(
    p_product JSONB
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_product_id UUID;
    v_cost INT;
    v_stock INT;
BEGIN
    PERFORM public.assert_admin();

    v_product_id := (p_product->>'id')::UUID;
    v_cost := (p_product->>'cost_pearls')::INT;
    v_stock := (p_product->>'stock')::INT;

    IF v_cost <= 0 THEN
        RAISE EXCEPTION 'El costo en perlitas debe ser mayor a cero.';
    END IF;

    IF v_stock < 0 THEN
        RAISE EXCEPTION 'El stock no puede ser negativo.';
    END IF;

    IF v_product_id IS NULL THEN
        INSERT INTO public.products (
            name, description, category, cost_pearls, stock, variants, active, valid_from, valid_until, images
        ) VALUES (
            p_product->>'name',
            p_product->>'description',
            COALESCE((p_product->>'category')::product_category, 'physical'),
            v_cost,
            v_stock,
            COALESCE(p_product->'variants', '[]'::jsonb),
            COALESCE((p_product->>'active')::BOOLEAN, true),
            COALESCE((p_product->>'valid_from')::TIMESTAMPTZ, NOW()),
            (p_product->>'valid_until')::TIMESTAMPTZ,
            ARRAY(SELECT jsonb_array_elements_text(COALESCE(p_product->'images', '[]'::jsonb)))
        ) RETURNING id INTO v_product_id;
    ELSE
        UPDATE public.products SET
            name = COALESCE(p_product->>'name', name),
            description = COALESCE(p_product->>'description', description),
            category = COALESCE((p_product->>'category')::product_category, category),
            cost_pearls = v_cost,
            stock = v_stock,
            variants = COALESCE(p_product->'variants', variants),
            active = COALESCE((p_product->>'active')::BOOLEAN, active),
            valid_from = COALESCE((p_product->>'valid_from')::TIMESTAMPTZ, valid_from),
            valid_until = (p_product->>'valid_until')::TIMESTAMPTZ,
            images = ARRAY(SELECT jsonb_array_elements_text(COALESCE(p_product->'images', '[]'::jsonb)))
        WHERE id = v_product_id;
    END IF;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (v_admin_id, 'upsert_product', 'products', v_product_id::text, p_product);

    RETURN jsonb_build_object('id', v_product_id, 'status', 'success');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.admin_upsert_product(JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_upsert_product(JSONB) TO authenticated, service_role;

-- 6. Players and Games Management Functions
CREATE OR REPLACE FUNCTION public.admin_upsert_player(
    p_player JSONB
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_player_id UUID;
BEGIN
    PERFORM public.assert_admin();

    v_player_id := (p_player->>'id')::UUID;

    IF v_player_id IS NULL THEN
        INSERT INTO public.players (
            name, jersey_number, position, height, age, nationality, bio, is_active, is_star
        ) VALUES (
            p_player->>'name',
            (p_player->>'jersey_number')::INT,
            p_player->>'position',
            p_player->>'height',
            (p_player->>'age')::INT,
            COALESCE(p_player->>'nationality', 'Venezuela'),
            p_player->>'bio',
            COALESCE((p_player->>'is_active')::BOOLEAN, true),
            COALESCE((p_player->>'is_star')::BOOLEAN, false)
        ) RETURNING id INTO v_player_id;
    ELSE
        UPDATE public.players SET
            name = COALESCE(p_player->>'name', name),
            jersey_number = COALESCE((p_player->>'jersey_number')::INT, jersey_number),
            position = COALESCE(p_player->>'position', position),
            height = COALESCE(p_player->>'height', height),
            age = COALESCE((p_player->>'age')::INT, age),
            nationality = COALESCE(p_player->>'nationality', nationality),
            bio = COALESCE(p_player->>'bio', bio),
            is_active = COALESCE((p_player->>'is_active')::BOOLEAN, is_active),
            is_star = COALESCE((p_player->>'is_star')::BOOLEAN, is_star)
        WHERE id = v_player_id;
    END IF;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (v_admin_id, 'upsert_player', 'players', v_player_id::text, p_player);

    RETURN jsonb_build_object('id', v_player_id, 'status', 'success');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

CREATE OR REPLACE FUNCTION public.admin_delete_player(
    p_player_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID := auth.uid();
BEGIN
    PERFORM public.assert_admin();

    UPDATE public.players SET is_active = false WHERE id = p_player_id;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id)
    VALUES (v_admin_id, 'deactivate_player', 'players', p_player_id::text);

    RETURN jsonb_build_object('id', p_player_id, 'status', 'deactivated');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

CREATE OR REPLACE FUNCTION public.admin_upsert_game(
    p_game JSONB
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_game_id UUID;
BEGIN
    PERFORM public.assert_admin();

    v_game_id := (p_game->>'id')::UUID;

    IF v_game_id IS NULL THEN
        INSERT INTO public.games (
            opponent, location, game_date, is_home, status, our_score, opponent_score
        ) VALUES (
            p_game->>'opponent',
            COALESCE(p_game->>'location', 'Gimnasio Ciudad de La Asunción'),
            (p_game->>'game_date')::TIMESTAMPTZ,
            COALESCE((p_game->>'is_home')::BOOLEAN, true),
            COALESCE((p_game->>'status')::game_status, 'scheduled'),
            COALESCE((p_game->>'our_score')::INT, 0),
            COALESCE((p_game->>'opponent_score')::INT, 0)
        ) RETURNING id INTO v_game_id;
    ELSE
        UPDATE public.games SET
            opponent = COALESCE(p_game->>'opponent', opponent),
            location = COALESCE(p_game->>'location', location),
            game_date = COALESCE((p_game->>'game_date')::TIMESTAMPTZ, game_date),
            is_home = COALESCE((p_game->>'is_home')::BOOLEAN, is_home),
            status = COALESCE((p_game->>'status')::game_status, status),
            our_score = COALESCE((p_game->>'our_score')::INT, our_score),
            opponent_score = COALESCE((p_game->>'opponent_score')::INT, opponent_score)
        WHERE id = v_game_id;
    END IF;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (v_admin_id, 'upsert_game', 'games', v_game_id::text, p_game);

    RETURN jsonb_build_object('id', v_game_id, 'status', 'success');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

CREATE OR REPLACE FUNCTION public.admin_delete_game(
    p_game_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID := auth.uid();
BEGIN
    PERFORM public.assert_admin();

    UPDATE public.games SET status = 'cancelled' WHERE id = p_game_id;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id)
    VALUES (v_admin_id, 'cancel_game', 'games', p_game_id::text);

    RETURN jsonb_build_object('id', p_game_id, 'status', 'cancelled');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.admin_upsert_player(JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_upsert_player(JSONB) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_delete_player(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_delete_player(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_upsert_game(JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_upsert_game(JSONB) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_delete_game(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_delete_game(UUID) TO authenticated, service_role;

-- 7. Economy Settings Function
CREATE OR REPLACE FUNCTION public.admin_update_economy_settings(
    p_settings JSONB
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_daily INT;
    v_weekly INT;
    v_streak JSONB;
    v_old_settings JSONB;
    v_new_id UUID;
BEGIN
    PERFORM public.assert_admin();

    v_daily := (p_settings->>'daily_pearl_cap')::INT;
    v_weekly := (p_settings->>'weekly_pearl_cap')::INT;
    v_streak := COALESCE(p_settings->'streak_bonus_config', '{"streak_3_days": 100, "streak_7_days": 300}'::jsonb);

    IF v_daily <= 0 THEN
        RAISE EXCEPTION 'El cap diario debe ser mayor a 0.';
    END IF;

    IF v_weekly < v_daily THEN
        RAISE EXCEPTION 'El cap semanal (%) debe ser mayor o igual al cap diario (%).', v_weekly, v_daily;
    END IF;

    SELECT jsonb_build_object('daily_pearl_cap', daily_pearl_cap, 'weekly_pearl_cap', weekly_pearl_cap, 'streak_bonus_config', streak_bonus_config)
    INTO v_old_settings
    FROM public.economy_settings
    ORDER BY created_at DESC LIMIT 1;

    INSERT INTO public.economy_settings (
        daily_pearl_cap, weekly_pearl_cap, streak_bonus_config
    ) VALUES (
        v_daily, v_weekly, v_streak
    ) RETURNING id INTO v_new_id;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        v_admin_id, 'update_economy_settings', 'economy_settings', v_new_id::text,
        v_old_settings, p_settings
    );

    RETURN jsonb_build_object('id', v_new_id, 'status', 'success');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.admin_update_economy_settings(JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_economy_settings(JSONB) TO authenticated, service_role;

-- 8. Staff / Personal Management Functions
CREATE OR REPLACE FUNCTION public.admin_update_staff_role(
    p_target_id UUID,
    p_new_role staff_role
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_active_admins INT;
    v_old_role staff_role;
BEGIN
    PERFORM public.assert_admin();

    IF p_target_id = v_admin_id THEN
        RAISE EXCEPTION 'Un administrador no puede modificar su propio rol.';
    END IF;

    SELECT role INTO v_old_role FROM public.staff_members WHERE user_id = p_target_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Miembro del personal no encontrado.';
    END IF;

    IF v_old_role = 'admin' AND p_new_role != 'admin' THEN
        SELECT COUNT(*) INTO v_active_admins FROM public.staff_members WHERE role = 'admin' AND active = true;
        IF v_active_admins <= 1 THEN
            RAISE EXCEPTION 'No se puede degradar al último administrador activo.';
        END IF;
    END IF;

    UPDATE public.staff_members SET role = p_new_role WHERE user_id = p_target_id;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        v_admin_id, 'update_staff_role', 'staff_members', p_target_id::text,
        jsonb_build_object('role', v_old_role), jsonb_build_object('role', p_new_role)
    );

    RETURN jsonb_build_object('user_id', p_target_id, 'new_role', p_new_role);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

CREATE OR REPLACE FUNCTION public.admin_toggle_staff_active(
    p_target_id UUID,
    p_active BOOLEAN
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_active_admins INT;
    v_role staff_role;
BEGIN
    PERFORM public.assert_admin();

    IF p_target_id = v_admin_id THEN
        RAISE EXCEPTION 'Un administrador no puede desactivar su propia cuenta.';
    END IF;

    SELECT role INTO v_role FROM public.staff_members WHERE user_id = p_target_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Miembro del personal no encontrado.';
    END IF;

    IF v_role = 'admin' AND p_active IS FALSE THEN
        SELECT COUNT(*) INTO v_active_admins FROM public.staff_members WHERE role = 'admin' AND active = true;
        IF v_active_admins <= 1 THEN
            RAISE EXCEPTION 'No se puede desactivar al último administrador activo.';
        END IF;
    END IF;

    UPDATE public.staff_members SET active = p_active WHERE user_id = p_target_id;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'toggle_staff_active', 'staff_members', p_target_id::text,
        jsonb_build_object('active', p_active)
    );

    RETURN jsonb_build_object('user_id', p_target_id, 'active', p_active);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.admin_update_staff_role(UUID, staff_role) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_staff_role(UUID, staff_role) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_toggle_staff_active(UUID, BOOLEAN) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_toggle_staff_active(UUID, BOOLEAN) TO authenticated, service_role;

-- 9. Fanatics Management Functions
CREATE OR REPLACE FUNCTION public.admin_list_fans(
    p_municipality TEXT DEFAULT NULL,
    p_age_min INT DEFAULT NULL,
    p_age_max INT DEFAULT NULL,
    p_favorite_player_id UUID DEFAULT NULL,
    p_inactive_days INT DEFAULT NULL,
    p_status user_status DEFAULT NULL,
    p_search TEXT DEFAULT NULL,
    p_limit INT DEFAULT 20,
    p_cursor UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_res JSONB;
BEGIN
    PERFORM public.assert_admin();

    WITH filtered_fans AS (
        SELECT 
            p.id,
            p.display_name,
            p.municipality,
            p.birth_date,
            p.gender,
            p.favorite_player_id,
            p.shirt_size,
            p.status,
            p.created_at,
            COALESCE(w.balance_cache, 0) AS pearl_balance,
            pl.name AS favorite_player_name,
            EXTRACT(YEAR FROM age(CURRENT_DATE, p.birth_date))::INT AS calculated_age,
            GREATEST(
                p.created_at,
                (SELECT MAX(created_at) FROM public.ledger_entries WHERE fan_id = p.id),
                (SELECT MAX(created_at) FROM public.redemptions WHERE fan_id = p.id)
            ) AS last_activity_at
        FROM public.profiles p
        LEFT JOIN public.wallets w ON w.fan_id = p.id
        LEFT JOIN public.players pl ON pl.id = p.favorite_player_id
        WHERE 
            (p_municipality IS NULL OR p.municipality = p_municipality)
            AND (p_favorite_player_id IS NULL OR p.favorite_player_id = p_favorite_player_id)
            AND (p_status IS NULL OR p.status = p_status)
            AND (p_search IS NULL OR p.display_name ILIKE '%' || p_search || '%')
            AND (p_cursor IS NULL OR p.id > p_cursor)
    ),
    age_filtered AS (
        SELECT * FROM filtered_fans
        WHERE (p_age_min IS NULL OR calculated_age >= p_age_min)
          AND (p_age_max IS NULL OR calculated_age <= p_age_max)
          AND (p_inactive_days IS NULL OR last_activity_at <= NOW() - (p_inactive_days || ' days')::INTERVAL)
    )
    SELECT jsonb_build_object(
        'fans', COALESCE(jsonb_agg(to_jsonb(f)), '[]'::jsonb),
        'next_cursor', (SELECT id FROM age_filtered ORDER BY id LIMIT 1 OFFSET p_limit)
    ) INTO v_res
    FROM (
        SELECT * FROM age_filtered ORDER BY id LIMIT p_limit
    ) f;

    RETURN v_res;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

CREATE OR REPLACE FUNCTION public.admin_get_fan(
    p_fan_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_profile RECORD;
    v_balance INT := 0;
    v_trivias JSONB;
    v_redemptions JSONB;
BEGIN
    PERFORM public.assert_admin();

    SELECT p.*, pl.name AS favorite_player_name
    INTO v_profile
    FROM public.profiles p
    LEFT JOIN public.players pl ON pl.id = p.favorite_player_id
    WHERE p.id = p_fan_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Perfil de fanático no encontrado.';
    END IF;

    SELECT balance_cache INTO v_balance FROM public.wallets WHERE fan_id = p_fan_id;

    SELECT COALESCE(jsonb_agg(to_jsonb(ta)), '[]'::jsonb)
    INTO v_trivias
    FROM (
        SELECT a.id, t.title, a.score, a.pearls_awarded, a.submitted_at
        FROM public.trivia_attempts a
        JOIN public.trivias t ON t.id = a.trivia_id
        WHERE a.fan_id = p_fan_id
        ORDER BY a.started_at DESC LIMIT 10
    ) ta;

    SELECT COALESCE(jsonb_agg(to_jsonb(rd)), '[]'::jsonb)
    INTO v_redemptions
    FROM (
        SELECT r.id, pr.name AS product_name, r.cost_pearls, r.status, r.created_at
        FROM public.redemptions r
        JOIN public.products pr ON pr.id = r.product_id
        WHERE r.fan_id = p_fan_id
        ORDER BY r.created_at DESC LIMIT 10
    ) rd;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id)
    VALUES (v_admin_id, 'view_fan_profile', 'profiles', p_fan_id::text);

    RETURN jsonb_build_object(
        'profile', to_jsonb(v_profile),
        'balance', COALESCE(v_balance, 0),
        'recent_trivias', v_trivias,
        'recent_redemptions', v_redemptions
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

CREATE OR REPLACE FUNCTION public.admin_suspend_fan(
    p_fan_id UUID,
    p_reason TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID := auth.uid();
BEGIN
    PERFORM public.assert_admin();

    IF p_reason IS NULL OR trim(p_reason) = '' THEN
        RAISE EXCEPTION 'Se requiere un motivo obligatorio para suspender al fanático.';
    END IF;

    UPDATE public.profiles SET status = 'suspended' WHERE id = p_fan_id;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'suspend_fan', 'profiles', p_fan_id::text,
        jsonb_build_object('status', 'suspended', 'reason', p_reason)
    );

    RETURN jsonb_build_object('fan_id', p_fan_id, 'status', 'suspended');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

CREATE OR REPLACE FUNCTION public.admin_reactivate_fan(
    p_fan_id UUID,
    p_reason TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID := auth.uid();
BEGIN
    PERFORM public.assert_admin();

    IF p_reason IS NULL OR trim(p_reason) = '' THEN
        RAISE EXCEPTION 'Se requiere un motivo obligatorio para reactivar al fanático.';
    END IF;

    UPDATE public.profiles SET status = 'active' WHERE id = p_fan_id;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'reactivate_fan', 'profiles', p_fan_id::text,
        jsonb_build_object('status', 'active', 'reason', p_reason)
    );

    RETURN jsonb_build_object('fan_id', p_fan_id, 'status', 'active');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.admin_list_fans(TEXT, INT, INT, UUID, INT, user_status, TEXT, INT, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_fans(TEXT, INT, INT, UUID, INT, user_status, TEXT, INT, UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_get_fan(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_get_fan(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_suspend_fan(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_suspend_fan(UUID, TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_reactivate_fan(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_reactivate_fan(UUID, TEXT) TO authenticated, service_role;

-- 10. Segments Management Functions
CREATE OR REPLACE FUNCTION public.admin_upsert_segment(
    p_segment JSONB
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_segment_id UUID;
    v_filters JSONB;
    v_key TEXT;
    v_allowed_keys TEXT[] := ARRAY['municipality', 'gender', 'shirt_size', 'favorite_player_id', 'status', 'min_age', 'max_age'];
BEGIN
    PERFORM public.assert_admin();

    v_segment_id := (p_segment->>'id')::UUID;
    v_filters := COALESCE(p_segment->'filters', '{}'::jsonb);

    FOR v_key IN SELECT jsonb_object_keys(v_filters)
    LOOP
        IF NOT (v_key = ANY(v_allowed_keys)) THEN
            RAISE EXCEPTION 'Campo de filtro no permitido en segmentos: %', v_key;
        END IF;
    END LOOP;

    IF v_segment_id IS NULL THEN
        INSERT INTO public.segments (name, filters)
        VALUES (p_segment->>'name', v_filters)
        RETURNING id INTO v_segment_id;
    ELSE
        UPDATE public.segments SET
            name = COALESCE(p_segment->>'name', name),
            filters = v_filters
        WHERE id = v_segment_id;
    END IF;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (v_admin_id, 'upsert_segment', 'segments', v_segment_id::text, p_segment);

    RETURN jsonb_build_object('id', v_segment_id, 'status', 'success');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

CREATE OR REPLACE FUNCTION public.segment_count(
    p_segment_id UUID
)
RETURNS INT AS $$
DECLARE
    v_filters JSONB;
    v_count INT;
BEGIN
    PERFORM public.assert_admin();

    SELECT filters INTO v_filters FROM public.segments WHERE id = p_segment_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Segmento no encontrado.';
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM public.profiles p
    WHERE 
        ((v_filters->>'municipality') IS NULL OR p.municipality = (v_filters->>'municipality'))
        AND ((v_filters->>'gender') IS NULL OR p.gender = (v_filters->>'gender'))
        AND ((v_filters->>'shirt_size') IS NULL OR p.shirt_size = (v_filters->>'shirt_size'))
        AND ((v_filters->>'favorite_player_id') IS NULL OR p.favorite_player_id = (v_filters->>'favorite_player_id')::UUID)
        AND ((v_filters->>'status') IS NULL OR p.status = (v_filters->>'status')::user_status)
        AND ((v_filters->>'min_age') IS NULL OR EXTRACT(YEAR FROM age(CURRENT_DATE, p.birth_date)) >= (v_filters->>'min_age')::INT)
        AND ((v_filters->>'max_age') IS NULL OR EXTRACT(YEAR FROM age(CURRENT_DATE, p.birth_date)) <= (v_filters->>'max_age')::INT);

    RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

CREATE OR REPLACE FUNCTION public.segment_members(
    p_segment_id UUID,
    p_limit INT DEFAULT 50,
    p_cursor UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_filters JSONB;
    v_res JSONB;
BEGIN
    PERFORM public.assert_admin();

    SELECT filters INTO v_filters FROM public.segments WHERE id = p_segment_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Segmento no encontrado.';
    END IF;

    SELECT jsonb_build_object(
        'members', COALESCE(jsonb_agg(to_jsonb(sub)), '[]'::jsonb)
    ) INTO v_res
    FROM (
        SELECT 
            p.id,
            p.display_name,
            p.municipality,
            p.created_at
        FROM public.profiles p
        WHERE 
            ((v_filters->>'municipality') IS NULL OR p.municipality = (v_filters->>'municipality'))
            AND ((v_filters->>'gender') IS NULL OR p.gender = (v_filters->>'gender'))
            AND ((v_filters->>'shirt_size') IS NULL OR p.shirt_size = (v_filters->>'shirt_size'))
            AND ((v_filters->>'favorite_player_id') IS NULL OR p.favorite_player_id = (v_filters->>'favorite_player_id')::UUID)
            AND ((v_filters->>'status') IS NULL OR p.status = (v_filters->>'status')::user_status)
            AND ((v_filters->>'min_age') IS NULL OR EXTRACT(YEAR FROM age(CURRENT_DATE, p.birth_date)) >= (v_filters->>'min_age')::INT)
            AND ((v_filters->>'max_age') IS NULL OR EXTRACT(YEAR FROM age(CURRENT_DATE, p.birth_date)) <= (v_filters->>'max_age')::INT)
            AND (p_cursor IS NULL OR p.id > p_cursor)
        ORDER BY p.id
        LIMIT p_limit
    ) sub;

    RETURN v_res;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.admin_upsert_segment(JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_upsert_segment(JSONB) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.segment_count(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.segment_count(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.segment_members(UUID, INT, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.segment_members(UUID, INT, UUID) TO authenticated, service_role;

-- 11. Audit Log Search Function
CREATE OR REPLACE FUNCTION public.audit_search(
    p_actor_id UUID DEFAULT NULL,
    p_action TEXT DEFAULT NULL,
    p_entity TEXT DEFAULT NULL,
    p_from TIMESTAMPTZ DEFAULT NULL,
    p_to TIMESTAMPTZ DEFAULT NULL,
    p_limit INT DEFAULT 50,
    p_cursor UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_res JSONB;
BEGIN
    PERFORM public.assert_admin();

    SELECT jsonb_build_object(
        'logs', COALESCE(jsonb_agg(to_jsonb(sub)), '[]'::jsonb)
    ) INTO v_res
    FROM (
        SELECT a.*, p.display_name AS actor_name
        FROM public.audit_log a
        LEFT JOIN public.profiles p ON p.id = a.actor_id
        WHERE 
            (p_actor_id IS NULL OR a.actor_id = p_actor_id)
            AND (p_action IS NULL OR a.action = p_action)
            AND (p_entity IS NULL OR a.entity = p_entity)
            AND (p_from IS NULL OR a.created_at >= p_from)
            AND (p_to IS NULL OR a.created_at <= p_to)
            AND (p_cursor IS NULL OR a.id < p_cursor)
        ORDER BY a.created_at DESC, a.id DESC
        LIMIT p_limit
    ) sub;

    RETURN v_res;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.audit_search(UUID, TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, INT, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.audit_search(UUID, TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, INT, UUID) TO authenticated, service_role;

-- 12. Redemption Issues Resolution Function
CREATE OR REPLACE FUNCTION public.admin_resolve_redemption_issue(
    p_redemption_id UUID,
    p_action TEXT,
    p_note TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_redemption public.redemptions%ROWTYPE;
    v_refund_exists INT := 0;
    v_old_status redemption_status;
    v_new_status redemption_status;
    v_old_balance INT := 0;
    v_new_balance INT := 0;
BEGIN
    PERFORM public.assert_admin();

    IF p_action NOT IN ('reissue', 'refund', 'close') THEN
        RAISE EXCEPTION 'Acción inválida. Debe ser reissue, refund o close.';
    END IF;

    IF p_note IS NULL OR trim(p_note) = '' THEN
        RAISE EXCEPTION 'Se requiere una nota obligatoria para resolver la incidencia.';
    END IF;

    SELECT * INTO v_redemption FROM public.redemptions WHERE id = p_redemption_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Canje no encontrado.';
    END IF;

    v_old_status := v_redemption.status;

    IF p_action = 'refund' THEN
        SELECT COUNT(*) INTO v_refund_exists
        FROM public.ledger_entries
        WHERE source_type = 'redemption_refund' AND source_id = p_redemption_id::text;

        IF v_refund_exists > 0 THEN
            RAISE EXCEPTION 'Este canje ya ha sido reembolsado previamente.';
        END IF;

        SELECT balance_cache INTO v_old_balance FROM public.wallets WHERE fan_id = v_redemption.fan_id FOR UPDATE;

        v_new_balance := COALESCE(v_old_balance, 0) + v_redemption.cost_pearls;

        INSERT INTO public.ledger_entries (
            fan_id, amount, type, status, source_type, source_id, note, created_by
        ) VALUES (
            v_redemption.fan_id, v_redemption.cost_pearls, 'refund', 'confirmed',
            'redemption_refund', p_redemption_id::text, p_note, v_admin_id
        );

        INSERT INTO public.wallets (fan_id, balance_cache)
        VALUES (v_redemption.fan_id, v_new_balance)
        ON CONFLICT (fan_id)
        DO UPDATE SET balance_cache = v_new_balance, updated_at = NOW();

        v_new_status := 'cancelled';
        UPDATE public.redemptions SET status = v_new_status WHERE id = p_redemption_id;

    ELSIF p_action = 'reissue' THEN
        v_new_status := 'approved';
        UPDATE public.redemptions SET
            status = v_new_status,
            expires_at = NOW() + INTERVAL '7 days'
        WHERE id = p_redemption_id;

    ELSIF p_action = 'close' THEN
        v_new_status := 'rejected';
        UPDATE public.redemptions SET status = v_new_status WHERE id = p_redemption_id;
    END IF;

    INSERT INTO public.redemption_history (
        redemption_id, previous_status, new_status, changed_by, note
    ) VALUES (
        p_redemption_id, v_old_status, v_new_status, v_admin_id, p_note
    );

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        v_admin_id, 'resolve_redemption_issue', 'redemptions', p_redemption_id::text,
        jsonb_build_object('status', v_old_status),
        jsonb_build_object('status', v_new_status, 'action', p_action, 'note', p_note)
    );

    RETURN jsonb_build_object('id', p_redemption_id, 'status', v_new_status, 'action', p_action);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.admin_resolve_redemption_issue(UUID, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_resolve_redemption_issue(UUID, TEXT, TEXT) TO authenticated, service_role;
