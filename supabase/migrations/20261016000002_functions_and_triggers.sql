-- ============================================================================
-- Migration: 20261016000002_functions_and_triggers.sql
-- Description: Consolidated functions, triggers, and RPCs for Guaiqueríes Platform.
--              Includes security hardening, STABLE auth helpers, search_path,
--              and permission grants.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.is_admin(user_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    IF user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    RETURN EXISTS (
        SELECT 1 FROM public.staff_members 
        WHERE staff_members.user_id = is_admin.user_id 
          AND role = 'admin' 
          AND active = true
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.is_staff_or_admin(user_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    IF user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    RETURN EXISTS (
        SELECT 1 FROM public.staff_members 
        WHERE staff_members.user_id = is_staff_or_admin.user_id 
          AND active = true
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.is_admin_check()
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    RETURN public.is_admin(auth.uid());
END;
$function$;

CREATE OR REPLACE FUNCTION public.assert_admin()
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_uid UUID := auth.uid();
    v_aal TEXT := (auth.jwt() ->> 'aal');
    v_role staff_role;
    v_active BOOLEAN;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Usuario no autenticado' USING ERRCODE = '42501';
    END IF;

    IF v_aal IS NULL OR v_aal != 'aal2' THEN
        RAISE EXCEPTION 'Verificación en dos pasos (2FA) requerida para administradores.' USING ERRCODE = '42501';
    END IF;

    SELECT role, active INTO v_role, v_active
    FROM public.staff_members
    WHERE user_id = v_uid;

    IF v_active IS NOT TRUE OR v_role != 'admin' THEN
        RAISE EXCEPTION 'Admin authorization required.' USING ERRCODE = '42501';
    END IF;

    RETURN TRUE;
END;
$function$;

CREATE OR REPLACE FUNCTION public.assert_staff()
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_uid UUID := auth.uid();
    v_aal TEXT := (auth.jwt() ->> 'aal');
    v_active BOOLEAN;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Usuario no autenticado' USING ERRCODE = '42501';
    END IF;

    IF v_aal IS NULL OR v_aal != 'aal2' THEN
        RAISE EXCEPTION 'Verificación en dos pasos (2FA) requerida para personal.' USING ERRCODE = '42501';
    END IF;

    SELECT active INTO v_active
    FROM public.staff_members
    WHERE user_id = v_uid;

    IF v_active IS NOT TRUE THEN
        RAISE EXCEPTION 'Staff or Admin authorization required.' USING ERRCODE = '42501';
    END IF;

    RETURN TRUE;
END;
$function$;

CREATE OR REPLACE FUNCTION public.assert_active_verified_fan(p_user_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
    v_uid UUID := COALESCE(p_user_id, auth.uid());
    v_email_confirmed TIMESTAMPTZ;
    v_profile_status user_status;
    v_deleted_at TIMESTAMPTZ;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    -- Ensure caller matches the target or caller is service_role
    IF auth.uid() IS NOT NULL AND v_uid != auth.uid() THEN
        RAISE EXCEPTION 'Unauthorized.';
    END IF;

    -- Check email confirmation in auth.users
    SELECT email_confirmed_at INTO v_email_confirmed
    FROM auth.users
    WHERE id = v_uid;

    IF v_email_confirmed IS NULL THEN
        RAISE EXCEPTION 'El correo electrónico debe estar verificado para realizar esta acción.';
    END IF;

    -- Check profile status
    SELECT status, deleted_at INTO v_profile_status, v_deleted_at
    FROM public.profiles
    WHERE id = v_uid;

    IF v_profile_status IS NULL OR v_profile_status != 'active' OR v_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION 'Tu cuenta está inactiva, suspendida o ha sido eliminada.';
    END IF;

    RETURN v_uid;
END;
$function$;

CREATE OR REPLACE FUNCTION public.assert_active_verified_fan()
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid UUID := auth.uid();
    v_email_confirmed TIMESTAMPTZ;
    v_profile_status user_status;
    v_deleted_at TIMESTAMPTZ;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT email_confirmed_at INTO v_email_confirmed
    FROM auth.users
    WHERE id = v_uid;

    IF v_email_confirmed IS NULL THEN
        RAISE EXCEPTION 'El correo electrónico debe estar verificado para realizar esta acción.';
    END IF;

    SELECT status, deleted_at INTO v_profile_status, v_deleted_at
    FROM public.profiles
    WHERE id = v_uid;

    IF v_profile_status IS NULL OR v_profile_status != 'active' OR v_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION 'Tu cuenta está inactiva, suspendida o ha sido eliminada.';
    END IF;

    RETURN v_uid;
END;
$function$;

CREATE OR REPLACE FUNCTION public.accept_terms()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_now TIMESTAMPTZ := NOW();
BEGIN
    PERFORM public.assert_active_verified_fan();

    UPDATE public.profiles
    SET terms_accepted_at = v_now,
        privacy_accepted_at = v_now,
        pearls_rules_accepted_at = v_now,
        updated_at = v_now
    WHERE id = v_user_id;

    RETURN jsonb_build_object('success', true, 'accepted_at', v_now);
END;
$function$;

CREATE OR REPLACE FUNCTION public.adjust_stock(p_product_id uuid, p_delta integer, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_staff_id UUID := auth.uid();
    v_product public.products%ROWTYPE;
    v_new_stock INT;
BEGIN
    PERFORM assert_staff();

    IF p_reason IS NULL OR trim(p_reason) = '' THEN
        RAISE EXCEPTION 'El motivo del ajuste de inventario es obligatorio.';
    END IF;

    SELECT * INTO v_product
    FROM public.products
    WHERE id = p_product_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Producto no encontrado.';
    END IF;

    v_new_stock := v_product.stock + p_delta;

    IF v_new_stock < 0 THEN
        RAISE EXCEPTION 'El stock no puede ser negativo. Stock actual: %, Delta: %', v_product.stock, p_delta;
    END IF;

    UPDATE public.products
    SET stock = v_new_stock
    WHERE id = v_product.id;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        v_staff_id,
        'adjust_stock',
        'products',
        v_product.id::text,
        jsonb_build_object('stock', v_product.stock),
        jsonb_build_object('stock', v_new_stock, 'delta', p_delta, 'reason', p_reason)
    );

    RETURN jsonb_build_object(
        'product_id', v_product.id,
        'old_stock', v_product.stock,
        'new_stock', v_new_stock,
        'delta', p_delta,
        'reason', p_reason
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_adjust_pearls(p_fan_id uuid, p_amount integer, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_old_balance INT := 0;
    v_new_balance INT;
BEGIN
    IF NOT is_admin(v_admin_id) THEN
        RAISE EXCEPTION 'Admin authorization required.';
    END IF;

    IF p_reason IS NULL OR trim(p_reason) = '' THEN
        RAISE EXCEPTION 'Mandatory justification reason required for manual pearl adjustment.';
    END IF;

    SELECT balance_cache INTO v_old_balance FROM wallets WHERE fan_id = p_fan_id FOR UPDATE;

    v_new_balance := COALESCE(v_old_balance, 0) + p_amount;
    IF v_new_balance < 0 THEN
        RAISE EXCEPTION 'Adjustment would result in negative balance (Current: %, Adjustment: %).', v_old_balance, p_amount;
    END IF;

    -- Insert into Ledger
    INSERT INTO ledger_entries (
        fan_id, amount, type, status, source_type, source_id, note, created_by
    ) VALUES (
        p_fan_id, p_amount, 'admin_adjustment', 'confirmed', 'admin', gen_random_uuid()::text,
        p_reason, v_admin_id
    );

    -- Update Wallet
    INSERT INTO wallets (fan_id, balance_cache)
    VALUES (p_fan_id, v_new_balance)
    ON CONFLICT (fan_id) 
    DO UPDATE SET balance_cache = v_new_balance, updated_at = NOW();

    -- Audit Log
    INSERT INTO audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        v_admin_id, 'admin_adjust_pearls', 'wallets', p_fan_id::text,
        jsonb_build_object('balance', v_old_balance),
        jsonb_build_object('balance', v_new_balance, 'adjustment', p_amount, 'reason', p_reason)
    );

    RETURN jsonb_build_object('fan_id', p_fan_id, 'old_balance', v_old_balance, 'new_balance', v_new_balance, 'adjustment', p_amount);
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_archive_trivia(p_trivia_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
BEGIN
    PERFORM public.assert_admin();

    UPDATE public.trivias SET status = 'archived' WHERE id = p_trivia_id;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id)
    VALUES (v_admin_id, 'archive_trivia', 'trivias', p_trivia_id::text);

    RETURN jsonb_build_object('id', p_trivia_id, 'status', 'archived');
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_delete_game(p_game_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
BEGIN
    PERFORM public.assert_admin();

    UPDATE public.games SET status = 'cancelled' WHERE id = p_game_id;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id)
    VALUES (v_admin_id, 'cancel_game', 'games', p_game_id::text);

    RETURN jsonb_build_object('id', p_game_id, 'status', 'cancelled');
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_delete_login_modal_slide(p_slide_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
BEGIN
    PERFORM public.assert_admin();

    DELETE FROM public.login_modal_slides WHERE id = p_slide_id;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        auth.uid(),
        'admin_delete_login_modal_slide',
        'login_modal_slides',
        p_slide_id::text,
        jsonb_build_object('deleted_id', p_slide_id),
        NULL
    );

    RETURN jsonb_build_object('success', true);
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_delete_player(p_player_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
BEGIN
    PERFORM public.assert_admin();

    UPDATE public.players SET is_active = false WHERE id = p_player_id;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id)
    VALUES (v_admin_id, 'deactivate_player', 'players', p_player_id::text);

    RETURN jsonb_build_object('id', p_player_id, 'status', 'deactivated');
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_duplicate_trivia(p_trivia_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
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
        title, description, status, starts_at, ends_at, time_limit_seconds, reward_rules, max_attempts, target_segment_id
    ) VALUES (
        v_orig.title || ' (Copia)',
        v_orig.description,
        'draft',
        v_orig.starts_at,
        v_orig.ends_at,
        v_orig.time_limit_seconds,
        v_orig.reward_rules,
        v_orig.max_attempts,
        v_orig.target_segment_id
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
    VALUES (
        v_admin_id, 'duplicate_trivia', 'trivias', v_new_id::text,
        jsonb_build_object('source_id', p_trivia_id),
        jsonb_build_object('new_id', v_new_id)
    );

    RETURN jsonb_build_object('id', v_new_id, 'status', 'draft');
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_get_fan(p_fan_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.admin_get_trivia_with_options(p_trivia_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_trivia public.trivias%ROWTYPE;
    v_questions JSONB;
BEGIN
    PERFORM public.assert_admin();

    SELECT * INTO v_trivia FROM public.trivias WHERE id = p_trivia_id;
    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    SELECT jsonb_agg(
        jsonb_build_object(
            'id', q.id,
            'question_text', q.question_text,
            'points', q.points,
            'order_index', q.order_index,
            'options', (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'id', o.id,
                        'option_text', o.option_text,
                        'is_correct', o.is_correct
                    )
                )
                FROM public.trivia_options o
                WHERE o.question_id = q.id
            )
        )
    ) INTO v_questions
    FROM public.trivia_questions q
    WHERE q.trivia_id = p_trivia_id;

    RETURN jsonb_build_object(
        'trivia', to_jsonb(v_trivia),
        'questions', COALESCE(v_questions, '[]'::jsonb)
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_list_fans(p_municipality text DEFAULT NULL::text, p_age_min integer DEFAULT NULL::integer, p_age_max integer DEFAULT NULL::integer, p_favorite_player_id uuid DEFAULT NULL::uuid, p_inactive_days integer DEFAULT NULL::integer, p_status user_status DEFAULT NULL::user_status, p_search text DEFAULT NULL::text, p_limit integer DEFAULT 20, p_cursor uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.admin_publish_policy(p_slug text, p_version text, p_content text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_new_id UUID;
BEGIN
    PERFORM public.assert_admin();

    IF p_slug NOT IN ('terminos', 'privacidad', 'perlitas', 'canjes') THEN
        RAISE EXCEPTION 'Slug de política inválido: %', p_slug;
    END IF;

    IF p_version IS NULL OR trim(p_version) = '' THEN
        RAISE EXCEPTION 'La versión de la política es obligatoria.';
    END IF;

    IF p_content IS NULL OR trim(p_content) = '' THEN
        RAISE EXCEPTION 'El contenido de la política en Markdown no puede estar vacío.';
    END IF;

    -- Deactivate current active policy for this slug
    UPDATE public.policy_documents
    SET is_active = false
    WHERE slug = p_slug AND is_active = true;

    -- Insert new active policy version
    INSERT INTO public.policy_documents (
        slug, version, content_markdown, published_at, is_active
    ) VALUES (
        p_slug, p_version, p_content, NOW(), true
    ) RETURNING id INTO v_new_id;

    -- Audit log
    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'publish_policy_document', 'policy_documents', v_new_id::text,
        jsonb_build_object('slug', p_slug, 'version', p_version)
    );

    RETURN jsonb_build_object('id', v_new_id, 'slug', p_slug, 'version', p_version, 'status', 'published');
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_publish_trivia(p_trivia_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.admin_reactivate_fan(p_fan_id uuid, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.admin_release_held_pearls(p_ledger_id uuid, p_note text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_entry public.ledger_entries%ROWTYPE;
    v_release_entry_id UUID := gen_random_uuid();
BEGIN
    PERFORM public.assert_admin();

    IF p_note IS NULL OR trim(p_note) = '' THEN
        RAISE EXCEPTION 'La justificación es obligatoria para liberar perlitas retenidas.';
    END IF;

    SELECT * INTO v_entry FROM public.ledger_entries WHERE id = p_ledger_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Registro de libro no encontrado.';
    END IF;

    IF v_entry.status != 'held' THEN
        RAISE EXCEPTION 'El registro no se encuentra en estado retenido (held).';
    END IF;

    IF EXISTS (SELECT 1 FROM public.ledger_hold_resolutions WHERE ledger_id = p_ledger_id) THEN
        RAISE EXCEPTION 'El registro retenido ya ha sido resuelto previamente (liberado o revocado).';
    END IF;

    -- A) Insert Resolution Record
    INSERT INTO public.ledger_hold_resolutions (
        ledger_id, action, note, resolved_by
    ) VALUES (
        p_ledger_id, 'release', p_note, v_admin_id
    );

    -- B) Append-Only: Insert NEW Confirmed Entry in Ledger
    INSERT INTO public.ledger_entries (
        id, fan_id, amount, type, status, source_type, source_id, note
    ) VALUES (
        v_release_entry_id, v_entry.fan_id, v_entry.amount, v_entry.type, 'confirmed', 'hold_release', p_ledger_id::text,
        'Liberado por admin: ' || p_note
    );

    -- C) Update Wallet Balance Cache
    INSERT INTO public.wallets (fan_id, balance_cache)
    VALUES (v_entry.fan_id, v_entry.amount)
    ON CONFLICT (fan_id)
    DO UPDATE SET balance_cache = wallets.balance_cache + v_entry.amount, updated_at = NOW();

    -- D) Audit Log
    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'release_held_pearls', 'ledger_entries', p_ledger_id::text,
        jsonb_build_object('fan_id', v_entry.fan_id, 'amount', v_entry.amount, 'note', p_note, 'release_entry_id', v_release_entry_id)
    );

    RETURN jsonb_build_object(
        'status', 'released',
        'ledger_id', p_ledger_id,
        'release_entry_id', v_release_entry_id,
        'amount', v_entry.amount
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_reorder_login_modal_slides(p_slide_ids uuid[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_id UUID;
    v_pos INT := 1;
BEGIN
    PERFORM public.assert_admin();

    IF p_slide_ids IS NULL OR array_length(p_slide_ids, 1) > 5 THEN
        RAISE EXCEPTION 'Máximo 5 diapositivas pueden ser reordenadas.';
    END IF;

    FOREACH v_id IN ARRAY p_slide_ids LOOP
        UPDATE public.login_modal_slides
        SET position = v_pos, updated_at = NOW()
        WHERE id = v_id;
        v_pos := v_pos + 1;
    END LOOP;

    RETURN jsonb_build_object('success', true);
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_resolve_redemption_issue(p_redemption_id uuid, p_action text, p_note text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.admin_resolve_risk_flag(p_flag_id uuid, p_note text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
BEGIN
    PERFORM public.assert_admin();

    IF p_note IS NULL OR trim(p_note) = '' THEN
        RAISE EXCEPTION 'La justificación es obligatoria para resolver una alerta de riesgo.';
    END IF;

    UPDATE public.risk_flags
    SET resolved = true
    WHERE id = p_flag_id;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'resolve_risk_flag', 'risk_flags', p_flag_id::text,
        jsonb_build_object('note', p_note)
    );

    RETURN jsonb_build_object('status', 'resolved', 'flag_id', p_flag_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_revoke_held_pearls(p_ledger_id uuid, p_note text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_entry public.ledger_entries%ROWTYPE;
BEGIN
    PERFORM public.assert_admin();

    IF p_note IS NULL OR trim(p_note) = '' THEN
        RAISE EXCEPTION 'La justificación es obligatoria para revocar perlitas retenidas.';
    END IF;

    SELECT * INTO v_entry FROM public.ledger_entries WHERE id = p_ledger_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Registro de libro no encontrado.';
    END IF;

    IF v_entry.status != 'held' THEN
        RAISE EXCEPTION 'El registro no se encuentra en estado retenido (held).';
    END IF;

    IF EXISTS (SELECT 1 FROM public.ledger_hold_resolutions WHERE ledger_id = p_ledger_id) THEN
        RAISE EXCEPTION 'El registro retenido ya ha sido resuelto previamente (liberado o revocado).';
    END IF;

    -- A) Insert Resolution Record
    INSERT INTO public.ledger_hold_resolutions (
        ledger_id, action, note, resolved_by
    ) VALUES (
        p_ledger_id, 'revoke', p_note, v_admin_id
    );

    -- B) Audit Log (No wallet update required since held amount was never added to wallet)
    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'revoke_held_pearls', 'ledger_entries', p_ledger_id::text,
        jsonb_build_object('fan_id', v_entry.fan_id, 'amount', v_entry.amount, 'note', p_note)
    );

    RETURN jsonb_build_object(
        'status', 'revoked',
        'ledger_id', p_ledger_id,
        'amount', v_entry.amount
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_risk_queue(p_resolved boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_res JSONB;
BEGIN
    PERFORM public.assert_admin();

    SELECT jsonb_agg(
        jsonb_build_object(
            'flag_id', rf.id,
            'fan_id', rf.fan_id,
            'display_name', p.display_name,
            'reason', rf.reason,
            'severity', rf.severity,
            'resolved', rf.resolved,
            'created_at', rf.created_at,
            'held_pearls', (
                SELECT COALESCE(SUM(le.amount), 0)
                FROM public.ledger_entries le
                WHERE le.fan_id = rf.fan_id
                  AND le.status = 'held'
                  AND NOT EXISTS (
                      SELECT 1 FROM public.ledger_hold_resolutions r WHERE r.ledger_id = le.id
                  )
            )
        ) ORDER BY rf.created_at DESC
    ) INTO v_res
    FROM public.risk_flags rf
    JOIN public.profiles p ON p.id = rf.fan_id
    WHERE rf.resolved = p_resolved;

    RETURN COALESCE(v_res, '[]'::jsonb);
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_suspend_fan(p_fan_id uuid, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.admin_toggle_staff_active(p_target_id uuid, p_active boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.admin_update_ads_settings(p_settings jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_enabled BOOLEAN;
    v_daily_views INT;
    v_block_size INT;
    v_min_sec INT;
    v_min_age INT;
    v_min_trivias INT;
    v_tiers JSONB;
    v_tier RECORD;
    v_old_settings JSONB;
    v_latest_id UUID;
BEGIN
    PERFORM public.assert_admin();

    v_enabled := COALESCE((p_settings->>'ads_enabled')::boolean, true);
    v_daily_views := COALESCE((p_settings->>'daily_ad_views')::int, 50);
    v_block_size := COALESCE((p_settings->>'block_size')::int, 10);
    v_min_sec := COALESCE((p_settings->>'ad_min_seconds')::int, 6);
    v_min_age := COALESCE((p_settings->>'ad_min_account_age_days')::int, 3);
    v_min_trivias := COALESCE((p_settings->>'ad_min_trivias_completed')::int, 1);
    v_tiers := p_settings->'reward_tiers';

    IF v_daily_views <= 0 OR v_block_size <= 0 OR v_min_sec <= 0 THEN
        RAISE EXCEPTION 'Los parámetros numéricos deben ser mayores a 0.';
    END IF;

    IF v_daily_views % v_block_size != 0 THEN
        RAISE EXCEPTION 'El límite diario (%) debe ser múltiplo del tamaño de bloque (%).', v_daily_views, v_block_size;
    END IF;

    -- Fetch latest economy settings row
    SELECT id, jsonb_build_object(
        'ads_enabled', ads_enabled,
        'daily_ad_views', daily_ad_views,
        'block_size', block_size,
        'ad_min_seconds', ad_min_seconds,
        'ad_min_account_age_days', ad_min_account_age_days,
        'ad_min_trivias_completed', ad_min_trivias_completed
    ) INTO v_latest_id, v_old_settings
    FROM public.economy_settings
    ORDER BY created_at DESC LIMIT 1;

    IF v_latest_id IS NOT NULL THEN
        -- Safe UPDATE targeting specific ID
        UPDATE public.economy_settings
        SET ads_enabled = v_enabled,
            daily_ad_views = v_daily_views,
            block_size = v_block_size,
            ad_min_seconds = v_min_sec,
            ad_min_account_age_days = v_min_age,
            ad_min_trivias_completed = v_min_trivias
        WHERE id = v_latest_id;
    ELSE
        -- Fallback INSERT if no economy settings existed
        INSERT INTO public.economy_settings (
            daily_pearl_cap,
            weekly_pearl_cap,
            streak_bonus_config,
            ads_enabled,
            daily_ad_views,
            block_size,
            ad_min_seconds,
            ad_min_account_age_days,
            ad_min_trivias_completed
        ) VALUES (
            500,
            2500,
            '{"streak_3_days": 100, "streak_7_days": 300}'::jsonb,
            v_enabled,
            v_daily_views,
            v_block_size,
            v_min_sec,
            v_min_age,
            v_min_trivias
        ) RETURNING id INTO v_latest_id;
    END IF;

    -- Update reward tiers if provided
    IF v_tiers IS NOT NULL AND jsonb_array_length(v_tiers) > 0 THEN
        FOR v_tier IN SELECT * FROM jsonb_to_recordset(v_tiers) AS x(block_number int, pearls int) LOOP
            IF v_tier.block_number IS NOT NULL AND v_tier.pearls IS NOT NULL AND v_tier.pearls > 0 THEN
                INSERT INTO public.ad_reward_tiers (block_number, pearls)
                VALUES (v_tier.block_number, v_tier.pearls)
                ON CONFLICT (block_number) DO UPDATE SET pearls = EXCLUDED.pearls, updated_at = NOW();
            END IF;
        END LOOP;
    END IF;

    -- Audit log entry
    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        v_admin_id, 'update_ads_settings', 'economy_settings', COALESCE(v_latest_id::text, '1'),
        v_old_settings, p_settings
    );

    RETURN jsonb_build_object('success', true);
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_update_birth_date(p_user_id uuid, p_birth_date date, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
BEGIN
    PERFORM public.assert_admin();

    IF p_user_id IS NULL OR p_birth_date IS NULL OR p_reason IS NULL OR TRIM(p_reason) = '' THEN
        RAISE EXCEPTION 'El usuario, la nueva fecha y el motivo son obligatorios.';
    END IF;

    UPDATE public.profiles
    SET birth_date = p_birth_date,
        updated_at = NOW()
    WHERE id = p_user_id;

    INSERT INTO public.audit_logs (actor_id, action, target_table, target_id, details)
    VALUES (
        auth.uid(),
        'admin_update_birth_date',
        'profiles',
        p_user_id::text,
        jsonb_build_object('new_birth_date', p_birth_date, 'reason', p_reason)
    );

    RETURN jsonb_build_object('success', true);
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_update_economy_settings(p_settings jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.admin_update_staff_role(p_target_id uuid, p_new_role staff_role)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.admin_upsert_game(p_game jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.admin_upsert_login_modal_slide(p_id uuid, p_position integer, p_image_url text, p_title text, p_subtitle text, p_cta_label text, p_cta_url text, p_status text, p_starts_at timestamp with time zone, p_ends_at timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_slide_id UUID;
    v_clean_title TEXT := TRIM(p_title);
    v_clean_subtitle TEXT := TRIM(COALESCE(p_subtitle, ''));
    v_clean_cta_label TEXT := COALESCE(NULLIF(TRIM(p_cta_label), ''), 'Ver más');
    v_status TEXT := COALESCE(p_status, 'draft');
BEGIN
    PERFORM public.assert_admin();
    PERFORM public.validate_login_modal_urls(p_image_url, p_cta_url);

    IF p_position < 1 OR p_position > 5 THEN
        RAISE EXCEPTION 'La posición de la diapositiva debe estar entre 1 y 5.';
    END IF;

    IF v_clean_title IS NULL OR v_clean_title = '' OR CHAR_LENGTH(v_clean_title) > 80 THEN
        RAISE EXCEPTION 'El título es obligatorio y debe tener como máximo 80 caracteres.';
    END IF;

    IF CHAR_LENGTH(v_clean_subtitle) > 160 THEN
        RAISE EXCEPTION 'El subtítulo no puede exceder 160 caracteres.';
    END IF;

    IF p_id IS NOT NULL THEN
        UPDATE public.login_modal_slides
        SET position = p_position,
            image_url = p_image_url,
            title = v_clean_title,
            subtitle = v_clean_subtitle,
            cta_label = v_clean_cta_label,
            cta_url = TRIM(p_cta_url),
            status = v_status,
            starts_at = COALESCE(p_starts_at, NOW()),
            ends_at = p_ends_at,
            updated_at = NOW()
        WHERE id = p_id;
        v_slide_id := p_id;
    ELSE
        INSERT INTO public.login_modal_slides (
            position, image_url, title, subtitle, cta_label, cta_url, status, starts_at, ends_at, created_by
        )
        VALUES (
            p_position, p_image_url, v_clean_title, v_clean_subtitle, v_clean_cta_label, TRIM(p_cta_url), v_status, COALESCE(p_starts_at, NOW()), p_ends_at, auth.uid()
        )
        RETURNING id INTO v_slide_id;
    END IF;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        auth.uid(),
        'admin_upsert_login_modal_slide',
        'login_modal_slides',
        v_slide_id::text,
        NULL,
        jsonb_build_object('title', v_clean_title, 'position', p_position, 'status', v_status)
    );

    RETURN jsonb_build_object('success', true, 'id', v_slide_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_upsert_player(p_player jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.admin_upsert_product(p_product jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.admin_upsert_segment(p_segment jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.admin_upsert_trivia(p_trivia jsonb, p_questions jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
            title, description, status, starts_at, ends_at, time_limit_seconds, reward_rules, max_attempts, target_segment_id
        ) VALUES (
            p_trivia->>'title',
            p_trivia->>'description',
            COALESCE((p_trivia->>'status')::trivia_status, 'draft'::trivia_status),
            (p_trivia->>'starts_at')::TIMESTAMPTZ,
            (p_trivia->>'ends_at')::TIMESTAMPTZ,
            COALESCE((p_trivia->>'time_limit_seconds')::INT, 60),
            COALESCE(p_trivia->'reward_rules', '{"per_correct_pearls": 50, "perfect_score_bonus": 100}'::jsonb),
            COALESCE((p_trivia->>'max_attempts')::INT, 1),
            NULLIF(p_trivia->>'target_segment_id', '')::UUID
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
            max_attempts = COALESCE((p_trivia->>'max_attempts')::INT, max_attempts),
            target_segment_id = CASE
                WHEN p_trivia ? 'target_segment_id' THEN NULLIF(p_trivia->>'target_segment_id', '')::UUID
                ELSE target_segment_id
            END
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
    VALUES (
        v_admin_id, 'admin_upsert_trivia', 'trivias', v_trivia_id::text,
        p_trivia
    );

    RETURN jsonb_build_object('success', true, 'id', v_trivia_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.analytics_active_users(p_start_date timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_date timestamp with time zone DEFAULT NULL::timestamp with time zone, p_granularity text DEFAULT 'day'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_start TIMESTAMPTZ := COALESCE(p_start_date, NOW() - INTERVAL '30 days');
    v_end TIMESTAMPTZ := COALESCE(p_end_date, NOW());
    v_gran TEXT := CASE WHEN p_granularity = 'month' THEN 'month' WHEN p_granularity = 'week' THEN 'week' ELSE 'day' END;
    v_step INTERVAL := CASE WHEN p_granularity = 'month' THEN '1 month' WHEN p_granularity = 'week' THEN '1 week' ELSE '1 day' END;
    v_result JSONB;
BEGIN
    PERFORM public.assert_admin();

    SELECT jsonb_agg(
        jsonb_build_object(
            'period', p.period_date,
            'active_users', COALESCE(a.active_users, 0),
            'new_registrations', COALESCE(r.new_registrations, 0)
        ) ORDER BY p.period_date
    ) INTO v_result
    FROM (
        SELECT generate_series(
            date_trunc(v_gran, (v_start AT TIME ZONE 'America/Caracas')),
            date_trunc(v_gran, (v_end AT TIME ZONE 'America/Caracas')),
            v_step
        )::date AS period_date
    ) p
    LEFT JOIN (
        SELECT
            date_trunc(v_gran, activity_date)::date AS period_date,
            COUNT(DISTINCT fan_id) AS active_users
        FROM public.mv_daily_fan_activity
        WHERE activity_date >= (v_start AT TIME ZONE 'America/Caracas')::date 
          AND activity_date <= (v_end AT TIME ZONE 'America/Caracas')::date
        GROUP BY 1
    ) a ON a.period_date = p.period_date
    LEFT JOIN (
        SELECT
            date_trunc(v_gran, (created_at AT TIME ZONE 'America/Caracas'))::date AS period_date,
            COUNT(*) AS new_registrations
        FROM public.profiles
        WHERE created_at >= v_start AND created_at <= v_end
        GROUP BY 1
    ) r ON r.period_date = p.period_date;

    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$function$;

CREATE OR REPLACE FUNCTION public.analytics_ads(p_from timestamp with time zone DEFAULT (now() - '30 days'::interval), p_to timestamp with time zone DEFAULT now())
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_total_started INT := 0;
    v_total_completed INT := 0;
    v_unique_users INT := 0;
    v_total_pearls_paid INT := 0;
    v_by_reason JSONB;
    v_cap_reached_users INT := 0;
    v_cap_percentage NUMERIC := 0;
    v_reconciliation JSONB;
BEGIN
    PERFORM public.assert_admin();

    SELECT COUNT(*) INTO v_total_started
    FROM public.ad_sessions WHERE started_at >= p_from AND started_at <= p_to;

    SELECT COUNT(*) INTO v_total_completed
    FROM public.ad_sessions WHERE status = 'completed' AND completed_at >= p_from AND completed_at <= p_to;

    SELECT COUNT(DISTINCT user_id) INTO v_unique_users
    FROM public.ad_sessions WHERE started_at >= p_from AND started_at <= p_to;

    SELECT COALESCE(SUM(amount), 0) INTO v_total_pearls_paid
    FROM public.ledger_entries
    WHERE type = 'ad_reward' AND created_at >= p_from AND created_at <= p_to AND status = 'confirmed';

    -- Cancellation by reason
    SELECT COALESCE(jsonb_object_agg(reason, count), '{}'::jsonb) INTO v_by_reason
    FROM (
        SELECT COALESCE(reason, status) AS reason, COUNT(*) AS count
        FROM public.ad_sessions
        WHERE status != 'completed' AND status != 'started' AND started_at >= p_from AND started_at <= p_to
        GROUP BY COALESCE(reason, status)
    ) x;

    -- Percentage of users hitting cap (50 views) at least once
    SELECT COUNT(DISTINCT user_id) INTO v_cap_reached_users
    FROM public.ad_daily_progress
    WHERE completed_count >= 50 AND created_at >= p_from AND created_at <= p_to;

    IF v_unique_users > 0 THEN
        v_cap_percentage := round((v_cap_reached_users::numeric / v_unique_users::numeric) * 100, 1);
    END IF;

    -- Reconciliation summary by day
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'day', r.day,
            'google_impressions', r.google_rewarded_impressions,
            'db_completed', (SELECT COUNT(*) FROM public.ad_sessions s WHERE s.day = r.day AND s.status = 'completed'),
            'imported_at', r.imported_at,
            'notes', r.notes
        ) ORDER BY r.day DESC
    ), '[]'::jsonb) INTO v_reconciliation
    FROM public.ad_reconciliation r
    WHERE r.day >= p_from::date AND r.day <= p_to::date;

    RETURN jsonb_build_object(
        'period_from', p_from,
        'period_to', p_to,
        'sessions_started', v_total_started,
        'sessions_completed', v_total_completed,
        'unique_fans', v_unique_users,
        'pearls_paid', v_total_pearls_paid,
        'cancellations_by_reason', v_by_reason,
        'fans_hitting_cap', v_cap_reached_users,
        'cap_percentage', v_cap_percentage,
        'reconciliation_history', v_reconciliation
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.analytics_demographics()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_municipality JSONB;
    v_gender JSONB;
    v_age_groups JSONB;
BEGIN
    PERFORM public.assert_admin();

    -- Municipality (Groups with < 5 count merged into "Otros / Grupos Pequeños")
    SELECT jsonb_agg(
        jsonb_build_object(
            'name', group_name,
            'count', total_count
        ) ORDER BY total_count DESC
    ) INTO v_municipality
    FROM (
        SELECT
            CASE WHEN fan_count >= 5 THEN municipality ELSE 'Otros (< 5)' END AS group_name,
            SUM(fan_count) AS total_count
        FROM public.mv_demographics
        GROUP BY 1
    ) sub;

    -- Gender
    SELECT jsonb_agg(
        jsonb_build_object(
            'name', group_name,
            'count', total_count
        ) ORDER BY total_count DESC
    ) INTO v_gender
    FROM (
        SELECT
            CASE WHEN fan_count >= 5 THEN gender ELSE 'Otros (< 5)' END AS group_name,
            SUM(fan_count) AS total_count
        FROM public.mv_demographics
        GROUP BY 1
    ) sub;

    -- Age Groups
    SELECT jsonb_agg(
        jsonb_build_object(
            'name', group_name,
            'count', total_count
        ) ORDER BY total_count DESC
    ) INTO v_age_groups
    FROM (
        SELECT
            CASE WHEN fan_count >= 5 THEN age_group ELSE 'Otros (< 5)' END AS group_name,
            SUM(fan_count) AS total_count
        FROM public.mv_demographics
        GROUP BY 1
    ) sub;

    RETURN jsonb_build_object(
        'by_municipality', COALESCE(v_municipality, '[]'::jsonb),
        'by_gender', COALESCE(v_gender, '[]'::jsonb),
        'by_age_group', COALESCE(v_age_groups, '[]'::jsonb)
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.analytics_economy()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_total_issued BIGINT;
    v_total_spent BIGINT;
    v_total_in_circulation BIGINT;
    v_total_held BIGINT;
    v_min_product_cost INT;
    v_max_product_cost INT;
    v_avg_daily_earnings_per_fan NUMERIC;
    v_days_for_cheapest NUMERIC;
    v_days_for_most_expensive NUMERIC;
BEGIN
    PERFORM public.assert_admin();

    -- Issued, Spent & Pending Held from Ledger
    SELECT
        COALESCE(SUM(CASE WHEN amount > 0 AND status = 'confirmed' THEN amount ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN amount < 0 AND status = 'confirmed' THEN ABS(amount) ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN status = 'held' AND NOT EXISTS (SELECT 1 FROM public.ledger_hold_resolutions r WHERE r.ledger_id = le.id) THEN amount ELSE 0 END), 0)
    INTO v_total_issued, v_total_spent, v_total_held
    FROM public.ledger_entries le;

    -- In Circulation from Wallets Cache
    SELECT COALESCE(SUM(balance_cache), 0) INTO v_total_in_circulation
    FROM public.wallets;

    -- Product cost bounds
    SELECT MIN(cost_pearls), MAX(cost_pearls)
    INTO v_min_product_cost, v_max_product_cost
    FROM public.products
    WHERE active = true;

    -- Average daily earnings per active fan
    SELECT COALESCE(AVG(pearls_earned), 50.0)
    INTO v_avg_daily_earnings_per_fan
    FROM (
        SELECT fan_id, SUM(pearls_awarded) AS pearls_earned
        FROM public.trivia_attempts
        WHERE submitted_at >= NOW() - INTERVAL '30 days'
        GROUP BY fan_id
    ) sub;

    IF v_avg_daily_earnings_per_fan <= 0 THEN
        v_avg_daily_earnings_per_fan := 50.0;
    END IF;

    v_days_for_cheapest := ROUND((COALESCE(v_min_product_cost, 0)::NUMERIC / v_avg_daily_earnings_per_fan), 1);
    v_days_for_most_expensive := ROUND((COALESCE(v_max_product_cost, 0)::NUMERIC / v_avg_daily_earnings_per_fan), 1);

    RETURN jsonb_build_object(
        'total_issued', v_total_issued,
        'total_spent', v_total_spent,
        'total_in_circulation', v_total_in_circulation,
        'total_held', v_total_held,
        'min_product_cost', v_min_product_cost,
        'max_product_cost', v_max_product_cost,
        'avg_daily_earnings_per_fan', v_avg_daily_earnings_per_fan,
        'days_for_cheapest_product', v_days_for_cheapest,
        'days_for_most_expensive_product', v_days_for_most_expensive
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.analytics_engagement_hours(p_start_date timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_date timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_start TIMESTAMPTZ := COALESCE(p_start_date, NOW() - INTERVAL '30 days');
    v_end TIMESTAMPTZ := COALESCE(p_end_date, NOW());
    v_result JSONB;
BEGIN
    PERFORM public.assert_admin();

    -- Matrix 7 x 24: [day_of_week (0=Sun, 6=Sat), hour (0-23), count]
    SELECT jsonb_agg(
        jsonb_build_array(day_of_week, hour_of_day, activity_count)
    ) INTO v_result
    FROM (
        SELECT
            EXTRACT(DOW FROM (started_at AT TIME ZONE 'America/Caracas'))::INT AS day_of_week,
            EXTRACT(HOUR FROM (started_at AT TIME ZONE 'America/Caracas'))::INT AS hour_of_day,
            COUNT(*) AS activity_count
        FROM public.trivia_attempts
        WHERE started_at >= v_start AND started_at <= v_end
        GROUP BY 1, 2
        ORDER BY 1, 2
    ) sub;

    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$function$;

CREATE OR REPLACE FUNCTION public.analytics_funnel(p_start_date timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_date timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_start TIMESTAMPTZ := COALESCE(p_start_date, NOW() - INTERVAL '30 days');
    v_end TIMESTAMPTZ := COALESCE(p_end_date, NOW());
    v_total_registered INT := 0;
    v_email_verified INT := 0;
    v_first_trivia INT := 0;
    v_first_redemption INT := 0;
BEGIN
    PERFORM public.assert_admin();

    -- Step 1: Registered in cohort (registered between v_start and v_end)
    SELECT COUNT(*) INTO v_total_registered
    FROM public.profiles
    WHERE created_at >= v_start AND created_at <= v_end;

    -- Step 2: Email Verified in cohort
    SELECT COUNT(p.id) INTO v_email_verified
    FROM public.profiles p
    JOIN auth.users u ON u.id = p.id
    WHERE p.created_at >= v_start AND p.created_at <= v_end
      AND (u.email_confirmed_at IS NOT NULL OR u.confirmed_at IS NOT NULL);

    -- Step 3: Played at least 1 Trivia in cohort
    SELECT COUNT(DISTINCT p.id) INTO v_first_trivia
    FROM public.profiles p
    JOIN public.trivia_attempts ta ON ta.fan_id = p.id AND ta.submitted_at IS NOT NULL
    WHERE p.created_at >= v_start AND p.created_at <= v_end;

    -- Step 4: Performed at least 1 Redemption in cohort
    SELECT COUNT(DISTINCT p.id) INTO v_first_redemption
    FROM public.profiles p
    JOIN public.redemptions r ON r.fan_id = p.id
    WHERE p.created_at >= v_start AND p.created_at <= v_end;

    RETURN jsonb_build_array(
        jsonb_build_object('step', 1, 'name', 'Registrados', 'count', v_total_registered, 'conversion_rate', 100.0),
        jsonb_build_object(
            'step', 2, 'name', 'Correo Verificado', 'count', v_email_verified,
            'conversion_rate', ROUND((v_email_verified::NUMERIC / NULLIF(v_total_registered, 0) * 100.0), 1)
        ),
        jsonb_build_object(
            'step', 3, 'name', 'Primera Trivia Jugada', 'count', v_first_trivia,
            'conversion_rate', ROUND((v_first_trivia::NUMERIC / NULLIF(v_total_registered, 0) * 100.0), 1)
        ),
        jsonb_build_object(
            'step', 4, 'name', 'Primer Canje Realizado', 'count', v_first_redemption,
            'conversion_rate', ROUND((v_first_redemption::NUMERIC / NULLIF(v_total_registered, 0) * 100.0), 1)
        )
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.analytics_overview(p_start_date timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_date timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_start TIMESTAMPTZ := COALESCE(p_start_date, NOW() - INTERVAL '30 days');
    v_end TIMESTAMPTZ := COALESCE(p_end_date, NOW());
    v_dau INT;
    v_wau INT;
    v_mau INT;
    v_new_registrations INT;
    v_pearls_issued BIGINT;
    v_pearls_spent BIGINT;
    v_redemptions_by_status JSONB;
    v_avg_fulfillment_hours NUMERIC;
BEGIN
    PERFORM public.assert_admin();

    -- DAU (Today in Caracas)
    SELECT COUNT(DISTINCT fan_id) INTO v_dau
    FROM public.mv_daily_fan_activity
    WHERE activity_date = (NOW() AT TIME ZONE 'America/Caracas')::DATE;

    -- WAU (Last 7 days)
    SELECT COUNT(DISTINCT fan_id) INTO v_wau
    FROM public.mv_daily_fan_activity
    WHERE activity_date >= ((NOW() AT TIME ZONE 'America/Caracas')::DATE - INTERVAL '7 days')::DATE;

    -- MAU (Last 30 days)
    SELECT COUNT(DISTINCT fan_id) INTO v_mau
    FROM public.mv_daily_fan_activity
    WHERE activity_date >= ((NOW() AT TIME ZONE 'America/Caracas')::DATE - INTERVAL '30 days')::DATE;

    -- New registrations in date range
    SELECT COUNT(*) INTO v_new_registrations
    FROM public.profiles
    WHERE created_at >= v_start AND created_at <= v_end;

    -- Pearls issued vs spent
    SELECT
        COALESCE(SUM(CASE WHEN amount > 0 AND status = 'confirmed' THEN amount ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN amount < 0 AND status = 'confirmed' THEN ABS(amount) ELSE 0 END), 0)
    INTO v_pearls_issued, v_pearls_spent
    FROM public.ledger_entries
    WHERE created_at >= v_start AND created_at <= v_end;

    -- Redemptions breakdown by status
    SELECT jsonb_object_agg(COALESCE(status::text, 'unknown'), cnt)
    INTO v_redemptions_by_status
    FROM (
        SELECT status, COUNT(*) AS cnt
        FROM public.redemptions
        WHERE created_at >= v_start AND created_at <= v_end
        GROUP BY status
    ) sub;

    -- Average fulfillment time (Approved to Delivered in hours)
    SELECT ROUND(AVG(EXTRACT(EPOCH FROM (delivered_at - approved_at)) / 3600.0)::NUMERIC, 2)
    INTO v_avg_fulfillment_hours
    FROM public.redemptions
    WHERE delivered_at IS NOT NULL AND approved_at IS NOT NULL
      AND created_at >= v_start AND created_at <= v_end;

    RETURN jsonb_build_object(
        'dau', COALESCE(v_dau, 0),
        'wau', COALESCE(v_wau, 0),
        'mau', COALESCE(v_mau, 0),
        'new_registrations', v_new_registrations,
        'pearls_issued', v_pearls_issued,
        'pearls_spent', v_pearls_spent,
        'redemptions_by_status', COALESCE(v_redemptions_by_status, '{}'::jsonb),
        'avg_fulfillment_hours', COALESCE(v_avg_fulfillment_hours, 0)
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.analytics_products(p_start_date timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_date timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_start TIMESTAMPTZ := COALESCE(p_start_date, NOW() - INTERVAL '30 days');
    v_end TIMESTAMPTZ := COALESCE(p_end_date, NOW());
    v_top_products JSONB;
    v_low_stock JSONB;
BEGIN
    PERFORM public.assert_admin();

    -- Top redeemed products
    SELECT jsonb_agg(
        jsonb_build_object(
            'product_id', product_id,
            'name', name,
            'cost_pearls', cost_pearls,
            'redemptions_count', redemptions_count,
            'total_pearls_spent', total_pearls_spent
        ) ORDER BY redemptions_count DESC
    ) INTO v_top_products
    FROM (
        SELECT
            p.id AS product_id,
            p.name,
            p.cost_pearls,
            COUNT(r.id) AS redemptions_count,
            COALESCE(SUM(r.cost_pearls), 0) AS total_pearls_spent
        FROM public.products p
        LEFT JOIN public.redemptions r ON r.product_id = p.id AND r.created_at >= v_start AND r.created_at <= v_end
        GROUP BY p.id, p.name, p.cost_pearls
    ) sub;

    -- Low stock alerts (stock <= 3)
    SELECT jsonb_agg(
        jsonb_build_object(
            'product_id', id,
            'name', name,
            'stock', stock,
            'active', active
        ) ORDER BY stock ASC
    ) INTO v_low_stock
    FROM public.products
    WHERE stock <= 3 AND active = true;

    RETURN jsonb_build_object(
        'top_products', COALESCE(v_top_products, '[]'::jsonb),
        'low_stock_alerts', COALESCE(v_low_stock, '[]'::jsonb)
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.analytics_top_fans(p_limit integer DEFAULT 10, p_start_date timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_date timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_start TIMESTAMPTZ := COALESCE(p_start_date, NOW() - INTERVAL '30 days');
    v_end TIMESTAMPTZ := COALESCE(p_end_date, NOW());
    v_result JSONB;
BEGIN
    PERFORM public.assert_admin();

    SELECT jsonb_agg(
        jsonb_build_object(
            'fan_id', fan_id,
            'display_name', display_name,
            'avatar_url', avatar_url,
            'trivias_played', trivias_played,
            'pearls_earned', pearls_earned
        ) ORDER BY pearls_earned DESC
    ) INTO v_result
    FROM (
        SELECT
            p.id AS fan_id,
            p.display_name,
            p.avatar_url,
            COUNT(DISTINCT ta.id) AS trivias_played,
            COALESCE(SUM(ta.pearls_awarded), 0) AS pearls_earned
        FROM public.profiles p
        JOIN public.trivia_attempts ta ON ta.fan_id = p.id
        WHERE ta.submitted_at IS NOT NULL
          AND ta.started_at >= v_start AND ta.started_at <= v_end
          AND p.status = 'active'
        GROUP BY p.id, p.display_name, p.avatar_url
        ORDER BY pearls_earned DESC
        LIMIT LEAST(GREATEST(p_limit, 1), 100)
    ) sub;

    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$function$;

CREATE OR REPLACE FUNCTION public.analytics_trivias(p_start_date timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_date timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_start TIMESTAMPTZ := COALESCE(p_start_date, NOW() - INTERVAL '30 days');
    v_end TIMESTAMPTZ := COALESCE(p_end_date, NOW());
    v_popular JSONB;
    v_hardest_questions JSONB;
BEGIN
    PERFORM public.assert_admin();

    -- Trivias summary
    SELECT jsonb_agg(
        jsonb_build_object(
            'trivia_id', trivia_id,
            'title', title,
            'attempts_count', attempts_count,
            'avg_score', avg_score,
            'completion_rate', completion_rate
        ) ORDER BY attempts_count DESC
    ) INTO v_popular
    FROM (
        SELECT
            t.id AS trivia_id,
            t.title,
            COUNT(ta.id) AS attempts_count,
            ROUND(AVG(ta.score)::NUMERIC, 1) AS avg_score,
            ROUND(
                (COUNT(CASE WHEN ta.submitted_at IS NOT NULL THEN 1 END)::NUMERIC / NULLIF(COUNT(ta.id), 0) * 100)::NUMERIC,
                1
            ) AS completion_rate
        FROM public.trivias t
        LEFT JOIN public.trivia_attempts ta ON ta.trivia_id = t.id AND ta.started_at >= v_start AND ta.started_at <= v_end
        GROUP BY t.id, t.title
    ) sub;

    -- Hardest questions (lowest correct rate evaluated against trivia_options.is_correct)
    SELECT jsonb_agg(
        jsonb_build_object(
            'question_id', question_id,
            'trivia_title', trivia_title,
            'question_text', question_text,
            'total_answers', total_answers,
            'correct_rate', correct_rate
        ) ORDER BY correct_rate ASC
    ) INTO v_hardest_questions
    FROM (
        SELECT
            q.id AS question_id,
            t.title AS trivia_title,
            q.question_text,
            COUNT(ta.id) AS total_answers,
            ROUND(
                (COUNT(CASE WHEN o.is_correct IS TRUE THEN 1 END)::NUMERIC / NULLIF(COUNT(ta.id), 0) * 100)::NUMERIC,
                1
            ) AS correct_rate
        FROM public.trivia_questions q
        JOIN public.trivias t ON t.id = q.trivia_id
        JOIN public.trivia_attempts ta ON ta.trivia_id = t.id AND ta.submitted_at IS NOT NULL
        LEFT JOIN public.trivia_options o 
          ON o.id = (ta.answers->>(q.id::text))::uuid 
         AND o.question_id = q.id
        WHERE ta.started_at >= v_start AND ta.started_at <= v_end
        GROUP BY q.id, t.title, q.question_text
        HAVING COUNT(ta.id) > 0
        ORDER BY correct_rate ASC
        LIMIT 5
    ) sub;

    RETURN jsonb_build_object(
        'popular_trivias', COALESCE(v_popular, '[]'::jsonb),
        'hardest_questions', COALESCE(v_hardest_questions, '[]'::jsonb)
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.approve_redemption(p_redemption_id uuid, p_note text DEFAULT 'Canje aprobado por staff'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_staff_id UUID := auth.uid();
    v_redemption redemptions%ROWTYPE;
BEGIN
    IF NOT is_staff_or_admin(v_staff_id) THEN
        RAISE EXCEPTION 'Staff or Admin authorization required.';
    END IF;

    SELECT * INTO v_redemption FROM redemptions WHERE id = p_redemption_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Redemption not found.';
    END IF;

    IF v_redemption.status != 'pending' THEN
        RAISE EXCEPTION 'Solo los canjes pendientes pueden ser aprobados. Estado actual: %', v_redemption.status;
    END IF;

    UPDATE redemptions
    SET status = 'approved',
        approved_by = v_staff_id,
        approved_at = NOW()
    WHERE id = v_redemption.id;

    INSERT INTO redemption_history (redemption_id, previous_status, new_status, changed_by, note)
    VALUES (v_redemption.id, 'pending', 'approved', v_staff_id, COALESCE(p_note, 'Aprobado por staff'));

    PERFORM public.create_notification(
        v_redemption.fan_id,
        'redemption_approved',
        '¡Tu canje fue aprobado!',
        'Tu código QR ya está disponible en tus canjes para la entrega.',
        jsonb_build_object('redemption_id', v_redemption.id, 'url', '/app/canjes/' || v_redemption.id),
        'redemption_approved_' || v_redemption.id
    );

    RETURN jsonb_build_object(
        'redemption_id', v_redemption.id,
        'status', 'approved'
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.assert_min_admins()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_count INT;
BEGIN
    -- Check active admins count
    SELECT COUNT(*) INTO v_admin_count
    FROM public.staff_members
    WHERE role = 'admin' AND active = true;

    IF v_admin_count < 2 THEN
        RAISE EXCEPTION 'Operación denegada: debe existir siempre al menos 2 administradores activos en el sistema.' USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.audit_search(p_actor_id uuid DEFAULT NULL::uuid, p_action text DEFAULT NULL::text, p_entity text DEFAULT NULL::text, p_from timestamp with time zone DEFAULT NULL::timestamp with time zone, p_to timestamp with time zone DEFAULT NULL::timestamp with time zone, p_limit integer DEFAULT 50, p_cursor uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.calculate_and_apply_streak_bonus(p_fan_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_today DATE := (NOW() AT TIME ZONE 'America/Caracas')::date;
    v_already_awarded BOOLEAN;
    v_streak_days INT := 0;
    v_day_check DATE;
    v_bonus_amount INT := 0;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM ledger_entries
        WHERE fan_id = p_fan_id
          AND type = 'streak_bonus'
          AND (created_at AT TIME ZONE 'America/Caracas')::date = v_today
    ) INTO v_already_awarded;

    -- Calculate consecutive days up to today in Caracas timezone
    v_day_check := v_today;
    LOOP
        IF EXISTS (
            SELECT 1 FROM trivia_attempts
            WHERE fan_id = p_fan_id
              AND submitted_at IS NOT NULL
              AND (submitted_at AT TIME ZONE 'America/Caracas')::date = v_day_check
        ) THEN
            v_streak_days := v_streak_days + 1;
            v_day_check := v_day_check - INTERVAL '1 day';
        ELSE
            EXIT;
        END IF;
    END LOOP;

    IF v_already_awarded THEN
        RETURN jsonb_build_object('streak_days', v_streak_days, 'bonus_awarded', 0, 'already_awarded_today', true);
    END IF;

    -- Award milestone bonus
    IF v_streak_days >= 7 THEN
        v_bonus_amount := 300;
    ELSIF v_streak_days >= 3 THEN
        v_bonus_amount := 100;
    ELSIF v_streak_days >= 1 THEN
        v_bonus_amount := 20;
    END IF;

    IF v_bonus_amount > 0 THEN
        INSERT INTO ledger_entries (
            fan_id, amount, type, status, source_type, source_id, note
        ) VALUES (
            p_fan_id, v_bonus_amount, 'streak_bonus', 'confirmed', 'streak', v_today::text || '-' || v_streak_days,
            'Bono de racha diaria (' || v_streak_days || ' días consecutivos)'
        ) ON CONFLICT DO NOTHING;

        INSERT INTO wallets (fan_id, balance_cache)
        VALUES (p_fan_id, v_bonus_amount)
        ON CONFLICT (fan_id)
        DO UPDATE SET balance_cache = wallets.balance_cache + v_bonus_amount, updated_at = NOW();
    END IF;

    RETURN jsonb_build_object(
        'streak_days', v_streak_days,
        'bonus_awarded', v_bonus_amount,
        'already_awarded_today', false
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.cancel_ad_session(p_session_id uuid, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid UUID := auth.uid();
    v_valid_reasons TEXT[] := ARRAY['declined', 'no_fill', 'closed_early', 'error'];
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    IF NOT (p_reason = ANY(v_valid_reasons)) THEN
        RAISE EXCEPTION 'Motivo de cancelación no válido.';
    END IF;

    UPDATE public.ad_sessions
    SET status = p_reason, reason = p_reason
    WHERE id = p_session_id AND user_id = v_uid AND status = 'started';

    RETURN jsonb_build_object('success', true, 'session_id', p_session_id, 'status', p_reason);
END;
$function$;

CREATE OR REPLACE FUNCTION public.cancel_redemption(p_redemption_id uuid, p_reason text DEFAULT 'Cancelado por el usuario'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_actor_id UUID := auth.uid();
    v_redemption redemptions%ROWTYPE;
    v_is_owner BOOLEAN;
BEGIN
    IF v_actor_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT * INTO v_redemption FROM redemptions WHERE id = p_redemption_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Redemption not found.';
    END IF;

    v_is_owner := (v_redemption.fan_id = v_actor_id);

    IF v_is_owner THEN
        IF v_redemption.status != 'pending' THEN
            RAISE EXCEPTION 'Solo puedes cancelar canjes en estado pendiente. Estado actual: %', v_redemption.status;
        END IF;
    ELSE
        IF NOT is_staff_or_admin(v_actor_id) THEN
            RAISE EXCEPTION 'No tienes permisos para cancelar este canje.';
        END IF;
        IF v_redemption.status IN ('delivered', 'completed', 'cancelled', 'rejected') THEN
            RAISE EXCEPTION 'No se puede cancelar un canje en estado %', v_redemption.status;
        END IF;
    END IF;

    UPDATE redemptions SET status = 'cancelled' WHERE id = v_redemption.id;

    INSERT INTO ledger_entries (
        fan_id, amount, type, status, source_type, source_id, note, created_by
    ) VALUES (
        v_redemption.fan_id, v_redemption.cost_pearls, 'refund', 'confirmed',
        'redemption', v_redemption.id::text,
        'Reembolso por cancelación de canje: ' || COALESCE(p_reason, 'Sin motivo'),
        v_actor_id
    );

    UPDATE wallets
    SET balance_cache = balance_cache + v_redemption.cost_pearls, updated_at = NOW()
    WHERE fan_id = v_redemption.fan_id;

    UPDATE products SET stock = stock + 1 WHERE id = v_redemption.product_id;

    INSERT INTO redemption_history (redemption_id, previous_status, new_status, changed_by, note)
    VALUES (v_redemption.id, v_redemption.status, 'cancelled', v_actor_id, COALESCE(p_reason, 'Cancelado'));

    INSERT INTO audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        v_actor_id, 'cancel_redemption', 'redemptions', v_redemption.id::text,
        jsonb_build_object('status', v_redemption.status, 'cost_pearls', v_redemption.cost_pearls),
        jsonb_build_object('status', 'cancelled', 'reason', p_reason, 'refunded_pearls', v_redemption.cost_pearls)
    );

    PERFORM public.create_notification(
        v_redemption.fan_id,
        'redemption_cancelled',
        'Canje cancelado',
        'Se ha cancelado tu canje y tus perlitas han sido reembolsadas.',
        jsonb_build_object('redemption_id', v_redemption.id, 'url', '/app/canjes/' || v_redemption.id),
        'redemption_cancelled_' || v_redemption.id
    );

    RETURN jsonb_build_object(
        'redemption_id', v_redemption.id,
        'status', 'cancelled',
        'refunded_pearls', v_redemption.cost_pearls
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.check_in_redemption(p_redemption_id uuid, p_idempotency_key text, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_staff_id UUID := auth.uid();
    v_redemption public.redemptions%ROWTYPE;
    v_deliv_name TEXT;
BEGIN
    PERFORM assert_staff();

    IF p_idempotency_key IS NULL OR trim(p_idempotency_key) = '' THEN
        RAISE EXCEPTION 'Idempotency key is required for check-in.';
    END IF;

    SELECT * INTO v_redemption
    FROM public.redemptions
    WHERE id = p_redemption_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Canje no encontrado.';
    END IF;

    IF v_redemption.status = 'completed' OR v_redemption.delivery_idempotency_key = p_idempotency_key THEN
        SELECT display_name INTO v_deliv_name FROM public.profiles WHERE id = v_redemption.delivered_by;
        RETURN jsonb_build_object(
            'result', 'ALREADY_DELIVERED',
            'status', v_redemption.status,
            'delivered_at', v_redemption.delivered_at,
            'delivered_by_name', COALESCE(v_deliv_name, 'Personal de Staff')
        );
    END IF;

    IF v_redemption.status NOT IN ('scheduled', 'approved') THEN
        RAISE EXCEPTION 'Solo se puede registrar asistencia para experiencias agendadas o aprobadas. Estado actual: %', v_redemption.status;
    END IF;

    UPDATE public.redemptions
    SET status = 'completed',
        delivered_by = v_staff_id,
        delivered_at = NOW(),
        delivery_idempotency_key = p_idempotency_key
    WHERE id = v_redemption.id AND status IN ('scheduled', 'approved');

    INSERT INTO public.redemption_history (redemption_id, previous_status, new_status, changed_by, note)
    VALUES (v_redemption.id, v_redemption.status, 'completed', v_staff_id, COALESCE(p_note, 'Asistencia a experiencia registrada'));

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        v_staff_id,
        'check_in_redemption',
        'redemptions',
        v_redemption.id::text,
        jsonb_build_object('status', v_redemption.status),
        jsonb_build_object('status', 'completed', 'idempotency_key', p_idempotency_key)
    );

    SELECT display_name INTO v_deliv_name FROM public.profiles WHERE id = v_staff_id;

    RETURN jsonb_build_object(
        'result', 'SUCCESS',
        'status', 'completed',
        'delivered_at', NOW(),
        'delivered_by_name', v_deliv_name
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.check_max_5_published_login_modal_slides()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_published_count INT;
BEGIN
    IF NEW.status = 'published' AND (NEW.ends_at IS NULL OR NEW.ends_at >= NOW()) THEN
        SELECT COUNT(*) INTO v_published_count
        FROM public.login_modal_slides
        WHERE status = 'published'
          AND (ends_at IS NULL OR ends_at >= NOW())
          AND id != NEW.id;

        IF v_published_count >= 5 THEN
            RAISE EXCEPTION 'No se pueden publicar más de 5 diapositivas vigentes al mismo tiempo.' USING ERRCODE = '23514';
        END IF;
    END IF;

    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.check_rate_limit(p_user_id uuid, p_action text, p_max integer, p_window_seconds integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_now TIMESTAMPTZ := NOW();
    v_window_start TIMESTAMPTZ := to_timestamp(floor(EXTRACT(EPOCH FROM v_now) / p_window_seconds) * p_window_seconds);
    v_count INT;
BEGIN
    INSERT INTO public.rate_limits (user_id, action, window_start, request_count)
    VALUES (p_user_id, p_action, v_window_start, 1)
    ON CONFLICT (user_id, action, window_start)
    DO UPDATE SET request_count = rate_limits.request_count + 1
    RETURNING request_count INTO v_count;

    IF v_count > p_max THEN
        RAISE EXCEPTION 'RATE_LIMITED';
    END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.claim_birthday_bonus()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_user_id UUID;
    v_profile public.profiles%ROWTYPE;
    v_settings public.birthday_settings%ROWTYPE;
    v_card JSONB;
    v_cur_year INT;
    v_bonus INT;
    v_ref_id TEXT;
    v_claimed BOOLEAN;
    v_wallet wallets%ROWTYPE;
    v_entry_id UUID;
BEGIN
    v_user_id := public.assert_active_verified_fan();

    SELECT * INTO v_profile FROM public.profiles WHERE id = v_user_id;

    -- Account age check (>= 30 days)
    IF v_profile.created_at > NOW() - INTERVAL '30 days' THEN
        RAISE EXCEPTION 'El bono de cumpleaños requiere una cuenta con al menos 30 días de antigüedad.';
    END IF;

    v_card := public.get_birthday_card();
    IF (v_card->>'eligible')::boolean IS NOT TRUE THEN
        RAISE EXCEPTION 'No eres elegible para reclamar un bono de cumpleaños hoy.';
    END IF;

    v_bonus := COALESCE((v_card->>'bonus_pearls')::int, 0);
    IF v_bonus <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'La campaña no contempla bono de perlitas.');
    END IF;

    IF (v_card->>'has_claimed_bonus')::boolean IS TRUE THEN
        RETURN jsonb_build_object('success', true, 'message', 'El bono de cumpleaños ya fue reclamado previamente este año.', 'already_claimed', true);
    END IF;

    v_cur_year := EXTRACT(YEAR FROM (NOW() AT TIME ZONE 'America/Caracas'))::int;
    v_ref_id := 'birthday_bonus_' || v_user_id::text || '_' || v_cur_year::text;

    -- Atomic Ledger Entry Insertion
    INSERT INTO public.ledger_entries (user_id, pearls, entry_type, description, reference_id)
    VALUES (
        v_user_id,
        v_bonus,
        'confirmed',
        'Bono de Cumpleaños ' || v_cur_year::text,
        v_ref_id
    )
    RETURNING id INTO v_entry_id;

    -- Update wallet cache
    UPDATE public.wallets
    SET confirmed_balance = confirmed_balance + v_bonus,
        updated_at = NOW()
    WHERE fan_id = v_user_id;

    RETURN jsonb_build_object('success', true, 'claimed_pearls', v_bonus);
END;
$function$;

CREATE OR REPLACE FUNCTION public.complete_ad_session(p_session_id uuid, p_idempotency_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid UUID;
    v_today DATE := (NOW() AT TIME ZONE 'America/Caracas')::date;
    v_session public.ad_sessions%ROWTYPE;
    v_eco RECORD;
    v_elapsed NUMERIC;
    v_new_count INT;
    v_block_index INT;
    v_pearls_tier INT := 0;
    v_source_id TEXT;
    v_is_held BOOLEAN := false;
    v_risk_level TEXT := 'low';
    v_ledger_status ledger_status := 'confirmed';
    v_ledger_id UUID := gen_random_uuid();
    v_paid BOOLEAN := false;
BEGIN
    v_uid := public.assert_active_verified_fan();

    SELECT * INTO v_session FROM public.ad_sessions WHERE id = p_session_id FOR UPDATE;
    IF NOT FOUND OR v_session.user_id != v_uid THEN
        RAISE EXCEPTION 'Sesión de anuncio no encontrada o no pertenece al usuario.';
    END IF;

    -- Idempotency check if already completed
    IF v_session.status = 'completed' THEN
        SELECT completed_count INTO v_new_count FROM public.ad_daily_progress WHERE user_id = v_uid AND day = v_today;
        RETURN jsonb_build_object(
            'status', 'already_completed',
            'session_id', p_session_id,
            'completed_today', COALESCE(v_new_count, 0)
        );
    END IF;

    IF v_session.status != 'started' THEN
        RAISE EXCEPTION 'La sesión ya no está en estado activo (%)..', v_session.status;
    END IF;

    SELECT daily_ad_views, block_size, ad_min_seconds INTO v_eco
    FROM public.economy_settings
    ORDER BY created_at DESC LIMIT 1;

    -- Time validation against SERVER clock
    v_elapsed := EXTRACT(EPOCH FROM (NOW() - v_session.started_at));

    IF v_elapsed < v_eco.ad_min_seconds THEN
        UPDATE public.ad_sessions SET status = 'error', reason = 'timing_too_fast' WHERE id = p_session_id;
        RAISE EXCEPTION 'El anuncio fue completado demasiado rápido (% s vs min % s).', round(v_elapsed, 1), v_eco.ad_min_seconds;
    END IF;

    IF v_elapsed > 600 THEN
        UPDATE public.ad_sessions SET status = 'expired', reason = 'exceeded_10_minutes' WHERE id = p_session_id;
        RAISE EXCEPTION 'La sesión de anuncio ha expirado por inactividad.';
    END IF;

    -- Mark session as completed
    UPDATE public.ad_sessions
    SET status = 'completed', completed_at = NOW()
    WHERE id = p_session_id AND status = 'started';

    -- Lock daily progress and increment count
    INSERT INTO public.ad_daily_progress (user_id, day, completed_count)
    VALUES (v_uid, v_today, 1)
    ON CONFLICT (user_id, day) DO UPDATE
    SET completed_count = LEAST(ad_daily_progress.completed_count + 1, 50),
        updated_at = NOW()
    RETURNING completed_count INTO v_new_count;

    -- Check if block reward is triggered
    IF v_new_count % v_eco.block_size = 0 THEN
        v_block_index := v_new_count / v_eco.block_size;
        
        -- Update block index in session
        UPDATE public.ad_sessions SET block_index = v_block_index WHERE id = p_session_id;

        -- Fetch block reward amount
        SELECT pearls INTO v_pearls_tier FROM public.ad_reward_tiers WHERE block_number = v_block_index;
        IF v_pearls_tier IS NULL THEN
            v_pearls_tier := 5 * v_block_index; -- fallback calculation
        END IF;

        v_source_id := 'ad_block:' || v_uid::text || ':' || v_today::text || ':' || v_block_index::text;

        -- Check risk
        PERFORM public.compute_risk(v_uid);
        
        IF EXISTS (
            SELECT 1 FROM public.risk_flags
            WHERE fan_id = v_uid AND resolved = false AND severity IN ('medium', 'high')
        ) THEN
            v_is_held := true;
            v_ledger_status := 'held';
        END IF;

        -- Insert ledger entry with UNIQUE source_id protection
        BEGIN
            INSERT INTO public.ledger_entries (
                id, fan_id, amount, type, status, source_type, source_id, note
            ) VALUES (
                v_ledger_id, v_uid, v_pearls_tier, 'ad_reward', v_ledger_status, 'ad_block', v_source_id,
                'Recompensa por bloque ' || v_block_index || ' (' || v_new_count || ' anuncios vistos)'
            );

            v_paid := true;

            IF v_ledger_status = 'confirmed' THEN
                UPDATE public.wallets
                SET balance_cache = balance_cache + v_pearls_tier,
                    updated_at = NOW()
                WHERE fan_id = v_uid;
            END IF;

            UPDATE public.ad_daily_progress
            SET blocks_paid = blocks_paid + 1
            WHERE user_id = v_uid AND day = v_today;

        EXCEPTION WHEN unique_violation THEN
            -- Block was already paid by concurrent transaction
            v_paid := false;
            v_pearls_tier := 0;
        END;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'completed_today', v_new_count,
        'daily_limit', v_eco.daily_ad_views,
        'block_size', v_eco.block_size,
        'block_progress', v_new_count % v_eco.block_size,
        'block_completed', (v_new_count % v_eco.block_size = 0),
        'pearls_awarded', v_pearls_tier,
        'held', v_is_held,
        'paid', v_paid
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.compute_redemption_code_hash(p_code_or_hash text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_cleaned TEXT := upper(trim(p_code_or_hash));
BEGIN
    IF v_cleaned IS NULL OR v_cleaned = '' THEN
        RETURN NULL;
    END IF;

    -- Si ya es un hash SHA-256 en hexadecimal (64 chars), devolverlo en minúsculas
    IF length(v_cleaned) = 64 AND v_cleaned ~ '^[0-9A-F]{64}$' THEN
        RETURN lower(v_cleaned);
    END IF;

    -- Si es el código base32 de 12 chars (o texto libre), calcular su SHA-256
    RETURN encode(extensions.digest(v_cleaned, 'sha256'), 'hex');
END;
$function$;

CREATE OR REPLACE FUNCTION public.compute_risk(p_fan_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_device_count INT;
    v_ip_count INT;
    v_exact_min_sec_count INT;
    v_consecutive_caps INT;
    v_shared_cap_device INT;
    v_eco_min_sec INT;
BEGIN
    SELECT ad_min_seconds INTO v_eco_min_sec FROM public.economy_settings ORDER BY created_at DESC LIMIT 1;
    v_eco_min_sec := COALESCE(v_eco_min_sec, 6);

    -- 1. Check multiple accounts sharing same device_id
    SELECT COUNT(DISTINCT fan_id) INTO v_device_count
    FROM public.fraud_telemetry
    WHERE device_id IN (
        SELECT device_id FROM public.fraud_telemetry WHERE fan_id = p_fan_id AND device_id IS NOT NULL LIMIT 1
    );

    IF v_device_count >= 3 THEN
        INSERT INTO public.risk_flags (fan_id, reason, severity)
        VALUES (p_fan_id, 'Shared device across multiple accounts (' || v_device_count || ' fans)', 'medium')
        ON CONFLICT DO NOTHING;
    END IF;

    -- 2. Check multiple new accounts from same ip_hash in short window (24h)
    SELECT COUNT(DISTINCT fan_id) INTO v_ip_count
    FROM public.fraud_telemetry
    WHERE ip_hash IN (
        SELECT ip_hash FROM public.fraud_telemetry WHERE fan_id = p_fan_id AND ip_hash IS NOT NULL LIMIT 1
    ) AND created_at >= NOW() - INTERVAL '24 hours';

    IF v_ip_count >= 5 THEN
        INSERT INTO public.risk_flags (fan_id, reason, severity)
        VALUES (p_fan_id, 'High velocity account registrations from same IP hash (' || v_ip_count || ' fans)', 'medium')
        ON CONFLICT DO NOTHING;
    END IF;

    -- 3. Ad Risk: Sessions completed right at ad_min_seconds window consistently (5+ sessions within +/- 0.5s of min seconds)
    SELECT COUNT(*) INTO v_exact_min_sec_count
    FROM public.ad_sessions
    WHERE user_id = p_fan_id
      AND status = 'completed'
      AND completed_at IS NOT NULL
      AND ABS(EXTRACT(EPOCH FROM (completed_at - started_at)) - v_eco_min_sec) <= 0.5;

    IF v_exact_min_sec_count >= 5 THEN
        INSERT INTO public.risk_flags (fan_id, reason, severity)
        VALUES (p_fan_id, 'Sustained ad completions at exact minimum time threshold (' || v_exact_min_sec_count || ' sessions)', 'medium')
        ON CONFLICT DO NOTHING;
    END IF;

    -- 4. Ad Risk: Daily cap of 50 reached for 3+ consecutive days
    SELECT COUNT(*) INTO v_consecutive_caps
    FROM public.ad_daily_progress
    WHERE user_id = p_fan_id
      AND completed_count >= 50
      AND day >= (NOW() AT TIME ZONE 'America/Caracas')::date - INTERVAL '7 days';

    IF v_consecutive_caps >= 3 THEN
        INSERT INTO public.risk_flags (fan_id, reason, severity)
        VALUES (p_fan_id, 'Daily ad limit of 50 reached on ' || v_consecutive_caps || ' days in past week', 'medium')
        ON CONFLICT DO NOTHING;
    END IF;

    -- 5. Ad Risk: Multiple accounts with same device reaching ad cap
    SELECT COUNT(DISTINCT user_id) INTO v_shared_cap_device
    FROM public.ad_daily_progress dp
    WHERE dp.completed_count >= 50
      AND dp.user_id IN (
          SELECT DISTINCT fan_id FROM public.fraud_telemetry
          WHERE device_id IN (SELECT device_id FROM public.fraud_telemetry WHERE fan_id = p_fan_id AND device_id IS NOT NULL)
      );

    IF v_shared_cap_device >= 2 THEN
        INSERT INTO public.risk_flags (fan_id, reason, severity)
        VALUES (p_fan_id, 'Multiple accounts on same device hitting daily ad cap (' || v_shared_cap_device || ' accounts)', 'high')
        ON CONFLICT DO NOTHING;
    END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.confirm_test_user_email(p_email text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    UPDATE auth.users SET email_confirmed_at = NOW() WHERE email = p_email;
END;
$function$;

CREATE OR REPLACE FUNCTION public.create_notification(p_user_id uuid, p_type text, p_title text, p_body text, p_data jsonb DEFAULT '{}'::jsonb, p_dedup_key text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_dedup_key TEXT;
    v_prefs JSONB;
    v_is_transactional BOOLEAN;
    v_pref_enabled BOOLEAN := true;
    v_daily_non_trans_count INT := 0;
    v_cur_hour INT;
    v_next_attempt_at TIMESTAMPTZ := NOW();
    v_target_date DATE;
    v_notif_id UUID;
    v_has_active_push BOOLEAN := false;
BEGIN
    IF p_user_id IS NULL OR p_type IS NULL OR p_title IS NULL OR p_body IS NULL THEN
        RETURN NULL;
    END IF;

    v_dedup_key := COALESCE(p_dedup_key, gen_random_uuid()::text);

    -- Clasificación transaccional vs no transaccional
    v_is_transactional := (p_type IN (
        'redemption_approved',
        'redemption_delivered',
        'redemption_rejected',
        'redemption_cancelled',
        'redemption_issue',
        'redemption_expiring',
        'pearls_released'
    ));

    -- Obtener preferencias del usuario
    SELECT notification_prefs INTO v_prefs FROM public.profiles WHERE id = p_user_id;
    IF v_prefs IS NULL THEN
        v_prefs := '{"redemptions": true, "trivias_matches": true, "news": true, "push": true, "email": true}'::jsonb;
    END IF;

    IF NOT v_is_transactional THEN
        -- Verificar preferencia según categoría
        IF p_type IN ('new_trivia', 'match_day') THEN
            IF COALESCE((v_prefs->>'trivias_matches')::boolean, true) IS FALSE THEN
                RETURN NULL;
            END IF;
        ELSIF p_type IN ('team_news') THEN
            IF COALESCE((v_prefs->>'news')::boolean, true) IS FALSE THEN
                RETURN NULL;
            END IF;
        END IF;

        -- Tope de 1 notificación no transaccional al día (huso America/Caracas)
        SELECT COUNT(*) INTO v_daily_non_trans_count
        FROM public.notifications
        WHERE user_id = p_user_id
          AND type NOT IN ('redemption_approved', 'redemption_delivered', 'redemption_rejected', 'redemption_cancelled', 'redemption_issue', 'redemption_expiring', 'pearls_released')
          AND (created_at AT TIME ZONE 'America/Caracas')::date = (NOW() AT TIME ZONE 'America/Caracas')::date;

        IF v_daily_non_trans_count >= 1 THEN
            RETURN NULL;
        END IF;

        -- Horario de silencio 22:00 a 08:00 (America/Caracas)
        v_cur_hour := EXTRACT(HOUR FROM (NOW() AT TIME ZONE 'America/Caracas'));
        IF v_cur_hour >= 22 OR v_cur_hour < 8 THEN
            IF v_cur_hour >= 22 THEN
                v_target_date := (NOW() AT TIME ZONE 'America/Caracas')::date + INTERVAL '1 day';
            ELSE
                v_target_date := (NOW() AT TIME ZONE 'America/Caracas')::date;
            END IF;
            v_next_attempt_at := (v_target_date || ' 08:00:00')::timestamp AT TIME ZONE 'America/Caracas';
        END IF;
    END IF;

    -- Inserción idempotente en notifications
    INSERT INTO public.notifications (user_id, type, title, body, data, dedup_key)
    VALUES (p_user_id, p_type, p_title, p_body, COALESCE(p_data, '{}'::jsonb), v_dedup_key)
    ON CONFLICT (user_id, dedup_key) DO NOTHING
    RETURNING id INTO v_notif_id;

    IF v_notif_id IS NULL THEN
        RETURN NULL; -- Ya existía por dedup_key
    END IF;

    -- Encolar en notification_outbox si las preferencias del canal lo permiten
    IF COALESCE((v_prefs->>'push')::boolean, true) IS NOT FALSE THEN
        SELECT EXISTS (
            SELECT 1 FROM public.push_subscriptions
            WHERE user_id = p_user_id AND disabled_at IS NULL
        ) INTO v_has_active_push;

        IF v_has_active_push THEN
            INSERT INTO public.notification_outbox (notification_id, channel, status, next_attempt_at)
            VALUES (v_notif_id, 'push', 'pending', v_next_attempt_at);
        END IF;
    END IF;

    IF COALESCE((v_prefs->>'email')::boolean, true) IS NOT FALSE THEN
        INSERT INTO public.notification_outbox (notification_id, channel, status, next_attempt_at)
        VALUES (v_notif_id, 'email', 'pending', v_next_attempt_at);
    END IF;

    RETURN v_notif_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.create_security_notification(p_user_id uuid, p_title text, p_body text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
BEGIN
    INSERT INTO public.notifications (user_id, title, message, type)
    VALUES (p_user_id, p_title, p_body, 'security');
END;
$function$;

CREATE OR REPLACE FUNCTION public.cron_cleanup_old_notifications()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
BEGIN
    DELETE FROM public.notifications
    WHERE read_at IS NOT NULL
      AND read_at < (NOW() - INTERVAL '90 days');
END;
$function$;

CREATE OR REPLACE FUNCTION public.cron_notify_expiring_redemptions()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT id, fan_id, expires_at
        FROM public.redemptions
        WHERE status IN ('pending', 'approved')
          AND expires_at IS NOT NULL
          AND expires_at > NOW()
          AND expires_at <= (NOW() + INTERVAL '24 hours')
    LOOP
        PERFORM public.create_notification(
            r.fan_id,
            'redemption_expiring',
            '¡Tu canje vence pronto!',
            'Tienes un canje pendiente por retirar que vence en menos de 24 horas.',
            jsonb_build_object('redemption_id', r.id, 'url', '/app/canjes/' || r.id),
            'redemption_expiring_' || r.id || '_' || (r.expires_at::date)::text
        );
    END LOOP;
END;
$function$;

CREATE OR REPLACE FUNCTION public.cron_notify_match_day()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    m RECORD;
    f RECORD;
BEGIN
    FOR m IN
        SELECT id, opponent, game_date
        FROM public.games
        WHERE status = 'scheduled'
          AND game_date >= (NOW() + INTERVAL '2 hours 30 minutes')
          AND game_date <= (NOW() + INTERVAL '3 hours 30 minutes')
    LOOP
        FOR f IN SELECT id FROM public.profiles WHERE status = 'active' LOOP
            PERFORM public.create_notification(
                f.id,
                'match_day',
                '¡Hoy Juegan los Guaiqueríes!',
                'El partido contra ' || m.opponent || ' comienza en 3 horas.',
                jsonb_build_object('game_id', m.id, 'url', '/app'),
                'match_day_' || m.id || '_' || f.id
            );
        END LOOP;
    END LOOP;
END;
$function$;

CREATE OR REPLACE FUNCTION public.cron_notify_new_trivias()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    t RECORD;
    f RECORD;
BEGIN
    FOR t IN
        SELECT id, title
        FROM public.trivias
        WHERE status = 'published'
          AND created_at >= (NOW() - INTERVAL '1 hour')
    LOOP
        FOR f IN SELECT id FROM public.profiles WHERE status = 'active' LOOP
            PERFORM public.create_notification(
                f.id,
                'new_trivia',
                '¡Nueva Trivia Disponible!',
                'Demuestra cuánto sabes sobre los Guaiqueríes: ' || t.title,
                jsonb_build_object('trivia_id', t.id, 'url', '/app/trivias/' || t.id),
                'new_trivia_' || t.id || '_' || f.id
            );
        END LOOP;
    END LOOP;
END;
$function$;

CREATE OR REPLACE FUNCTION public.delete_my_account()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid UUID := auth.uid();
    v_status user_status;
    v_unresolved_flags INT;
    v_pending_redemptions INT;
    v_held_entries INT;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT status INTO v_status FROM profiles WHERE id = v_uid;

    IF v_status = 'deleted' THEN
        RETURN jsonb_build_object(
            'success', true,
            'message', 'La cuenta ya ha sido eliminada previamente.',
            'already_deleted', true
        );
    END IF;

    IF v_status = 'suspended' THEN
        RAISE EXCEPTION 'Cuentas suspendidas no pueden ser eliminadas directamente.';
    END IF;

    SELECT COUNT(*) INTO v_unresolved_flags FROM risk_flags WHERE fan_id = v_uid AND resolved = false;
    IF v_unresolved_flags > 0 THEN
        RAISE EXCEPTION 'Existen verificaciones pendientes en tu cuenta. Contáctate con soporte.';
    END IF;

    SELECT COUNT(*) INTO v_pending_redemptions
    FROM public.redemptions
    WHERE fan_id = v_uid AND status IN ('pending', 'approved', 'scheduled');

    IF v_pending_redemptions > 0 THEN
        RAISE EXCEPTION 'No puedes eliminar tu cuenta mientras tengas % canje(s) en proceso o pendiente(s) de entrega. Por favor completa o cancela tus canjes primero.', v_pending_redemptions;
    END IF;

    -- Check pending held entries (without resolution)
    SELECT COUNT(*) INTO v_held_entries
    FROM public.ledger_entries le
    WHERE le.fan_id = v_uid
      AND le.status = 'held'
      AND NOT EXISTS (
          SELECT 1 FROM public.ledger_hold_resolutions r WHERE r.ledger_id = le.id
      );

    IF v_held_entries > 0 THEN
        RAISE EXCEPTION 'No puedes eliminar tu cuenta mientras tengas perlitas retenidas bajo revisión de soporte.';
    END IF;

    UPDATE public.profiles
    SET display_name = 'Fanático Anónimo',
        avatar_url = NULL,
        municipality = NULL,
        birth_date = NULL,
        gender = NULL,
        favorite_player_id = NULL,
        shirt_size = NULL,
        referral_source = NULL,
        notification_prefs = '{}'::jsonb,
        status = 'deleted',
        deleted_at = NOW()
    WHERE id = v_uid;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        v_uid, 'delete_my_account', 'profiles', v_uid::text,
        jsonb_build_object('status', COALESCE(v_status::text, 'active')),
        jsonb_build_object('status', 'deleted', 'anonymized', true, 'deleted_at', NOW())
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Cuenta anonimizada y eliminada exitosamente.',
        'already_deleted', false
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.deliver_redemption(p_code text, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_staff_id UUID := auth.uid();
    v_clean_code TEXT;
    v_hash TEXT;
    v_redemption public.redemptions%ROWTYPE;
BEGIN
    PERFORM assert_staff();

    v_clean_code := UPPER(REGEXP_REPLACE(COALESCE(p_code, ''), '[-\s]', '', 'g'));
    v_hash := compute_redemption_code_hash(v_clean_code);

    SELECT * INTO v_redemption FROM public.redemptions WHERE code_hash = v_hash FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'REDEMPTION_NOT_FOUND: Código no encontrado.';
    END IF;

    IF v_redemption.status IN ('delivered', 'completed') THEN
        RETURN jsonb_build_object('status', 'already_delivered', 'redemption_id', v_redemption.id);
    END IF;

    IF v_redemption.status NOT IN ('approved', 'scheduled') THEN
        RAISE EXCEPTION 'INVALID_STATUS: Solo se pueden entregar canjes en estado "approved" o "scheduled". Estado actual: %', v_redemption.status;
    END IF;

    UPDATE public.redemptions
    SET status = 'delivered',
        delivered_by = v_staff_id,
        delivered_at = NOW()
    WHERE id = v_redemption.id AND status IN ('approved', 'scheduled');

    INSERT INTO public.redemption_history (redemption_id, previous_status, new_status, changed_by, note)
    VALUES (v_redemption.id, v_redemption.status, 'delivered', v_staff_id, COALESCE(p_note, 'Entregado en taquilla'));

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_staff_id, 'deliver_redemption', 'redemptions', v_redemption.id::text,
        jsonb_build_object('delivered_at', NOW(), 'note', p_note)
    );

    RETURN jsonb_build_object('status', 'delivered', 'redemption_id', v_redemption.id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.deliver_redemption(p_redemption_id uuid, p_idempotency_key text, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_staff_id UUID := auth.uid();
    v_redemption public.redemptions%ROWTYPE;
    v_deliv_name TEXT;
BEGIN
    PERFORM assert_staff();

    IF p_idempotency_key IS NULL OR trim(p_idempotency_key) = '' THEN
        RAISE EXCEPTION 'Idempotency key is required for delivery.';
    END IF;

    -- Lock FOR UPDATE for strict atomicity
    SELECT * INTO v_redemption
    FROM public.redemptions
    WHERE id = p_redemption_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Canje no encontrado.';
    END IF;

    -- If already delivered or idempotency key reused
    IF v_redemption.status IN ('delivered', 'completed') OR v_redemption.delivery_idempotency_key = p_idempotency_key THEN
        SELECT display_name INTO v_deliv_name FROM public.profiles WHERE id = v_redemption.delivered_by;
        RETURN jsonb_build_object(
            'result', 'ALREADY_DELIVERED',
            'status', v_redemption.status,
            'delivered_at', v_redemption.delivered_at,
            'delivered_by_name', COALESCE(v_deliv_name, 'Personal de Staff')
        );
    END IF;

    IF v_redemption.status NOT IN ('approved', 'scheduled') THEN
        RAISE EXCEPTION 'Solo se pueden entregar canjes en estado "approved" o "scheduled". Estado actual: %', v_redemption.status;
    END IF;

    -- Atomic update
    UPDATE public.redemptions
    SET status = 'delivered',
        delivered_by = v_staff_id,
        delivered_at = NOW(),
        delivery_idempotency_key = p_idempotency_key
    WHERE id = v_redemption.id AND status IN ('approved', 'scheduled');

    -- Log history and audit
    INSERT INTO public.redemption_history (redemption_id, previous_status, new_status, changed_by, note)
    VALUES (v_redemption.id, v_redemption.status, 'delivered', v_staff_id, COALESCE(p_note, 'Premio entregado al fanático'));

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_staff_id, 'deliver_redemption', 'redemptions', v_redemption.id::text,
        jsonb_build_object('delivered_at', NOW(), 'idempotency_key', p_idempotency_key, 'note', p_note)
    );

    RETURN jsonb_build_object(
        'result', 'DELIVERED',
        'status', 'delivered',
        'redemption_id', v_redemption.id,
        'delivered_at', NOW()
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.enqueue_birthday_notifications(p_now timestamp with time zone DEFAULT now())
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
    v_caracas_now TIMESTAMPTZ;
    v_cur_date DATE;
    v_cur_month INT;
    v_cur_day INT;
    v_cur_year INT;
    v_is_leap BOOLEAN;
    v_settings public.birthday_settings%ROWTYPE;
    v_count INT := 0;
    r RECORD;
BEGIN
    SELECT * INTO v_settings FROM public.birthday_settings WHERE id = 1;
    IF v_settings.enabled IS NOT TRUE THEN
        RETURN jsonb_build_object('success', true, 'enqueued', 0, 'reason', 'Campaign disabled');
    END IF;

    -- Calculate Caracas time (UTC-4)
    v_caracas_now := COALESCE(p_now, NOW()) AT TIME ZONE 'America/Caracas';
    v_cur_date := v_caracas_now::date;
    v_cur_month := EXTRACT(MONTH FROM v_caracas_now)::int;
    v_cur_day := EXTRACT(DAY FROM v_caracas_now)::int;
    v_cur_year := EXTRACT(YEAR FROM v_caracas_now)::int;

    -- Leap year check for current year
    v_is_leap := (v_cur_year % 4 = 0 AND (v_cur_year % 100 != 0 OR v_cur_year % 400 = 0));

    -- Select eligible fans whose birthday matches today in Caracas
    FOR r IN
        SELECT p.id, p.display_name, p.notification_prefs
        FROM public.profiles p
        JOIN auth.users u ON u.id = p.id
        WHERE p.status = 'active'
          AND p.deleted_at IS NULL
          AND u.email_confirmed_at IS NOT NULL
          AND p.birth_date IS NOT NULL
          AND (
            -- Exact month and day match
            (EXTRACT(MONTH FROM p.birth_date)::int = v_cur_month AND EXTRACT(DAY FROM p.birth_date)::int = v_cur_day)
            OR
            -- Feb 29 birth in non-leap year celebrated on Feb 28
            (NOT v_is_leap AND EXTRACT(MONTH FROM p.birth_date)::int = 2 AND EXTRACT(DAY FROM p.birth_date)::int = 29 AND v_cur_month = 2 AND v_cur_day = 28)
          )
          AND COALESCE((p.notification_prefs->>'birthday')::boolean, true) = true
        LIMIT 500
    LOOP
        PERFORM public.create_notification(
            r.id,
            'birthday',
            '¡Feliz cumpleaños, Guaiquerí!',
            'Hola ' || COALESCE(r.display_name, 'Fanático') || ', los Guaiqueríes de Margarita tienen un mensaje especial para ti hoy.',
            jsonb_build_object('url', '/app/cumpleanos'),
            'birthday:' || r.id::text || ':' || v_cur_year::text
        );
        v_count := v_count + 1;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'enqueued', v_count, 'caracas_date', v_cur_date);
END;
$function$;

CREATE OR REPLACE FUNCTION public.generate_redemption_code(p_redemption_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_active_key_id TEXT;
    v_secret TEXT;
    v_raw BYTEA;
    v_alphabet TEXT := '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
    v_val BIGINT := 0;
    v_code TEXT := '';
    v_i INT;
    v_sum INT := 0;
    v_check CHAR;
BEGIN
    IF p_redemption_id IS NULL THEN
        RAISE EXCEPTION 'Redemption ID required.';
    END IF;

    SELECT secret_value INTO v_active_key_id FROM public.app_secrets WHERE key_name = 'hmac_active_key_id';
    IF v_active_key_id IS NULL THEN v_active_key_id := 'v2'; END IF;

    SELECT secret_value INTO v_secret FROM public.app_secrets WHERE key_name = 'hmac_secret_' || v_active_key_id;
    IF v_secret IS NULL OR v_secret = '' THEN
        -- Fallback to default
        SELECT secret_value INTO v_secret FROM public.app_secrets WHERE key_name = 'hmac_secret_v2';
    END IF;

    IF v_secret IS NULL THEN
        RAISE EXCEPTION 'HMAC secret key not configured in app_secrets.';
    END IF;

    -- Update redemptions row with key_id used
    UPDATE public.redemptions SET qr_key_id = v_active_key_id WHERE id = p_redemption_id;

    -- HMAC-SHA256
    v_raw := extensions.hmac(p_redemption_id::text, v_secret, 'sha256');

    FOR v_i IN 1..7 LOOP
        v_val := (v_val * 256) + get_byte(v_raw, v_i - 1);
    END LOOP;

    FOR v_i IN 1..11 LOOP
        v_code := substr(v_alphabet, (v_val % 32)::int + 1, 1) || v_code;
        v_val := v_val / 32;
    END LOOP;

    FOR v_i IN 1..11 LOOP
        v_sum := v_sum + (position(substr(v_code, v_i, 1) in v_alphabet) - 1) * v_i;
    END LOOP;
    v_check := substr(v_alphabet, (v_sum % 32) + 1, 1);

    RETURN v_code || v_check;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_active_legal_versions()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_res JSONB;
BEGIN
    SELECT jsonb_object_agg(slug, version)
    INTO v_res
    FROM (
        SELECT slug, version
        FROM public.policy_documents
        WHERE is_active = true
    ) sub;

    RETURN COALESCE(v_res, '{"terminos": "v1.0", "privacidad": "v1.0", "perlitas": "v1.0", "canjes": "v1.0"}'::jsonb);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_ads_progress()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_uid UUID := auth.uid();
    v_today DATE := (NOW() AT TIME ZONE 'America/Caracas')::date;
    v_eco RECORD;
    v_completed INT := 0;
    v_earned_today INT := 0;
    v_account_age_days INT;
    v_trivias_count INT;
    v_can_watch BOOLEAN := true;
    v_cant_reason TEXT := NULL;
    v_block_size INT := 10;
    v_daily_limit INT := 50;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT ads_enabled, daily_ad_views, block_size, ad_min_seconds, ad_min_account_age_days, ad_min_trivias_completed
    INTO v_eco
    FROM public.economy_settings
    ORDER BY created_at DESC LIMIT 1;

    IF v_eco IS NOT NULL THEN
        v_block_size := COALESCE(v_eco.block_size, 10);
        v_daily_limit := COALESCE(v_eco.daily_ad_views, 50);
    END IF;

    -- Check daily completed count
    SELECT COALESCE(completed_count, 0) INTO v_completed
    FROM public.ad_daily_progress
    WHERE user_id = v_uid AND day = v_today;

    -- When SELECT INTO finds no rows, PL/pgSQL assigns NULL to v_completed. Force safe 0 fallback.
    v_completed := COALESCE(v_completed, 0);

    -- Calculate total pearls earned from ads today
    SELECT COALESCE(SUM(amount), 0) INTO v_earned_today
    FROM public.ledger_entries
    WHERE fan_id = v_uid
      AND type = 'ad_reward'
      AND (created_at AT TIME ZONE 'America/Caracas')::date = v_today;

    -- Force safe 0 fallback
    v_earned_today := COALESCE(v_earned_today, 0);

    -- Check conditions if fan can watch ads
    IF v_eco.ads_enabled IS NOT TRUE THEN
        v_can_watch := false;
        v_cant_reason := 'ADS_DISABLED';
    ELSIF v_completed >= v_daily_limit THEN
        v_can_watch := false;
        v_cant_reason := 'AD_DAILY_LIMIT';
    ELSE
        SELECT EXTRACT(DAY FROM (NOW() - created_at))::int INTO v_account_age_days
        FROM public.profiles WHERE id = v_uid;

        IF COALESCE(v_account_age_days, 0) < COALESCE(v_eco.ad_min_account_age_days, 3) THEN
            v_can_watch := false;
            v_cant_reason := 'ACCOUNT_TOO_NEW';
        ELSE
            SELECT COUNT(*) INTO v_trivias_count
            FROM public.trivia_attempts
            WHERE fan_id = v_uid AND submitted_at IS NOT NULL;

            IF v_trivias_count < COALESCE(v_eco.ad_min_trivias_completed, 1) THEN
                v_can_watch := false;
                v_cant_reason := 'TRIVIAS_REQUIRED';
            END IF;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'ads_enabled', COALESCE(v_eco.ads_enabled, false),
        'completed_today', v_completed,
        'daily_limit', v_daily_limit,
        'block_size', v_block_size,
        'block_progress', CASE WHEN v_block_size > 0 THEN v_completed % v_block_size ELSE 0 END,
        'next_block_number', CASE WHEN v_block_size > 0 THEN (v_completed / v_block_size) + 1 ELSE 1 END,
        'pearls_earned_today', v_earned_today,
        'can_watch', v_can_watch,
        'cant_reason', v_cant_reason,
        'ad_min_seconds', COALESCE(v_eco.ad_min_seconds, 6)
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_attempt_questions(p_attempt_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_fan_id UUID := auth.uid();
    v_attempt trivia_attempts%ROWTYPE;
    v_questions JSONB;
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT * INTO v_attempt FROM trivia_attempts WHERE id = p_attempt_id AND fan_id = v_fan_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Trivia attempt not found or unauthorized.';
    END IF;

    IF v_attempt.submitted_at IS NOT NULL THEN
        RAISE EXCEPTION 'TRIVIA_ALREADY_PLAYED';
    END IF;

    IF NOW() > v_attempt.expires_at THEN
        RAISE EXCEPTION 'ATTEMPT_EXPIRED';
    END IF;

    -- Fetch questions without is_correct
    SELECT jsonb_agg(
        jsonb_build_object(
            'question_id', q.id,
            'question_text', q.question_text,
            'points', q.points,
            'options', (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'option_id', o.id,
                        'option_text', o.option_text
                    )
                ) FROM trivia_options o WHERE o.question_id = q.id
            )
        ) ORDER BY hashtext(q.id::text || v_attempt.seed::text)
    ) INTO v_questions
    FROM trivia_questions q
    WHERE q.trivia_id = v_attempt.trivia_id;

    RETURN jsonb_build_object(
        'attempt_id', v_attempt.id,
        'trivia_id', v_attempt.trivia_id,
        'expires_at', v_attempt.expires_at,
        'seed', v_attempt.seed,
        'questions', COALESCE(v_questions, '[]'::jsonb)
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_birthday_card()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_user_id UUID;
    v_caracas_now TIMESTAMPTZ;
    v_cur_date DATE;
    v_cur_year INT;
    v_profile public.profiles%ROWTYPE;
    v_settings public.birthday_settings%ROWTYPE;
    v_bdate DATE;
    v_bmonth INT;
    v_bday INT;
    v_is_leap BOOLEAN;
    v_bdate_this_year DATE;
    v_grace_days INT;
    v_is_eligible BOOLEAN := false;
    v_claimed BOOLEAN := false;
BEGIN
    v_user_id := public.assert_active_verified_fan();

    SELECT * INTO v_profile FROM public.profiles WHERE id = v_user_id;
    SELECT * INTO v_settings FROM public.birthday_settings WHERE id = 1;

    IF v_profile.birth_date IS NULL OR v_settings.enabled IS NOT TRUE THEN
        RETURN jsonb_build_object('eligible', false);
    END IF;

    v_caracas_now := NOW() AT TIME ZONE 'America/Caracas';
    v_cur_date := v_caracas_now::date;
    v_cur_year := EXTRACT(YEAR FROM v_caracas_now)::int;
    v_is_leap := (v_cur_year % 4 = 0 AND (v_cur_year % 100 != 0 OR v_cur_year % 400 = 0));

    v_bdate := v_profile.birth_date;
    v_bmonth := EXTRACT(MONTH FROM v_bdate)::int;
    v_bday := EXTRACT(DAY FROM v_bdate)::int;

    -- Feb 29 adjustment on non-leap years
    IF v_bmonth = 2 AND v_bday = 29 AND NOT v_is_leap THEN
        v_bday := 28;
    END IF;

    v_bdate_this_year := (v_cur_year::text || '-' || lpad(v_bmonth::text, 2, '0') || '-' || lpad(v_bday::text, 2, '0'))::date;
    v_grace_days := COALESCE(v_settings.grace_days, 3);

    -- Check if today is within window [birthday, birthday + grace_days]
    IF v_cur_date >= v_bdate_this_year AND v_cur_date <= (v_bdate_this_year + (v_grace_days || ' days')::interval) THEN
        v_is_eligible := true;
    END IF;

    IF NOT v_is_eligible THEN
        RETURN jsonb_build_object('eligible', false);
    END IF;

    -- Check if bonus already claimed this year
    SELECT EXISTS (
        SELECT 1 FROM public.ledger_entries
        WHERE user_id = v_user_id
          AND reference_id = 'birthday_bonus_' || v_user_id::text || '_' || v_cur_year::text
    ) INTO v_claimed;

    RETURN jsonb_build_object(
        'eligible', true,
        'display_name', v_profile.display_name,
        'title', v_settings.title,
        'message', v_settings.message,
        'image_url', v_settings.image_url,
        'bonus_pearls', v_settings.bonus_pearls,
        'has_claimed_bonus', v_claimed
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_leaderboard(p_period text DEFAULT 'monthly'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid UUID := auth.uid();
    v_start_date TIMESTAMPTZ;
    v_leaderboard JSONB;
BEGIN
    IF p_period = 'weekly' THEN
        v_start_date := date_trunc('week', NOW());
    ELSE
        v_start_date := date_trunc('month', NOW());
    END IF;

    SELECT jsonb_agg(
        jsonb_build_object(
            'rank', r.rank_number,
            'user_id', r.fan_id,
            'display_name', r.display_name,
            'avatar_url', r.avatar_url,
            'pearls_earned', r.total_pearls,
            'is_current_user', (r.fan_id = v_uid)
        )
    ) INTO v_leaderboard
    FROM (
        SELECT 
            p.id AS fan_id,
            p.display_name,
            p.avatar_url,
            COALESCE(SUM(l.amount), 0)::int AS total_pearls,
            ROW_NUMBER() OVER (ORDER BY COALESCE(SUM(l.amount), 0) DESC, p.created_at ASC) AS rank_number
        FROM profiles p
        JOIN ledger_entries l ON l.fan_id = p.id
        WHERE p.status = 'active'
          AND p.deleted_at IS NULL
          AND l.status = 'confirmed'
          AND l.type IN ('trivia_reward', 'bonus', 'streak_bonus')
          AND l.created_at >= v_start_date
        GROUP BY p.id, p.display_name, p.avatar_url, p.created_at
        HAVING COALESCE(SUM(l.amount), 0) > 0
        ORDER BY total_pearls DESC
        LIMIT 50
    ) r;

    RETURN jsonb_build_object(
        'period', p_period,
        'leaderboard', COALESCE(v_leaderboard, '[]'::jsonb)
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_login_modal()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_user_id UUID;
    v_slides JSONB;
BEGIN
    v_user_id := public.assert_active_verified_fan();

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', id,
            'position', position,
            'image_url', image_url,
            'title', title,
            'subtitle', subtitle,
            'cta_label', cta_label,
            'cta_url', cta_url
        ) ORDER BY position ASC
    ), '[]'::jsonb) INTO v_slides
    FROM public.login_modal_slides
    WHERE status = 'published'
      AND starts_at <= NOW()
      AND (ends_at IS NULL OR ends_at >= NOW());

    RETURN v_slides;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_redemption_qr(p_redemption_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_fan_id UUID := auth.uid();
    v_redemption redemptions%ROWTYPE;
    v_code TEXT;
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT * INTO v_redemption 
    FROM redemptions 
    WHERE id = p_redemption_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Redemption not found.';
    END IF;

    IF v_redemption.fan_id != v_fan_id AND NOT is_staff_or_admin(v_fan_id) THEN
        RAISE EXCEPTION 'Unauthorized: You do not own this redemption.';
    END IF;

    IF v_redemption.status NOT IN ('approved', 'scheduled') THEN
        RAISE EXCEPTION 'QR Code is not available for redemptions in status "%". QR is only available when approved or scheduled.', v_redemption.status;
    END IF;

    IF v_redemption.expires_at IS NOT NULL AND NOW() > v_redemption.expires_at THEN
        RAISE EXCEPTION 'Redemption has expired on %.', v_redemption.expires_at;
    END IF;

    v_code := generate_redemption_code(v_redemption.id);

    RETURN jsonb_build_object(
        'redemption_id', v_redemption.id,
        'code', v_code,
        'status', v_redemption.status,
        'variant', v_redemption.variant,
        'cost_pearls', v_redemption.cost_pearls,
        'expires_at', v_redemption.expires_at
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_streak_info(p_fan_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_today DATE := (NOW() AT TIME ZONE 'America/Caracas')::date;
    v_already_awarded BOOLEAN;
    v_streak_days INT := 0;
    v_day_check DATE;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM ledger_entries
        WHERE fan_id = p_fan_id
          AND type = 'streak_bonus'
          AND (created_at AT TIME ZONE 'America/Caracas')::date = v_today
    ) INTO v_already_awarded;

    -- Calculate consecutive days up to today in Caracas timezone
    v_day_check := v_today;
    LOOP
        IF EXISTS (
            SELECT 1 FROM trivia_attempts
            WHERE fan_id = p_fan_id
              AND submitted_at IS NOT NULL
              AND (submitted_at AT TIME ZONE 'America/Caracas')::date = v_day_check
        ) THEN
            v_streak_days := v_streak_days + 1;
            v_day_check := v_day_check - INTERVAL '1 day';
        ELSE
            EXIT;
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'streak_days', v_streak_days,
        'already_awarded_today', v_already_awarded
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.health_check()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_unresolved_alerts INT;
  v_status TEXT := 'ok';
BEGIN
  SELECT COUNT(*) INTO v_unresolved_alerts FROM public.system_alerts WHERE resolved = false;

  IF v_unresolved_alerts > 0 THEN
    v_status := 'degraded';
  END IF;

  -- Only return high-level status token to prevent information disclosure
  RETURN jsonb_build_object('status', v_status);
END;
$function$;

CREATE OR REPLACE FUNCTION public.helper_generate_code_with_key(p_redemption_id uuid, p_key_id text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_secret TEXT;
    v_raw BYTEA;
    v_alphabet TEXT := '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
    v_val BIGINT := 0;
    v_code TEXT := '';
    v_i INT;
    v_sum INT := 0;
    v_check CHAR;
BEGIN
    SELECT secret_value INTO v_secret FROM public.app_secrets WHERE key_name = 'hmac_secret_' || p_key_id;
    IF v_secret IS NULL THEN RETURN NULL; END IF;

    v_raw := extensions.hmac(p_redemption_id::text, v_secret, 'sha256');

    FOR v_i IN 1..7 LOOP
        v_val := (v_val * 256) + get_byte(v_raw, v_i - 1);
    END LOOP;

    FOR v_i IN 1..11 LOOP
        v_code := substr(v_alphabet, (v_val % 32)::int + 1, 1) || v_code;
        v_val := v_val / 32;
    END LOOP;

    FOR v_i IN 1..11 LOOP
        v_sum := v_sum + (position(substr(v_code, v_i, 1) in v_alphabet) - 1) * v_i;
    END LOOP;
    v_check := substr(v_alphabet, (v_sum % 32) + 1, 1);

    RETURN v_code || v_check;
END;
$function$;

CREATE OR REPLACE FUNCTION public.home_summary()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid UUID := auth.uid();
    v_balance INT := 0;
    v_active_trivia JSONB;
    v_streak JSONB;
    v_next_game JSONB;
    v_my_rank INT := NULL;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    -- Balance
    SELECT COALESCE(balance_cache, 0) INTO v_balance FROM wallets WHERE fan_id = v_uid;

    -- Active Trivia (played is TRUE only if fan won it with pearls_awarded > 0, matching unlimited retries policy)
    SELECT jsonb_build_object(
        'id', t.id,
        'title', t.title,
        'description', t.description,
        'time_limit_seconds', t.time_limit_seconds,
        'starts_at', t.starts_at,
        'ends_at', t.ends_at,
        'max_attempts', t.max_attempts,
        'played', EXISTS (
            SELECT 1 FROM trivia_attempts ta 
            WHERE ta.fan_id = v_uid AND ta.trivia_id = t.id AND ta.submitted_at IS NOT NULL AND ta.pearls_awarded > 0
        )
    ) INTO v_active_trivia
    FROM trivias t
    WHERE t.status = 'published' AND NOW() BETWEEN t.starts_at AND t.ends_at
    ORDER BY t.starts_at DESC
    LIMIT 1;

    -- Read-only Streak Calculation (No ledger side-effects)
    v_streak := get_streak_info(v_uid);

    -- Next Game
    SELECT jsonb_build_object(
        'id', g.id,
        'opponent', g.opponent,
        'location', g.location,
        'game_date', g.game_date,
        'is_home', g.is_home,
        'status', g.status
    ) INTO v_next_game
    FROM games g
    WHERE g.status IN ('scheduled', 'live')
    ORDER BY g.game_date ASC
    LIMIT 1;

    -- Rank
    SELECT rank_number INTO v_my_rank
    FROM (
        SELECT 
            p.id AS fan_id,
            ROW_NUMBER() OVER (ORDER BY COALESCE(SUM(l.amount), 0) DESC) AS rank_number
        FROM profiles p
        JOIN ledger_entries l ON l.fan_id = p.id
        WHERE p.status = 'active' AND p.deleted_at IS NULL AND l.status = 'confirmed' AND l.created_at >= date_trunc('month', NOW())
        GROUP BY p.id
    ) ranks
    WHERE ranks.fan_id = v_uid;

    RETURN jsonb_build_object(
        'balance', v_balance,
        'active_trivia', v_active_trivia,
        'streak', v_streak,
        'next_game', v_next_game,
        'my_rank', v_my_rank
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.import_ad_report(p_day date, p_impressions integer, p_notes text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_completed_count INT := 0;
    v_ratio NUMERIC := 0;
    v_alert_created BOOLEAN := false;
BEGIN
    PERFORM public.assert_admin();

    IF p_impressions < 0 THEN
        RAISE EXCEPTION 'El número de impresiones no puede ser negativo.';
    END IF;

    INSERT INTO public.ad_reconciliation (day, google_rewarded_impressions, imported_by, imported_at, notes)
    VALUES (p_day, p_impressions, v_admin_id, NOW(), p_notes)
    ON CONFLICT (day) DO UPDATE
    SET google_rewarded_impressions = EXCLUDED.google_rewarded_impressions,
        imported_by = EXCLUDED.imported_by,
        imported_at = NOW(),
        notes = EXCLUDED.notes;

    -- Count total completed ad sessions in DB for this day
    SELECT COUNT(*) INTO v_completed_count
    FROM public.ad_sessions
    WHERE day = p_day AND status = 'completed';

    -- Ratio calculation (our DB completions / Google reported impressions)
    IF p_impressions > 0 THEN
        v_ratio := round((v_completed_count::numeric / p_impressions::numeric), 2);
    ELSIF v_completed_count > 0 THEN
        v_ratio := 99.9; -- Infinity alert threshold
    END IF;

    -- If ratio exceeds 1.2 threshold, flag system alert
    IF v_ratio > 1.2 THEN
        INSERT INTO public.system_alerts (
            type, title, message, severity, entity_id
        ) VALUES (
            'ad_discrepancy',
            'Discrepancia detectada en anuncios recompensados (' || p_day::text || ')',
            'Las sesiones completadas en DB (' || v_completed_count || ') superan las impresiones de Google GAM (' || p_impressions || ') por una proporción de ' || v_ratio || ' (límite: 1.2). Posible intento de manipulación del cliente.',
            'high',
            p_day::text
        );
        v_alert_created := true;
    END IF;

    -- Audit log entry
    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        v_admin_id, 'import_ad_report', 'ad_reconciliation', p_day::text,
        NULL, jsonb_build_object('impressions', p_impressions, 'completed_db', v_completed_count, 'ratio', v_ratio, 'alert_created', v_alert_created)
    );

    RETURN jsonb_build_object(
        'success', true,
        'day', p_day,
        'google_impressions', p_impressions,
        'db_completed_sessions', v_completed_count,
        'discrepancy_ratio', v_ratio,
        'alert_flagged', v_alert_created
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.mark_all_notifications_read()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_count INT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    WITH updated AS (
        UPDATE public.notifications
        SET read_at = NOW()
        WHERE user_id = v_user_id AND read_at IS NULL
        RETURNING id
    )
    SELECT COUNT(*) INTO v_count FROM updated;

    RETURN jsonb_build_object('success', true, 'updated_count', v_count);
END;
$function$;

CREATE OR REPLACE FUNCTION public.mark_notification_read(p_notification_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    UPDATE public.notifications
    SET read_at = NOW()
    WHERE id = p_notification_id AND user_id = v_user_id AND read_at IS NULL;

    RETURN jsonb_build_object('success', true);
END;
$function$;

CREATE OR REPLACE FUNCTION public.parse_instagram_shortcode(p_url text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_parts TEXT[];
BEGIN
    IF p_url IS NULL THEN RETURN NULL; END IF;
    IF p_url LIKE '%/p/%' THEN
        v_parts := string_to_array(p_url, '/p/');
        IF array_length(v_parts, 1) >= 2 THEN
            RETURN split_part(v_parts[2], '/', 1);
        END IF;
    ELSIF p_url LIKE '%/reel/%' THEN
        v_parts := string_to_array(p_url, '/reel/');
        IF array_length(v_parts, 1) >= 2 THEN
            RETURN split_part(v_parts[2], '/', 1);
        END IF;
    END IF;
    RETURN NULL;
END;
$function$;

CREATE OR REPLACE FUNCTION public.prevent_audit_log_mutation()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    RAISE EXCEPTION 'Audit Log entries are immutable. UPDATE and DELETE operations are forbidden.';
END;
$function$;

CREATE OR REPLACE FUNCTION public.prevent_ledger_mutation()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    RAISE EXCEPTION 'Financial Ledger entries are immutable. UPDATE and DELETE operations are forbidden.';
END;
$function$;

CREATE OR REPLACE FUNCTION public.purge_auth_identities(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
    v_deleted_count INT := 0;
BEGIN
    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'User ID is required.';
    END IF;

    DELETE FROM auth.identities WHERE user_id = p_user_id;
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

    RETURN jsonb_build_object(
        'success', true,
        'purged_user_id', p_user_id,
        'identities_removed', v_deleted_count
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.purge_fraud_telemetry()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    DELETE FROM public.fraud_telemetry WHERE created_at < NOW() - INTERVAL '30 days';
    DELETE FROM public.captcha_passes WHERE expires_at < NOW() - INTERVAL '1 day';
    DELETE FROM public.rate_limits WHERE window_start < NOW() - INTERVAL '1 day';
END;
$function$;

CREATE OR REPLACE FUNCTION public.reconcile_wallets()
 RETURNS TABLE(fan_id uuid, balance_cache integer, computed_balance integer, difference integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_actor_id UUID := auth.uid();
BEGIN
    IF v_actor_id IS NOT NULL AND NOT is_admin(v_actor_id) THEN
        RAISE EXCEPTION 'Only service_role or admin can run wallet reconciliation.';
    END IF;

    RETURN QUERY
    SELECT 
        w.fan_id,
        w.balance_cache,
        COALESCE(sub.sum_amount, 0)::INT AS computed_balance,
        (w.balance_cache - COALESCE(sub.sum_amount, 0))::INT AS difference
    FROM wallets w
    LEFT JOIN (
        SELECT le.fan_id, SUM(le.amount) AS sum_amount
        FROM ledger_entries le
        WHERE le.status = 'confirmed'
        GROUP BY le.fan_id
    ) sub ON sub.fan_id = w.fan_id
    WHERE w.balance_cache != COALESCE(sub.sum_amount, 0);
END;
$function$;

CREATE OR REPLACE FUNCTION public.redeem_product(p_product_id uuid, p_variant text, p_idempotency_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_fan_id UUID := auth.uid();
    v_product products%ROWTYPE;
    v_wallet wallets%ROWTYPE;
    v_profile profiles%ROWTYPE;
    v_existing_redemption redemptions%ROWTYPE;
    v_redemption_id UUID;
    v_code TEXT;
    v_code_hash TEXT;
    v_account_age_days INT;
    v_trivias_completed INT;

    -- Dynamic risk settings
    v_high_val_pearls INT := 3000;
    v_min_age_days INT := 7;
    v_min_trivias INT := 3;
    v_setting_record RECORD;
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    IF p_idempotency_key IS NULL OR trim(p_idempotency_key) = '' THEN
        RAISE EXCEPTION 'Idempotency key is required.';
    END IF;

    -- Rate limiting (Max 3 redemptions per 60s)
    PERFORM public.check_rate_limit(v_fan_id, 'redeem_product', 3, 60);

    -- 1. Check Idempotency
    SELECT * INTO v_existing_redemption 
    FROM redemptions 
    WHERE fan_id = v_fan_id AND idempotency_key = p_idempotency_key;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'redemption_id', v_existing_redemption.id,
            'code_hash', v_existing_redemption.code_hash,
            'status', v_existing_redemption.status,
            'cost_pearls', v_existing_redemption.cost_pearls,
            'variant', v_existing_redemption.variant,
            'reused', true
        );
    END IF;

    -- 2. Lock product FOR UPDATE
    SELECT * INTO v_product FROM products WHERE id = p_product_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'PRODUCT_NOT_FOUND: El producto solicitado no existe.';
    END IF;

    IF NOT v_product.active THEN
        RAISE EXCEPTION 'PRODUCT_INACTIVE: El producto no está disponible.';
    END IF;

    IF v_product.valid_until IS NOT NULL AND NOW() > v_product.valid_until THEN
        RAISE EXCEPTION 'PRODUCT_EXPIRED: La oferta de este premio ha expirado.';
    END IF;

    IF v_product.stock <= 0 THEN
        RAISE EXCEPTION 'OUT_OF_STOCK: El producto está agotado.';
    END IF;

    -- 3. Read dynamic risk settings
    FOR v_setting_record IN SELECT key, value FROM public.risk_settings LOOP
        IF v_setting_record.key = 'high_value_product_pearls' THEN
            v_high_val_pearls := (v_setting_record.value#>>'{}')::int;
        ELSIF v_setting_record.key = 'min_account_age_days' THEN
            v_min_age_days := (v_setting_record.value#>>'{}')::int;
        ELSIF v_setting_record.key = 'min_trivias_completed' THEN
            v_min_trivias := (v_setting_record.value#>>'{}')::int;
        END IF;
    END LOOP;

    -- Proportional Friction Check for High Value Products
    IF v_product.cost_pearls >= v_high_val_pearls THEN
        SELECT * INTO v_profile FROM profiles WHERE id = v_fan_id;
        v_account_age_days := EXTRACT(DAY FROM (NOW() - v_profile.created_at));

        SELECT COUNT(DISTINCT trivia_id) INTO v_trivias_completed
        FROM trivia_attempts
        WHERE fan_id = v_fan_id AND submitted_at IS NOT NULL;

        IF v_account_age_days < v_min_age_days OR v_trivias_completed < v_min_trivias THEN
            RAISE EXCEPTION 'ACCOUNT_TOO_NEW: Para canjear premios de alto valor debes tener al menos % días registrado y % trivias completadas.', v_min_age_days, v_min_trivias;
        END IF;
    END IF;

    -- 4. Lock wallet FOR UPDATE
    SELECT * INTO v_wallet FROM wallets WHERE fan_id = v_fan_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'INSUFFICIENT_PERLITAS: Billetera no inicializada.';
    END IF;

    IF v_wallet.balance_cache < v_product.cost_pearls THEN
        RAISE EXCEPTION 'INSUFFICIENT_PERLITAS: Saldo insuficiente (Requerido: %, Disponible: %).', v_product.cost_pearls, v_wallet.balance_cache;
    END IF;

    -- 5. Deterministic UUID + HMAC QR Code + Hash Generation
    v_redemption_id := gen_random_uuid();
    v_code := generate_redemption_code(v_redemption_id);
    v_code_hash := compute_redemption_code_hash(v_code);

    -- 6. Atomic Transaction
    -- A) Deduct Stock
    UPDATE products SET stock = stock - 1 WHERE id = p_product_id;

    -- B) Insert Negative Ledger Entry
    INSERT INTO ledger_entries (
        fan_id, amount, type, status, source_type, source_id, note
    ) VALUES (
        v_fan_id, -v_product.cost_pearls, 'redemption', 'confirmed', 'redemption', v_redemption_id::text,
        'Canje de premio: ' || v_product.name
    );

    -- C) Update Wallet Balance Cache
    UPDATE wallets 
    SET balance_cache = balance_cache - v_product.cost_pearls, updated_at = NOW() 
    WHERE fan_id = v_fan_id;

    -- D) Create Redemption Record
    INSERT INTO redemptions (
        id, fan_id, product_id, variant, cost_pearls, status, code_hash, idempotency_key, expires_at, created_at
    ) VALUES (
        v_redemption_id, v_fan_id, p_product_id, p_variant, v_product.cost_pearls, 'pending', v_code_hash, p_idempotency_key, NOW() + INTERVAL '30 days', NOW()
    );

    -- E) Redemption History
    INSERT INTO redemption_history (redemption_id, previous_status, new_status, changed_by, note)
    VALUES (v_redemption_id, NULL, 'pending', v_fan_id, 'Canje iniciado por el fanático');

    RETURN jsonb_build_object(
        'redemption_id', v_redemption_id,
        'code_hash', v_code_hash,
        'status', 'pending',
        'cost_pearls', v_product.cost_pearls,
        'variant', p_variant,
        'reused', false
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.refresh_analytics_materialized_views()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    -- Assert admin if called by an authenticated user; allow service_role / pg_cron (auth.uid() IS NULL)
    IF auth.uid() IS NOT NULL THEN
        PERFORM public.assert_admin();
    END IF;

    REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_daily_fan_activity;
    REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_daily_economy_stats;
    REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_demographics;
END;
$function$;

CREATE OR REPLACE FUNCTION public.register_email_send_attempt()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_period TEXT := to_char(NOW() AT TIME ZONE 'America/Caracas', 'YYYY-MM');
    v_tracker public.email_usage_tracker%ROWTYPE;
    v_key_index INT := 1;
    v_admin_fan_id UUID;
BEGIN
    -- Select or initialize monthly tracker row FOR UPDATE
    SELECT * INTO v_tracker 
    FROM public.email_usage_tracker 
    WHERE period_yyyy_mm = v_period 
    FOR UPDATE;

    IF NOT FOUND THEN
        INSERT INTO public.email_usage_tracker (period_yyyy_mm, total_sent, active_key_index)
        VALUES (v_period, 0, 1)
        RETURNING * INTO v_tracker;
    END IF;

    -- Check if total monthly limit (6,000 emails across both keys) is reached
    IF v_tracker.total_sent >= 6000 THEN
        -- Send alert to admin incidents queue (risk_flags) if not already logged
        IF NOT v_tracker.limit_reached_alert_sent THEN
            SELECT p.id INTO v_admin_fan_id 
            FROM public.profiles p
            JOIN public.staff_members s ON s.user_id = p.id AND s.role = 'admin'
            LIMIT 1;

            IF v_admin_fan_id IS NULL THEN
                SELECT id INTO v_admin_fan_id FROM public.profiles ORDER BY created_at ASC LIMIT 1;
            END IF;

            IF v_admin_fan_id IS NOT NULL THEN
                INSERT INTO public.risk_flags (fan_id, reason, severity, resolved)
                VALUES (
                    v_admin_fan_id,
                    'EMAIL_QUOTA_EXHAUSTED: Ambas API keys de Resend alcanzaron el límite de 3.000 correos mensuales (6.000 total) en el periodo ' || v_period,
                    'high',
                    false
                );
            END IF;

            UPDATE public.email_usage_tracker
            SET limit_reached_alert_sent = true, updated_at = NOW()
            WHERE period_yyyy_mm = v_period;
        END IF;

        RAISE EXCEPTION 'Servicio en mantenimiento. Por favor espera unos minutos antes de volver a intentarlo.' USING ERRCODE = 'P0001';
    END IF;

    -- Key rotation: 0..2999 -> Key 1 | 3000..5999 -> Key 2
    IF v_tracker.total_sent < 3000 THEN
        v_key_index := 1;
    ELSE
        v_key_index := 2;
    END IF;

    -- Increment counter and update tracker
    UPDATE public.email_usage_tracker
    SET total_sent = total_sent + 1,
        active_key_index = v_key_index,
        updated_at = NOW()
    WHERE period_yyyy_mm = v_period;

    RETURN jsonb_build_object(
        'key_index', v_key_index,
        'total_sent', v_tracker.total_sent + 1,
        'period', v_period
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.register_push_subscription(p_endpoint text, p_p256dh text, p_auth text, p_user_agent text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    IF p_endpoint IS NULL OR trim(p_endpoint) = '' THEN
        RAISE EXCEPTION 'Endpoint is required.';
    END IF;

    INSERT INTO public.push_subscriptions (user_id, endpoint, p256dh, auth, user_agent, disabled_at)
    VALUES (v_user_id, p_endpoint, p_p256dh, p_auth, p_user_agent, NULL)
    ON CONFLICT (endpoint) DO UPDATE
    SET user_id = EXCLUDED.user_id,
        p256dh = EXCLUDED.p256dh,
        auth = EXCLUDED.auth,
        user_agent = EXCLUDED.user_agent,
        disabled_at = NULL;

    RETURN jsonb_build_object('success', true);
END;
$function$;

CREATE OR REPLACE FUNCTION public.reject_redemption(p_redemption_id uuid, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_staff_id UUID := auth.uid();
    v_redemption public.redemptions%ROWTYPE;
    v_refunded BOOLEAN;
BEGIN
    PERFORM assert_staff();

    IF p_reason IS NULL OR trim(p_reason) = '' THEN
        RAISE EXCEPTION 'Motivo de rechazo es obligatorio.';
    END IF;

    SELECT * INTO v_redemption
    FROM public.redemptions
    WHERE id = p_redemption_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Canje no encontrado.';
    END IF;

    IF v_redemption.status = 'rejected' THEN
        RAISE EXCEPTION 'El canje ya ha sido rechazado previamente.';
    END IF;

    IF v_redemption.status IN ('delivered', 'completed', 'cancelled') THEN
        RAISE EXCEPTION 'No se puede rechazar un canje en estado "%".', v_redemption.status;
    END IF;

    UPDATE public.redemptions
    SET status = 'rejected'
    WHERE id = v_redemption.id;

    SELECT EXISTS (
        SELECT 1 FROM public.ledger_entries 
        WHERE source_id = v_redemption.id::text 
          AND source_type = 'redemption_refund'
    ) INTO v_refunded;

    IF NOT v_refunded THEN
        INSERT INTO public.ledger_entries (fan_id, amount, type, status, source_type, source_id, note, created_by)
        VALUES (
            v_redemption.fan_id,
            v_redemption.cost_pearls,
            'refund',
            'confirmed',
            'redemption_refund',
            v_redemption.id::text,
            'Reembolso por rechazo de canje: ' || p_reason,
            v_staff_id
        );

        UPDATE public.wallets
        SET balance_cache = balance_cache + v_redemption.cost_pearls,
            updated_at = NOW()
        WHERE fan_id = v_redemption.fan_id;
    END IF;

    INSERT INTO public.redemption_history (redemption_id, previous_status, new_status, changed_by, note)
    VALUES (v_redemption.id, v_redemption.status, 'rejected', v_staff_id, p_reason);

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        v_staff_id, 'reject_redemption', 'redemptions', v_redemption.id::text,
        jsonb_build_object('status', v_redemption.status),
        jsonb_build_object('status', 'rejected', 'reason', p_reason, 'refunded_pearls', v_redemption.cost_pearls)
    );

    PERFORM public.create_notification(
        v_redemption.fan_id,
        'redemption_rejected',
        'Canje rechazado',
        'Tu canje ha sido rechazado: ' || p_reason || '. Las perlitas han sido reembolsadas a tu billetera.',
        jsonb_build_object('redemption_id', v_redemption.id, 'url', '/app/canjes/' || v_redemption.id),
        'redemption_rejected_' || v_redemption.id
    );

    RETURN jsonb_build_object(
        'redemption_id', v_redemption.id,
        'status', 'rejected',
        'refunded_pearls', v_redemption.cost_pearls
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.report_redemption_issue(p_redemption_id uuid, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_staff_id UUID := auth.uid();
    v_redemption redemptions%ROWTYPE;
BEGIN
    IF NOT is_staff_or_admin(v_staff_id) THEN
        RAISE EXCEPTION 'Staff or Admin authorization required.';
    END IF;

    IF p_reason IS NULL OR trim(p_reason) = '' THEN
        RAISE EXCEPTION 'A reason is required to report an issue.';
    END IF;

    -- Lock redemption FOR UPDATE
    SELECT * INTO v_redemption FROM redemptions WHERE id = p_redemption_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Redemption not found.';
    END IF;

    IF v_redemption.status NOT IN ('delivered', 'approved', 'scheduled') THEN
        RAISE EXCEPTION 'Cannot report an issue for redemption in status %', v_redemption.status;
    END IF;

    -- Transition to issue
    UPDATE redemptions SET status = 'issue' WHERE id = v_redemption.id;

    -- History log
    INSERT INTO redemption_history (redemption_id, previous_status, new_status, changed_by, note)
    VALUES (v_redemption.id, v_redemption.status, 'issue', v_staff_id, p_reason);

    -- Audit log
    INSERT INTO audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        v_staff_id, 'report_redemption_issue', 'redemptions', v_redemption.id::text,
        jsonb_build_object('status', v_redemption.status),
        jsonb_build_object('status', 'issue', 'reason', p_reason)
    );

    RETURN jsonb_build_object(
        'redemption_id', v_redemption.id,
        'previous_status', v_redemption.status,
        'status', 'issue',
        'reason', p_reason
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.report_redemption_issue(p_redemption_id uuid, p_reason text, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_staff_id UUID := auth.uid();
    v_redemption public.redemptions%ROWTYPE;
BEGIN
    PERFORM assert_staff();

    IF p_reason NOT IN ('wrong_size', 'damaged', 'identity_mismatch', 'out_of_stock_physical', 'other') THEN
        RAISE EXCEPTION 'Motivo de incidencia no válido. Debe ser: wrong_size, damaged, identity_mismatch, out_of_stock_physical o other.';
    END IF;

    SELECT * INTO v_redemption
    FROM public.redemptions
    WHERE id = p_redemption_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Canje no encontrado.';
    END IF;

    UPDATE public.redemptions
    SET status = 'issue'
    WHERE id = v_redemption.id;

    INSERT INTO public.redemption_history (redemption_id, previous_status, new_status, changed_by, note)
    VALUES (v_redemption.id, v_redemption.status, 'issue', v_staff_id, COALESCE(p_note, 'Incidencia reportada: ' || p_reason));

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        v_staff_id, 'report_redemption_issue', 'redemptions', v_redemption.id::text,
        jsonb_build_object('status', v_redemption.status),
        jsonb_build_object('status', 'issue', 'reason', p_reason, 'note', p_note)
    );

    PERFORM public.create_notification(
        v_redemption.fan_id,
        'redemption_issue',
        'Incidencia en tu canje',
        'Se ha registrado un reporte sobre tu canje.',
        jsonb_build_object('redemption_id', v_redemption.id, 'url', '/app/canjes/' || v_redemption.id),
        'redemption_issue_' || v_redemption.id
    );

    RETURN jsonb_build_object(
        'redemption_id', v_redemption.id,
        'status', 'issue',
        'reason', p_reason
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.rls_auto_enable()
 RETURNS event_trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$function$;

CREATE OR REPLACE FUNCTION public.run_daily_wallet_reconciliation()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_mismatches INT := 0;
  v_rec RECORD;
BEGIN
  FOR v_rec IN SELECT * FROM public.reconcile_wallets() LOOP
    v_mismatches := v_mismatches + 1;
    INSERT INTO public.system_alerts (alert_type, severity, message, metadata)
    VALUES (
      'wallet_mismatch',
      'critical',
      'Descalce detectado en billetera de usuario: ' || v_rec.fan_id::text,
      jsonb_build_object(
        'user_id', v_rec.fan_id,
        'cached_balance', v_rec.balance_cache,
        'ledger_calculated', v_rec.computed_balance,
        'diff', v_rec.difference
      )
    );
  END LOOP;
END;
$function$;

CREATE OR REPLACE FUNCTION public.save_mfa_recovery_code_hashes(p_hashes text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_uid UUID := auth.uid();
    v_aal TEXT := (auth.jwt() ->> 'aal');
    v_hash TEXT;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Usuario no autenticado' USING ERRCODE = '42501';
    END IF;

    -- Replace existing recovery codes for user
    DELETE FROM public.mfa_recovery_codes WHERE user_id = v_uid;

    FOREACH v_hash IN ARRAY p_hashes LOOP
        INSERT INTO public.mfa_recovery_codes (user_id, code_hash)
        VALUES (v_uid, v_hash);
    END LOOP;

    RETURN jsonb_build_object('success', true, 'count', array_length(p_hashes, 1));
END;
$function$;

CREATE OR REPLACE FUNCTION public.seed_analytics_performance_data(p_num_fans integer DEFAULT 1000, p_num_ledger integer DEFAULT 5000)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_fan_ids UUID[];
    v_product_id UUID;
    v_trivia_id UUID;
BEGIN
    PERFORM public.assert_admin();

    -- Ensure a sample product and trivia exist
    SELECT id INTO v_product_id FROM public.products LIMIT 1;
    SELECT id INTO v_trivia_id FROM public.trivias LIMIT 1;

    -- Bulk generate synthetic profiles & wallets
    INSERT INTO public.profiles (id, display_name, municipality, gender, status, created_at)
    SELECT
        gen_random_uuid(),
        'PerfFan_' || i,
        (ARRAY['Mariño', 'Maneiro', 'Arismendi', 'García', 'Tubores'])[1 + (i % 5)],
        (ARRAY['Masculino', 'Femenino', 'Otro'])[1 + (i % 3)],
        'active',
        NOW() - (i || ' minutes')::INTERVAL
    FROM generate_series(1, LEAST(p_num_fans, 50000)) AS i
    ON CONFLICT (id) DO NOTHING;

    -- Collect inserted fan IDs
    SELECT ARRAY_AGG(id) INTO v_fan_ids FROM public.profiles WHERE display_name LIKE 'PerfFan_%';

    -- Bulk generate wallets
    INSERT INTO public.wallets (fan_id, balance_cache)
    SELECT unnest(v_fan_ids), 500
    ON CONFLICT (fan_id) DO NOTHING;

    -- Bulk generate ledger entries
    INSERT INTO public.ledger_entries (fan_id, amount, type, status, source_type, source_id, created_at)
    SELECT
        v_fan_ids[1 + (i % ARRAY_LENGTH(v_fan_ids, 1))],
        CASE WHEN i % 2 = 0 THEN 100 ELSE -50 END,
        CASE WHEN i % 2 = 0 THEN 'trivia_reward'::ledger_type ELSE 'redemption'::ledger_type END,
        'confirmed'::ledger_status,
        'benchmark_test',
        'bench_' || i,
        NOW() - (i || ' seconds')::INTERVAL
    FROM generate_series(1, LEAST(p_num_ledger, 500000)) AS i;

    -- Refresh Materialized Views
    PERFORM public.refresh_analytics_materialized_views();

    RETURN jsonb_build_object(
        'status', 'success',
        'fans_seeded', ARRAY_LENGTH(v_fan_ids, 1),
        'ledger_entries_seeded', p_num_ledger
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.segment_count(p_segment_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.segment_members(p_segment_id uuid, p_limit integer DEFAULT 50, p_cursor uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.send_test_birthday_notification()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
BEGIN
    PERFORM public.assert_admin();

    PERFORM public.create_notification(
        v_admin_id,
        'birthday',
        '¡Feliz cumpleaños, Guaiquerí! (Prueba Admin)',
        'Notificación de prueba del saludo de cumpleaños.',
        jsonb_build_object('url', '/app/cumpleanos'),
        'birthday_test:' || v_admin_id::text || ':' || extract(epoch from now())::text
    );

    RETURN jsonb_build_object('success', true);
END;
$function$;

CREATE OR REPLACE FUNCTION public.set_birth_date(p_birth_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_current_bdate DATE;
BEGIN
    PERFORM public.assert_active_verified_fan();

    IF p_birth_date IS NULL THEN
        RAISE EXCEPTION 'La fecha de nacimiento es obligatoria.';
    END IF;

    SELECT birth_date INTO v_current_bdate FROM public.profiles WHERE id = v_user_id;

    IF v_current_bdate IS NOT NULL THEN
        RAISE EXCEPTION 'La fecha de nacimiento no puede ser modificada una vez registrada.';
    END IF;

    UPDATE public.profiles
    SET birth_date = p_birth_date,
        updated_at = NOW()
    WHERE id = v_user_id;

    RETURN jsonb_build_object('success', true, 'birth_date', p_birth_date);
END;
$function$;

CREATE OR REPLACE FUNCTION public.staff_redemption_queue(p_status text DEFAULT NULL::text, p_search text DEFAULT NULL::text, p_cursor timestamp with time zone DEFAULT NULL::timestamp with time zone, p_limit integer DEFAULT 20)
 RETURNS TABLE(id uuid, status redemption_status, variant text, cost_pearls integer, created_at timestamp with time zone, expires_at timestamp with time zone, delivered_at timestamp with time zone, fan_id uuid, fan_display_name text, fan_avatar_url text, product_id uuid, product_name text, product_category product_category)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_eff_limit INT := LEAST(GREATEST(p_limit, 1), 50);
BEGIN
    PERFORM assert_staff();

    RETURN QUERY
    SELECT 
        r.id,
        r.status,
        r.variant,
        r.cost_pearls,
        r.created_at,
        r.expires_at,
        r.delivered_at,
        p.id AS fan_id,
        p.display_name AS fan_display_name,
        p.avatar_url AS fan_avatar_url,
        pr.id AS product_id,
        pr.name AS product_name,
        pr.category AS product_category
    FROM public.redemptions r
    JOIN public.profiles p ON p.id = r.fan_id
    JOIN public.products pr ON pr.id = r.product_id
    WHERE (p_status IS NULL OR p_status = '' OR r.status::text = p_status)
      AND (p_search IS NULL OR p_search = '' OR (p.display_name ILIKE '%' || p_search || '%' OR pr.name ILIKE '%' || p_search || '%'))
      AND (p_cursor IS NULL OR r.created_at > p_cursor)
    ORDER BY r.created_at ASC
    LIMIT v_eff_limit;
END;
$function$;

CREATE OR REPLACE FUNCTION public.staff_search_fans(p_query text, p_limit integer DEFAULT 20)
 RETURNS TABLE(id uuid, display_name text, avatar_url text, status text, pearl_balance integer, last_5_redemptions jsonb)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_staff_id UUID := auth.uid();
    v_eff_limit INT := LEAST(GREATEST(p_limit, 1), 20);
    v_clean_query TEXT := trim(COALESCE(p_query, ''));
BEGIN
    PERFORM assert_staff();

    IF length(v_clean_query) < 3 THEN
        RAISE EXCEPTION 'La búsqueda requiere al menos 3 caracteres.';
    END IF;

    -- Registrar consulta en audit_log
    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        v_staff_id,
        'staff_search_fans',
        'profiles',
        NULL,
        NULL,
        jsonb_build_object('query', v_clean_query)
    );

    RETURN QUERY
    SELECT 
        p.id,
        p.display_name,
        p.avatar_url,
        p.status::text,
        COALESCE(w.balance_cache, 0) AS pearl_balance,
        COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', r.id,
                    'product_name', pr.name,
                    'variant', r.variant,
                    'cost_pearls', r.cost_pearls,
                    'status', r.status,
                    'created_at', r.created_at
                )
            )
            FROM (
                SELECT r_sub.*
                FROM public.redemptions r_sub
                WHERE r_sub.fan_id = p.id
                ORDER BY r_sub.created_at DESC
                LIMIT 5
            ) r
            JOIN public.products pr ON pr.id = r.product_id
        ), '[]'::jsonb) AS last_5_redemptions
    FROM public.profiles p
    LEFT JOIN public.wallets w ON w.fan_id = p.id
    WHERE p.display_name ILIKE '%' || v_clean_query || '%'
    LIMIT v_eff_limit;
END;
$function$;

CREATE OR REPLACE FUNCTION public.staff_upsert_product(p_product jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_staff_id UUID := auth.uid();
    v_product_id UUID;
    v_is_new BOOLEAN := false;
BEGIN
    PERFORM public.assert_staff();

    IF p_product->>'id' IS NOT NULL AND (p_product->>'id') != '' THEN
        v_product_id := (p_product->>'id')::uuid;
    ELSE
        v_product_id := gen_random_uuid();
        v_is_new := true;
    END IF;

    INSERT INTO public.products (
        id, name, description, category, cost_pearls, stock, active, image_url, valid_until
    ) VALUES (
        v_product_id,
        p_product->>'name',
        p_product->>'description',
        (p_product->>'category')::product_category,
        (p_product->>'cost_pearls')::int,
        (p_product->>'stock')::int,
        COALESCE((p_product->>'active')::boolean, true),
        p_product->>'image_url',
        CASE WHEN p_product->>'valid_until' IS NOT NULL THEN (p_product->>'valid_until')::timestamptz ELSE NULL END
    )
    ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        description = EXCLUDED.description,
        category = EXCLUDED.category,
        cost_pearls = EXCLUDED.cost_pearls,
        stock = EXCLUDED.stock,
        active = EXCLUDED.active,
        image_url = EXCLUDED.image_url,
        valid_until = EXCLUDED.valid_until;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_staff_id, 'staff_upsert_product', 'products', v_product_id::text,
        p_product
    );

    RETURN jsonb_build_object('success', true, 'id', v_product_id, 'is_new', v_is_new);
END;
$function$;

CREATE OR REPLACE FUNCTION public.staff_upsert_trivia(p_trivia jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_staff_id UUID := auth.uid();
    v_trivia_id UUID;
    v_is_new BOOLEAN := false;
BEGIN
    PERFORM public.assert_staff();

    IF p_trivia->>'id' IS NOT NULL AND (p_trivia->>'id') != '' THEN
        v_trivia_id := (p_trivia->>'id')::uuid;
    ELSE
        v_trivia_id := gen_random_uuid();
        v_is_new := true;
    END IF;

    INSERT INTO public.trivias (
        id, title, description, starts_at, ends_at, status, max_attempts, time_limit_seconds, reward_rules
    ) VALUES (
        v_trivia_id,
        p_trivia->>'title',
        p_trivia->>'description',
        (p_trivia->>'starts_at')::timestamptz,
        (p_trivia->>'ends_at')::timestamptz,
        COALESCE(p_trivia->>'status', 'draft')::trivia_status,
        COALESCE((p_trivia->>'max_attempts')::int, 1),
        COALESCE((p_trivia->>'time_limit_seconds')::int, 60),
        COALESCE(p_trivia->'reward_rules', '{"per_correct_pearls": 50}'::jsonb)
    )
    ON CONFLICT (id) DO UPDATE SET
        title = EXCLUDED.title,
        description = EXCLUDED.description,
        starts_at = EXCLUDED.starts_at,
        ends_at = EXCLUDED.ends_at,
        status = EXCLUDED.status,
        max_attempts = EXCLUDED.max_attempts,
        time_limit_seconds = EXCLUDED.time_limit_seconds,
        reward_rules = EXCLUDED.reward_rules;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_staff_id, 'staff_upsert_trivia', 'trivias', v_trivia_id::text,
        p_trivia
    );

    RETURN jsonb_build_object('success', true, 'id', v_trivia_id, 'is_new', v_is_new);
END;
$function$;

CREATE OR REPLACE FUNCTION public.staff_upsert_trivia(p_trivia jsonb, p_questions jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_staff_id UUID := auth.uid();
    v_trivia_id UUID;
    v_is_new BOOLEAN := false;
    v_attempt_count INT := 0;
    v_q_elem JSONB;
    v_opt_elem JSONB;
    v_q_id UUID;
BEGIN
    PERFORM public.assert_staff();

    IF p_trivia->>'id' IS NOT NULL AND (p_trivia->>'id') != '' THEN
        v_trivia_id := (p_trivia->>'id')::uuid;
        SELECT COUNT(*) INTO v_attempt_count FROM public.trivia_attempts WHERE trivia_id = v_trivia_id;

        IF v_attempt_count > 0 AND p_questions IS NOT NULL THEN
            RAISE EXCEPTION 'No se pueden modificar preguntas u opciones de una trivia con intentos registrados. Duplique o archive la trivia.';
        END IF;
    ELSE
        v_trivia_id := gen_random_uuid();
        v_is_new := true;
    END IF;

    IF v_is_new THEN
        INSERT INTO public.trivias (
            id, title, description, status, starts_at, ends_at, time_limit_seconds, reward_rules, max_attempts, target_segment_id
        ) VALUES (
            v_trivia_id,
            p_trivia->>'title',
            p_trivia->>'description',
            COALESCE((p_trivia->>'status')::trivia_status, 'draft'::trivia_status),
            (p_trivia->>'starts_at')::TIMESTAMPTZ,
            (p_trivia->>'ends_at')::TIMESTAMPTZ,
            COALESCE((p_trivia->>'time_limit_seconds')::INT, 60),
            COALESCE(p_trivia->'reward_rules', '{"per_correct_pearls": 50, "perfect_score_bonus": 100}'::jsonb),
            COALESCE((p_trivia->>'max_attempts')::INT, 1),
            NULLIF(p_trivia->>'target_segment_id', '')::UUID
        );
    ELSE
        UPDATE public.trivias SET
            title = COALESCE(p_trivia->>'title', title),
            description = COALESCE(p_trivia->>'description', description),
            status = COALESCE((p_trivia->>'status')::trivia_status, status),
            starts_at = COALESCE((p_trivia->>'starts_at')::TIMESTAMPTZ, starts_at),
            ends_at = COALESCE((p_trivia->>'ends_at')::TIMESTAMPTZ, ends_at),
            time_limit_seconds = COALESCE((p_trivia->>'time_limit_seconds')::INT, time_limit_seconds),
            reward_rules = COALESCE(p_trivia->'reward_rules', reward_rules),
            max_attempts = COALESCE((p_trivia->>'max_attempts')::INT, max_attempts),
            target_segment_id = CASE
                WHEN p_trivia ? 'target_segment_id' THEN NULLIF(p_trivia->>'target_segment_id', '')::UUID
                ELSE target_segment_id
            END
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
    VALUES (
        v_staff_id, 'staff_upsert_trivia', 'trivias', v_trivia_id::text,
        p_trivia
    );

    RETURN jsonb_build_object('success', true, 'id', v_trivia_id, 'is_new', v_is_new);
END;
$function$;

CREATE OR REPLACE FUNCTION public.start_ad_session(p_idempotency_key text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid UUID;
    v_today DATE := (NOW() AT TIME ZONE 'America/Caracas')::date;
    v_eco RECORD;
    v_completed INT := 0;
    v_account_age_days INT;
    v_trivias_count INT;
    v_pass_id UUID;
    v_session_id UUID;
BEGIN
    v_uid := public.assert_active_verified_fan();

    SELECT ads_enabled, daily_ad_views, block_size, ad_min_seconds, ad_min_account_age_days, ad_min_trivias_completed
    INTO v_eco
    FROM public.economy_settings
    ORDER BY created_at DESC LIMIT 1;

    IF v_eco.ads_enabled IS NOT TRUE THEN
        RAISE EXCEPTION 'Los anuncios están temporalmente desactivados.' USING ERRCODE = 'P0001';
    END IF;

    SELECT EXTRACT(DAY FROM (NOW() - created_at))::int INTO v_account_age_days
    FROM public.profiles WHERE id = v_uid;

    IF COALESCE(v_account_age_days, 0) < v_eco.ad_min_account_age_days THEN
        RAISE EXCEPTION 'Tu cuenta requiere al menos % días de antigüedad para ver anuncios.', v_eco.ad_min_account_age_days USING ERRCODE = 'P0001';
    END IF;

    SELECT COUNT(*) INTO v_trivias_count
    FROM public.trivia_attempts
    WHERE fan_id = v_uid AND submitted_at IS NOT NULL;

    IF v_trivias_count < v_eco.ad_min_trivias_completed THEN
        RAISE EXCEPTION 'Debes completar al menos % trivia para poder ver anuncios.', v_eco.ad_min_trivias_completed USING ERRCODE = 'P0001';
    END IF;

    -- Rate limiting check (max 10 session starts per minute)
    PERFORM public.check_rate_limit(v_uid, 'start_ad_session', 10, 60);

    -- Lock or check daily progress
    INSERT INTO public.ad_daily_progress (user_id, day, completed_count)
    VALUES (v_uid, v_today, 0)
    ON CONFLICT (user_id, day) DO UPDATE SET updated_at = NOW()
    RETURNING completed_count INTO v_completed;

    IF v_completed >= v_eco.daily_ad_views THEN
        RAISE EXCEPTION 'Has alcanzado el límite diario de 50 anuncios por hoy.' USING ERRCODE = 'P0001';
    END IF;

    -- Captcha pass required for the FIRST session of the day
    IF v_completed = 0 AND NOT EXISTS (SELECT 1 FROM public.ad_sessions WHERE user_id = v_uid AND day = v_today AND status = 'completed') THEN
        SELECT id INTO v_pass_id
        FROM public.captcha_passes
        WHERE user_id = v_uid AND used = false AND expires_at > NOW()
        ORDER BY created_at DESC
        LIMIT 1
        FOR UPDATE;

        IF v_pass_id IS NULL THEN
            RAISE EXCEPTION 'CAPTCHA_REQUIRED' USING ERRCODE = 'P0001';
        END IF;

        UPDATE public.captcha_passes SET used = true WHERE id = v_pass_id;
    END IF;

    -- Void any existing started session for this user
    UPDATE public.ad_sessions
    SET status = 'void', reason = 'superseded_by_new_session'
    WHERE user_id = v_uid AND status = 'started';

    -- Create new session
    INSERT INTO public.ad_sessions (user_id, started_at, status, day)
    VALUES (v_uid, NOW(), 'started', v_today)
    RETURNING id INTO v_session_id;

    RETURN jsonb_build_object(
        'session_id', v_session_id,
        'ad_min_seconds', v_eco.ad_min_seconds
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.start_trivia_attempt(p_trivia_id uuid, p_idempotency_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_fan_id UUID := auth.uid();
    v_trivia trivias%ROWTYPE;
    v_existing_attempt trivia_attempts%ROWTYPE;
    v_attempt_id UUID;
    v_expires_at TIMESTAMPTZ;
    v_seed INT;
    v_questions JSONB;
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    PERFORM public.assert_active_verified_fan(v_fan_id);

    -- Rate limiting (Max 5 attempts created per 60s)
    PERFORM public.check_rate_limit(v_fan_id, 'start_trivia_attempt', 5, 60);

    -- Fetch trivia
    SELECT * INTO v_trivia FROM trivias WHERE id = p_trivia_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Trivia not found.';
    END IF;

    IF v_trivia.status != 'published' THEN
        RAISE EXCEPTION 'Trivia is not active for participation.';
    END IF;

    -- Time Window Check
    IF NOW() < v_trivia.starts_at THEN
        RAISE EXCEPTION 'TRIVIA_NOT_STARTED';
    END IF;

    IF NOW() > v_trivia.ends_at THEN
        RAISE EXCEPTION 'TRIVIA_EXPIRED';
    END IF;

    -- Verify if the fan has already won this trivia (pearls_awarded > 0)
    IF EXISTS (
        SELECT 1 FROM trivia_attempts
        WHERE fan_id = v_fan_id
          AND trivia_id = p_trivia_id
          AND submitted_at IS NOT NULL
          AND pearls_awarded > 0
    ) THEN
        RAISE EXCEPTION 'TRIVIA_ALREADY_WON';
    END IF;

    -- Check Idempotency (Existing active attempt with same idempotency_key)
    SELECT * INTO v_existing_attempt 
    FROM trivia_attempts 
    WHERE fan_id = v_fan_id AND trivia_id = p_trivia_id AND idempotency_key = p_idempotency_key;

    IF FOUND THEN
        IF v_existing_attempt.submitted_at IS NOT NULL THEN
            RAISE EXCEPTION 'TRIVIA_ALREADY_PLAYED';
        END IF;

        IF NOW() > v_existing_attempt.expires_at THEN
            RAISE EXCEPTION 'ATTEMPT_EXPIRED';
        END IF;

        -- Return questions for existing attempt
        SELECT jsonb_agg(
            jsonb_build_object(
                'question_id', q.id,
                'question_text', q.question_text,
                'points', q.points,
                'options', (
                    SELECT jsonb_agg(
                        jsonb_build_object(
                            'option_id', o.id,
                            'option_text', o.option_text
                        )
                    ) FROM trivia_options o WHERE o.question_id = q.id
                )
            ) ORDER BY hashtext(q.id::text || v_existing_attempt.seed::text)
        ) INTO v_questions
        FROM trivia_questions q
        WHERE q.trivia_id = p_trivia_id;

        RETURN jsonb_build_object(
            'attempt_id', v_existing_attempt.id,
            'expires_at', v_existing_attempt.expires_at,
            'seed', v_existing_attempt.seed,
            'questions', COALESCE(v_questions, '[]'::jsonb),
            'reused', true
        );
    END IF;

    -- Create Attempt (expires at trivia ends_at, no artificial attempt countdown)
    v_expires_at := v_trivia.ends_at;
    v_seed := floor(random() * 1000000)::int;

    INSERT INTO trivia_attempts (
        fan_id, trivia_id, started_at, expires_at, seed, idempotency_key
    ) VALUES (
        v_fan_id, p_trivia_id, NOW(), v_expires_at, v_seed, p_idempotency_key
    )
    RETURNING id INTO v_attempt_id;

    -- Fetch questions (WITHOUT is_correct)
    SELECT jsonb_agg(
        jsonb_build_object(
            'question_id', q.id,
            'question_text', q.question_text,
            'points', q.points,
            'options', (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'option_id', o.id,
                        'option_text', o.option_text
                    )
                ) FROM trivia_options o WHERE o.question_id = q.id
            )
        ) ORDER BY hashtext(q.id::text || v_seed::text)
    ) INTO v_questions
    FROM trivia_questions q
    WHERE q.trivia_id = p_trivia_id;

    RETURN jsonb_build_object(
        'attempt_id', v_attempt_id,
        'expires_at', v_expires_at,
        'seed', v_seed,
        'questions', COALESCE(v_questions, '[]'::jsonb),
        'reused', false
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.submit_trivia_attempt(p_attempt_id uuid, p_answers jsonb, p_idempotency_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_fan_id UUID := auth.uid();
    v_attempt trivia_attempts%ROWTYPE;
    v_trivia trivias%ROWTYPE;
    v_time_spent_seconds NUMERIC;
    v_is_suspicious BOOLEAN := false;
    v_score INT := 0;
    v_raw_pearls INT := 0;
    v_final_pearls INT := 0;
    v_per_correct_pearls INT;
    v_perfect_bonus INT := 0;
    v_total_questions INT := 0;
    v_correct_count INT := 0;
    v_is_won BOOLEAN := false;
    v_q RECORD;
    v_chosen_option_id UUID;
    v_is_correct BOOLEAN;
    v_entry_status ledger_status := 'confirmed';
    v_unresolved_flags INT;

    -- Economy caps
    v_daily_cap INT := 1000;
    v_weekly_cap INT := 5000;
    v_today_caracas DATE := (NOW() AT TIME ZONE 'America/Caracas')::date;
    v_week_start_caracas TIMESTAMPTZ := date_trunc('week', NOW() AT TIME ZONE 'America/Caracas');
    v_today_earned INT := 0;
    v_week_earned INT := 0;
    v_rem_daily INT := 0;
    v_rem_weekly INT := 0;
    v_effective_cap INT := 0;
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    -- Rate limiting (Max 3 submits per 60s)
    PERFORM public.check_rate_limit(v_fan_id, 'submit_trivia_attempt', 3, 60);

    -- Lock attempt FOR UPDATE
    SELECT * INTO v_attempt FROM trivia_attempts WHERE id = p_attempt_id AND fan_id = v_fan_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Trivia attempt not found.';
    END IF;

    IF v_attempt.submitted_at IS NOT NULL THEN
        RETURN jsonb_build_object(
            'attempt_id', v_attempt.id,
            'score', v_attempt.score,
            'pearls_awarded', v_attempt.pearls_awarded,
            'suspicious', v_attempt.suspicious,
            'is_won', (v_attempt.pearls_awarded > 0),
            'already_submitted', true
        );
    END IF;

    SELECT * INTO v_trivia FROM trivias WHERE id = v_attempt.trivia_id;

    -- Timing check
    v_time_spent_seconds := EXTRACT(EPOCH FROM (NOW() - v_attempt.started_at));

    -- Check if fan has unresolved risk flags
    SELECT COUNT(*) INTO v_unresolved_flags
    FROM public.risk_flags
    WHERE fan_id = v_fan_id AND resolved = false;

    IF v_time_spent_seconds < 3.0 OR v_unresolved_flags > 0 THEN
        v_is_suspicious := true;
        v_entry_status := 'held';

        IF v_time_spent_seconds < 3.0 THEN
            INSERT INTO public.risk_flags (fan_id, reason, severity)
            VALUES (v_fan_id, 'Implausible trivia completion speed (' || round(v_time_spent_seconds, 2) || 's)', 'high');
        END IF;
    END IF;

    v_per_correct_pearls := COALESCE((v_trivia.reward_rules->>'per_correct_pearls')::int, 50);
    v_perfect_bonus := COALESCE((v_trivia.reward_rules->>'perfect_score_bonus')::int, 100);

    -- Server-side grading
    FOR v_q IN SELECT q.id, q.points FROM trivia_questions q WHERE q.trivia_id = v_trivia.id LOOP
        v_total_questions := v_total_questions + 1;
        v_chosen_option_id := (p_answers->>(v_q.id::text))::uuid;
        IF v_chosen_option_id IS NOT NULL THEN
            SELECT is_correct INTO v_is_correct 
            FROM trivia_options 
            WHERE id = v_chosen_option_id AND question_id = v_q.id;

            IF v_is_correct IS TRUE THEN
                v_correct_count := v_correct_count + 1;
                v_score := v_score + v_q.points;
                v_raw_pearls := v_raw_pearls + v_per_correct_pearls;
            END IF;
        END IF;
    END LOOP;

    -- Option A: Trivia is won ONLY if all questions are answered correctly
    v_is_won := (v_total_questions > 0 AND v_correct_count = v_total_questions);

    IF v_is_won THEN
        -- Add perfect score bonus if applicable
        v_raw_pearls := v_raw_pearls + v_perfect_bonus;

        -- Read economy caps
        SELECT daily_pearl_cap, weekly_pearl_cap 
        INTO v_daily_cap, v_weekly_cap
        FROM public.economy_settings
        ORDER BY created_at DESC LIMIT 1;

        v_daily_cap := COALESCE(v_daily_cap, 1000);
        v_weekly_cap := COALESCE(v_weekly_cap, 5000);

        -- Calculate current earnings in Caracas timezone
        SELECT COALESCE(SUM(amount), 0) INTO v_today_earned
        FROM ledger_entries
        WHERE fan_id = v_fan_id
          AND amount > 0
          AND status IN ('confirmed', 'held')
          AND (created_at AT TIME ZONE 'America/Caracas')::date = v_today_caracas;

        SELECT COALESCE(SUM(amount), 0) INTO v_week_earned
        FROM ledger_entries
        WHERE fan_id = v_fan_id
          AND amount > 0
          AND status IN ('confirmed', 'held')
          AND (created_at AT TIME ZONE 'America/Caracas') >= v_week_start_caracas;

        v_rem_daily := GREATEST(0, v_daily_cap - v_today_earned);
        v_rem_weekly := GREATEST(0, v_weekly_cap - v_week_earned);
        v_effective_cap := LEAST(v_rem_daily, v_rem_weekly);

        -- Cap pearls awarded
        v_final_pearls := LEAST(v_raw_pearls, v_effective_cap);

        -- Atomic Ledger + Wallet update
        IF v_final_pearls > 0 THEN
            INSERT INTO ledger_entries (
                fan_id, amount, type, status, source_type, source_id, note
            ) VALUES (
                v_fan_id, v_final_pearls, 'trivia_reward', v_entry_status, 'trivia_attempt', v_attempt.id::text,
                'Premio por ganar trivia: ' || v_trivia.title
            );

            IF v_entry_status = 'confirmed' THEN
                INSERT INTO wallets (fan_id, balance_cache)
                VALUES (v_fan_id, v_final_pearls)
                ON CONFLICT (fan_id) 
                DO UPDATE SET balance_cache = wallets.balance_cache + v_final_pearls, updated_at = NOW();
            END IF;
        END IF;

        -- Update streak bonus if confirmed
        IF v_entry_status = 'confirmed' THEN
            PERFORM public.calculate_and_apply_streak_bonus(v_fan_id);
        END IF;
    ELSE
        -- If not won, pearls awarded is 0 so the fan can retry until won
        v_final_pearls := 0;
    END IF;

    UPDATE trivia_attempts
    SET submitted_at = NOW(),
        answers = p_answers,
        score = v_score,
        pearls_awarded = v_final_pearls,
        suspicious = v_is_suspicious
    WHERE id = v_attempt.id;

    RETURN jsonb_build_object(
        'attempt_id', v_attempt.id,
        'score', v_score,
        'pearls_awarded', v_final_pearls,
        'raw_pearls', v_raw_pearls,
        'correct_count', v_correct_count,
        'total_questions', v_total_questions,
        'is_won', v_is_won,
        'suspicious', v_is_suspicious,
        'status', v_entry_status,
        'already_submitted', false
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.unregister_push_subscription(p_endpoint text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    UPDATE public.push_subscriptions
    SET disabled_at = NOW()
    WHERE user_id = v_user_id AND endpoint = p_endpoint;

    RETURN jsonb_build_object('success', true);
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_birth_date(p_birth_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_current_bdate DATE;
    v_last_change TIMESTAMPTZ;
BEGIN
    PERFORM public.assert_active_verified_fan();

    IF p_birth_date IS NULL THEN
        RAISE EXCEPTION 'La fecha de nacimiento es obligatoria.';
    END IF;

    SELECT birth_date, last_birth_date_change INTO v_current_bdate, v_last_change
    FROM public.profiles WHERE id = v_user_id;

    IF v_current_bdate IS NULL THEN
        -- Initial set
        UPDATE public.profiles
        SET birth_date = p_birth_date,
            last_birth_date_change = NOW(),
            updated_at = NOW()
        WHERE id = v_user_id;
    ELSE
        -- Check 12 month interval
        IF v_last_change IS NOT NULL AND v_last_change > NOW() - INTERVAL '12 months' THEN
            RAISE EXCEPTION 'Solo se permite una corrección de fecha de nacimiento cada 12 meses.';
        END IF;

        UPDATE public.profiles
        SET birth_date = p_birth_date,
            last_birth_date_change = NOW(),
            updated_at = NOW()
        WHERE id = v_user_id;
    END IF;

    RETURN jsonb_build_object('success', true, 'birth_date', p_birth_date);
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_birthday_settings(p_enabled boolean, p_title text, p_message text, p_image_url text, p_send_hour integer, p_grace_days integer, p_bonus_pearls integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
BEGIN
    PERFORM public.assert_admin();

    UPDATE public.birthday_settings
    SET enabled = p_enabled,
        title = TRIM(p_title),
        message = TRIM(p_message),
        image_url = p_image_url,
        send_hour = p_send_hour,
        grace_days = p_grace_days,
        bonus_pearls = p_bonus_pearls,
        updated_at = NOW()
    WHERE id = 1;

    RETURN jsonb_build_object('success', true);
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_display_name(p_display_name text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_clean_name TEXT := TRIM(p_display_name);
    v_lower_name TEXT := LOWER(v_clean_name);
    v_changes_count INT;
    v_old_name TEXT;
    v_reserved_match TEXT;
BEGIN
    PERFORM public.assert_active_verified_fan();

    -- Length validation
    IF v_clean_name IS NULL OR CHAR_LENGTH(v_clean_name) < 3 OR CHAR_LENGTH(v_clean_name) > 30 THEN
        RAISE EXCEPTION 'El nombre de usuario debe tener entre 3 y 30 caracteres.';
    END IF;

    -- Valid characters (alphanumeric, spaces, underscores, Spanish accents)
    IF v_clean_name !~ '^[a-zA-Z0-9_ áéíóúÁÉÍÓÚñÑ]+$' THEN
        RAISE EXCEPTION 'El nombre contiene caracteres no permitidos.';
    END IF;

    -- Check static reserved words
    IF v_lower_name LIKE '%admin%' OR v_lower_name LIKE '%guaiqueries%' OR v_lower_name LIKE '%oficial%' THEN
        RAISE EXCEPTION 'El nombre contiene términos reservados no permitidos.';
    END IF;

    -- Check player names reserved words
    SELECT full_name INTO v_reserved_match
    FROM public.players
    WHERE LOWER(v_clean_name) LIKE '%' || LOWER(full_name) || '%'
    LIMIT 1;

    IF v_reserved_match IS NOT NULL THEN
        RAISE EXCEPTION 'El nombre no puede ser idéntico al de un jugador del equipo.';
    END IF;

    -- Monthly rate limit check (max 3 per calendar month)
    SELECT COUNT(*) INTO v_changes_count
    FROM public.display_name_change_logs
    WHERE user_id = v_user_id
      AND DATE_TRUNC('month', changed_at) = DATE_TRUNC('month', NOW());

    IF v_changes_count >= 3 THEN
        RAISE EXCEPTION 'Has alcanzado el límite máximo de 3 cambios de nombre por mes.';
    END IF;

    SELECT display_name INTO v_old_name FROM public.profiles WHERE id = v_user_id;

    UPDATE public.profiles
    SET display_name = v_clean_name,
        updated_at = NOW()
    WHERE id = v_user_id;

    INSERT INTO public.display_name_change_logs (user_id, old_name, new_name)
    VALUES (v_user_id, v_old_name, v_clean_name);

    RETURN jsonb_build_object('success', true, 'display_name', v_clean_name);
END;
$function$;

CREATE OR REPLACE FUNCTION public.user_has_verified_mfa(p_uid uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM auth.mfa_factors
    WHERE user_id = p_uid AND status = 'verified';
    
    RETURN COALESCE(v_count, 0) > 0;
END;
$function$;

CREATE OR REPLACE FUNCTION public.validate_crockford_base32_checksum(p_code text)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_clean TEXT := UPPER(REGEXP_REPLACE(COALESCE(p_code, ''), '[-\s]', '', 'g'));
    v_alphabet TEXT := '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
    v_sum INT := 0;
    v_i INT;
    v_pos INT;
    v_expected_check CHAR;
    v_actual_check CHAR;
BEGIN
    IF length(v_clean) != 12 THEN
        RETURN FALSE;
    END IF;

    FOR v_i IN 1..11 LOOP
        v_pos := position(substr(v_clean, v_i, 1) in v_alphabet);
        IF v_pos = 0 THEN
            RETURN FALSE;
        END IF;
        v_sum := v_sum + (v_pos - 1) * v_i;
    END LOOP;

    v_expected_check := substr(v_alphabet, (v_sum % 32) + 1, 1);
    v_actual_check := substr(v_clean, 12, 1);

    RETURN v_expected_check = v_actual_check;
END;
$function$;

CREATE OR REPLACE FUNCTION public.validate_login_modal_urls(p_image_url text, p_cta_url text)
 RETURNS void
 LANGUAGE plpgsql
 IMMUTABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_clean_img TEXT := LOWER(TRIM(COALESCE(p_image_url, '')));
    v_clean_cta TEXT := LOWER(TRIM(COALESCE(p_cta_url, '')));
BEGIN
    -- Check image URL
    IF v_clean_img != '' THEN
        IF v_clean_img LIKE 'javascript:%' OR v_clean_img LIKE 'data:%' OR v_clean_img LIKE 'vbscript:%' THEN
            RAISE EXCEPTION 'Esquema de URL no permitido en la imagen.' USING ERRCODE = '22023';
        END IF;

        IF NOT (v_clean_img LIKE 'https://%' OR v_clean_img LIKE '/%') THEN
            RAISE EXCEPTION 'La URL de la imagen debe ser una ruta segura https:// o relativa /.' USING ERRCODE = '22023';
        END IF;
    END IF;

    -- Check CTA URL
    IF v_clean_cta = '' THEN
        RAISE EXCEPTION 'La URL del botón CTA es obligatoria.' USING ERRCODE = '22023';
    END IF;

    IF v_clean_cta LIKE 'javascript:%' OR v_clean_cta LIKE 'data:%' OR v_clean_cta LIKE 'vbscript:%' THEN
        RAISE EXCEPTION 'Esquema de URL no permitido en el botón CTA.' USING ERRCODE = '22023';
    END IF;

    IF NOT (v_clean_cta LIKE 'https://%' OR v_clean_cta LIKE '/%') THEN
        RAISE EXCEPTION 'La URL del botón CTA debe empezar por https:// o /.' USING ERRCODE = '22023';
    END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.verify_redemption_code(p_code text, p_device text DEFAULT 'Scanner Terminal'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_staff_id UUID := auth.uid();
    v_invalid_count INT;
    v_clean_code TEXT;
    v_hash TEXT;
    v_redemption RECORD;
    v_deliv_name TEXT;
    v_result TEXT;
    v_scan_enum scan_result;
BEGIN
    PERFORM assert_staff();

    -- 2.1 Anti Brute-Force Rate Limiter (Más de 10 códigos inválidos en 5 min bloquea escáner)
    SELECT COUNT(*) INTO v_invalid_count
    FROM public.scan_events
    WHERE staff_id = v_staff_id
      AND result = 'invalid'
      AND created_at > (NOW() - INTERVAL '5 minutes');

    IF v_invalid_count >= 10 THEN
        INSERT INTO public.audit_log (actor_id, action, entity, entity_id, before, after)
        VALUES (
            v_staff_id,
            'scanner_locked',
            'staff_members',
            v_staff_id::text,
            NULL,
            jsonb_build_object('reason', 'brute_force_prevention', 'invalid_attempts_5m', v_invalid_count)
        );

        RAISE EXCEPTION 'SCANNER_LOCKED: Escáner bloqueado temporalmente por acumulación de intentos fallidos. Intente en 15 minutos.' USING ERRCODE = '42501';
    END IF;

    -- 2.2 Limpiar formato y validar Crockford Base32 + checksum
    v_clean_code := UPPER(REGEXP_REPLACE(COALESCE(p_code, ''), '[-\s]', '', 'g'));

    IF length(v_clean_code) != 12 OR NOT validate_crockford_base32_checksum(v_clean_code) THEN
        INSERT INTO public.scan_events (staff_id, code_hash, result, device)
        VALUES (v_staff_id, 'INVALID_FORMAT', 'invalid', p_device);

        RETURN jsonb_build_object(
            'result', 'INVALID',
            'message', 'Código con formato o dígito verificador inválido.'
        );
    END IF;

    -- 2.3 Calcular SHA-256 hash y buscar canje
    v_hash := compute_redemption_code_hash(v_clean_code);

    SELECT 
        r.id,
        r.status,
        r.variant,
        r.cost_pearls,
        r.created_at,
        r.expires_at,
        r.delivered_at,
        r.delivered_by,
        p.display_name AS fan_display_name,
        p.avatar_url AS fan_avatar_url,
        pr.name AS product_name,
        pr.category AS product_category
    INTO v_redemption
    FROM public.redemptions r
    JOIN public.profiles p ON p.id = r.fan_id
    JOIN public.products pr ON pr.id = r.product_id
    WHERE r.code_hash = v_hash;

    IF NOT FOUND THEN
        INSERT INTO public.scan_events (staff_id, code_hash, result, device)
        VALUES (v_staff_id, v_hash, 'invalid', p_device);

        RETURN jsonb_build_object(
            'result', 'INVALID',
            'message', 'Código de canje no encontrado.'
        );
    END IF;

    -- 2.4 Determinar resultado tipificado
    IF v_redemption.status = 'approved' THEN
        v_result := 'OK_APPROVED';
        v_scan_enum := 'success';
    ELSIF v_redemption.status = 'scheduled' THEN
        v_result := 'OK_SCHEDULED';
        v_scan_enum := 'success';
    ELSIF v_redemption.status IN ('delivered', 'completed') THEN
        v_result := 'ALREADY_DELIVERED';
        v_scan_enum := 'already_delivered';
    ELSIF v_redemption.status = 'expired' OR (v_redemption.expires_at IS NOT NULL AND NOW() > v_redemption.expires_at) THEN
        v_result := 'EXPIRED';
        v_scan_enum := 'expired';
    ELSIF v_redemption.status = 'pending' THEN
        v_result := 'PENDING';
        v_scan_enum := 'invalid';
    ELSIF v_redemption.status = 'cancelled' THEN
        v_result := 'CANCELLED';
        v_scan_enum := 'invalid';
    ELSIF v_redemption.status = 'rejected' THEN
        v_result := 'REJECTED';
        v_scan_enum := 'invalid';
    ELSE
        v_result := 'INVALID';
        v_scan_enum := 'invalid';
    END IF;

    -- Obtener nombre de quien entregó si ya fue entregado
    IF v_redemption.delivered_by IS NOT NULL THEN
        SELECT display_name INTO v_deliv_name
        FROM public.profiles
        WHERE id = v_redemption.delivered_by;
    END IF;

    -- Registrar evento de escaneo en scan_events
    INSERT INTO public.scan_events (staff_id, code_hash, result, device)
    VALUES (v_staff_id, v_hash, v_scan_enum, p_device);

    -- Retornar payload SEGURO (Sin correo, fecha nacimiento ni segmentación)
    RETURN jsonb_build_object(
        'result', v_result,
        'redemption_id', v_redemption.id,
        'status', v_redemption.status,
        'display_name', v_redemption.fan_display_name,
        'avatar_url', v_redemption.fan_avatar_url,
        'product_title', v_redemption.product_name,
        'variant_title', v_redemption.variant,
        'is_experience', (v_redemption.product_category = 'experience'),
        'created_at', v_redemption.created_at,
        'expires_at', v_redemption.expires_at,
        'delivered_at', v_redemption.delivered_at,
        'delivered_by_name', v_deliv_name
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.wallet_ledger(p_type text DEFAULT NULL::text, p_cursor timestamp with time zone DEFAULT NULL::timestamp with time zone, p_limit integer DEFAULT 20)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_fan_id UUID := auth.uid();
    v_limit INT := LEAST(COALESCE(p_limit, 20), 50);
    v_entries JSONB;
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT COALESCE(jsonb_agg(entry_data), '[]'::jsonb) INTO v_entries
    FROM (
        SELECT jsonb_build_object(
            'id', le.id,
            'amount', le.amount,
            'type', le.type,
            'status', le.status,
            'note', le.note,
            'source_type', le.source_type,
            'source_id', le.source_id,
            'created_at', le.created_at,
            'description', CASE
                WHEN le.type = 'trivia_reward' THEN 'Premio por trivia respondida'
                WHEN le.type = 'redemption' THEN 'Canje de premio en la tienda'
                WHEN le.type = 'refund' THEN 'Reembolso de canje cancelado/rechazado'
                WHEN le.type = 'bonus' THEN 'Bono de bienvenida / evento'
                WHEN le.type = 'streak_bonus' THEN 'Bono por racha de actividad'
                WHEN le.type = 'admin_adjustment' THEN 'Ajuste administrativo oficial'
                ELSE COALESCE(le.note, 'Movimiento de perlitas')
            END
        ) AS entry_data
        FROM ledger_entries le
        WHERE le.fan_id = v_fan_id
          AND (p_type IS NULL OR p_type = 'all' OR le.type::text = p_type)
          AND (p_cursor IS NULL OR le.created_at < p_cursor)
        ORDER BY le.created_at DESC
        LIMIT v_limit
    ) sub;

    RETURN v_entries;
END;
$function$;

CREATE OR REPLACE FUNCTION public.wallet_summary()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_fan_id UUID := auth.uid();
    v_balance INT := 0;
    v_earned_month INT := 0;
    v_spent_month INT := 0;
    v_held_pearls INT := 0;
    v_start_of_month TIMESTAMPTZ := date_trunc('month', NOW());
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    -- Saldo en billetera
    SELECT balance_cache INTO v_balance FROM wallets WHERE fan_id = v_fan_id;
    v_balance := COALESCE(v_balance, 0);

    -- Ganadas del mes (entradas positivas confirmadas)
    SELECT COALESCE(SUM(amount), 0) INTO v_earned_month
    FROM ledger_entries
    WHERE fan_id = v_fan_id
      AND amount > 0
      AND status = 'confirmed'
      AND created_at >= v_start_of_month;

    -- Gastadas del mes (entradas negativas confirmadas en valor absoluto)
    SELECT COALESCE(ABS(SUM(amount)), 0) INTO v_spent_month
    FROM ledger_entries
    WHERE fan_id = v_fan_id
      AND amount < 0
      AND status = 'confirmed'
      AND created_at >= v_start_of_month;

    -- Perlitas retenidas pendientes de resolución
    SELECT COALESCE(SUM(le.amount), 0) INTO v_held_pearls
    FROM ledger_entries le
    WHERE le.fan_id = v_fan_id
      AND le.status = 'held'
      AND NOT EXISTS (
          SELECT 1 FROM public.ledger_hold_resolutions r WHERE r.ledger_id = le.id
      );

    RETURN jsonb_build_object(
        'balance', v_balance,
        'earned_month', v_earned_month,
        'spent_month', v_spent_month,
        'held_pearls', v_held_pearls
    );
END;
$function$;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

CREATE TRIGGER trg_prevent_ledger_mutation
    BEFORE DELETE OR UPDATE ON public.ledger_entries
    FOR EACH ROW EXECUTE FUNCTION prevent_ledger_mutation();

CREATE TRIGGER trg_prevent_audit_log_mutation
    BEFORE DELETE OR UPDATE ON public.audit_log
    FOR EACH ROW EXECUTE FUNCTION prevent_audit_log_mutation();

CREATE TRIGGER trg_check_max_5_published_login_modal_slides
    BEFORE INSERT OR UPDATE ON public.login_modal_slides
    FOR EACH ROW EXECUTE FUNCTION check_max_5_published_login_modal_slides();

CREATE CONSTRAINT TRIGGER trg_assert_min_admins
    AFTER DELETE OR UPDATE ON public.staff_members
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION assert_min_admins();

-- ============================================================================
-- FUNCTION PERMISSIONS (REVOKE PUBLIC, GRANT EXPLICIT ROLES)
-- ============================================================================

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.accept_terms() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.adjust_stock(p_product_id uuid, p_delta integer, p_reason text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_adjust_pearls(p_fan_id uuid, p_amount integer, p_reason text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_archive_trivia(p_trivia_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_delete_game(p_game_id uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_delete_login_modal_slide(p_slide_id uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_delete_player(p_player_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_duplicate_trivia(p_trivia_id uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_get_fan(p_fan_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_get_trivia_with_options(p_trivia_id uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_list_fans(p_municipality text, p_age_min integer, p_age_max integer, p_favorite_player_id uuid, p_inactive_days integer, p_status user_status, p_search text, p_limit integer, p_cursor uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_publish_policy(p_slug text, p_version text, p_content text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_publish_trivia(p_trivia_id uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_reactivate_fan(p_fan_id uuid, p_reason text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_release_held_pearls(p_ledger_id uuid, p_note text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_reorder_login_modal_slides(p_slide_ids uuid[]) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_resolve_redemption_issue(p_redemption_id uuid, p_action text, p_note text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_resolve_risk_flag(p_flag_id uuid, p_note text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_revoke_held_pearls(p_ledger_id uuid, p_note text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_risk_queue(p_resolved boolean) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_suspend_fan(p_fan_id uuid, p_reason text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_toggle_staff_active(p_target_id uuid, p_active boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_update_ads_settings(p_settings jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_update_birth_date(p_user_id uuid, p_birth_date date, p_reason text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_update_economy_settings(p_settings jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_update_staff_role(p_target_id uuid, p_new_role staff_role) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_upsert_game(p_game jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_upsert_login_modal_slide(p_id uuid, p_position integer, p_image_url text, p_title text, p_subtitle text, p_cta_label text, p_cta_url text, p_status text, p_starts_at timestamp with time zone, p_ends_at timestamp with time zone) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_upsert_player(p_player jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_upsert_product(p_product jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_upsert_segment(p_segment jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_upsert_trivia(p_trivia jsonb, p_questions jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.analytics_active_users(p_start_date timestamp with time zone, p_end_date timestamp with time zone, p_granularity text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.analytics_ads(p_from timestamp with time zone, p_to timestamp with time zone) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.analytics_demographics() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.analytics_economy() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.analytics_engagement_hours(p_start_date timestamp with time zone, p_end_date timestamp with time zone) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.analytics_funnel(p_start_date timestamp with time zone, p_end_date timestamp with time zone) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.analytics_overview(p_start_date timestamp with time zone, p_end_date timestamp with time zone) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.analytics_products(p_start_date timestamp with time zone, p_end_date timestamp with time zone) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.analytics_top_fans(p_limit integer, p_start_date timestamp with time zone, p_end_date timestamp with time zone) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.analytics_trivias(p_start_date timestamp with time zone, p_end_date timestamp with time zone) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.approve_redemption(p_redemption_id uuid, p_note text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.assert_active_verified_fan(p_user_id uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.assert_active_verified_fan() TO service_role;
GRANT EXECUTE ON FUNCTION public.assert_admin() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.assert_min_admins() TO service_role;
GRANT EXECUTE ON FUNCTION public.assert_staff() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.audit_search(p_actor_id uuid, p_action text, p_entity text, p_from timestamp with time zone, p_to timestamp with time zone, p_limit integer, p_cursor uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.calculate_and_apply_streak_bonus(p_fan_id uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.cancel_ad_session(p_session_id uuid, p_reason text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.cancel_redemption(p_redemption_id uuid, p_reason text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.check_in_redemption(p_redemption_id uuid, p_idempotency_key text, p_note text) TO service_role;
GRANT EXECUTE ON FUNCTION public.check_max_5_published_login_modal_slides() TO service_role;
GRANT EXECUTE ON FUNCTION public.check_rate_limit(p_user_id uuid, p_action text, p_max integer, p_window_seconds integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.claim_birthday_bonus() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.complete_ad_session(p_session_id uuid, p_idempotency_key text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.compute_redemption_code_hash(p_code_or_hash text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.compute_risk(p_fan_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.confirm_test_user_email(p_email text) TO service_role;
GRANT EXECUTE ON FUNCTION public.create_notification(p_user_id uuid, p_type text, p_title text, p_body text, p_data jsonb, p_dedup_key text) TO service_role;
GRANT EXECUTE ON FUNCTION public.create_security_notification(p_user_id uuid, p_title text, p_body text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.cron_cleanup_old_notifications() TO service_role;
GRANT EXECUTE ON FUNCTION public.cron_notify_expiring_redemptions() TO service_role;
GRANT EXECUTE ON FUNCTION public.cron_notify_match_day() TO service_role;
GRANT EXECUTE ON FUNCTION public.cron_notify_new_trivias() TO service_role;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.deliver_redemption(p_code text, p_note text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.deliver_redemption(p_redemption_id uuid, p_idempotency_key text, p_note text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.enqueue_birthday_notifications(p_now timestamp with time zone) TO service_role;
GRANT EXECUTE ON FUNCTION public.generate_redemption_code(p_redemption_id uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_active_legal_versions() TO service_role;
GRANT EXECUTE ON FUNCTION public.get_ads_progress() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_attempt_questions(p_attempt_id uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_birthday_card() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_leaderboard(p_period text) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.get_login_modal() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_redemption_qr(p_redemption_id uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_streak_info(p_fan_id uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.health_check() TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.helper_generate_code_with_key(p_redemption_id uuid, p_key_id text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.home_summary() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.import_ad_report(p_day date, p_impressions integer, p_notes text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_admin(user_id uuid) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.is_admin_check() TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.is_staff_or_admin(user_id uuid) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.mark_all_notifications_read() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.mark_notification_read(p_notification_id uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.parse_instagram_shortcode(p_url text) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.prevent_audit_log_mutation() TO service_role;
GRANT EXECUTE ON FUNCTION public.prevent_ledger_mutation() TO service_role;
GRANT EXECUTE ON FUNCTION public.purge_auth_identities(p_user_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.purge_fraud_telemetry() TO service_role;
GRANT EXECUTE ON FUNCTION public.reconcile_wallets() TO service_role;
GRANT EXECUTE ON FUNCTION public.redeem_product(p_product_id uuid, p_variant text, p_idempotency_key text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.refresh_analytics_materialized_views() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.register_email_send_attempt() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.register_push_subscription(p_endpoint text, p_p256dh text, p_auth text, p_user_agent text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.reject_redemption(p_redemption_id uuid, p_reason text) TO service_role;
GRANT EXECUTE ON FUNCTION public.report_redemption_issue(p_redemption_id uuid, p_reason text) TO service_role;
GRANT EXECUTE ON FUNCTION public.report_redemption_issue(p_redemption_id uuid, p_reason text, p_note text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rls_auto_enable() TO service_role;
GRANT EXECUTE ON FUNCTION public.run_daily_wallet_reconciliation() TO service_role;
GRANT EXECUTE ON FUNCTION public.save_mfa_recovery_code_hashes(p_hashes text[]) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.seed_analytics_performance_data(p_num_fans integer, p_num_ledger integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.segment_count(p_segment_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.segment_members(p_segment_id uuid, p_limit integer, p_cursor uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.send_test_birthday_notification() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.set_birth_date(p_birth_date date) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.staff_redemption_queue(p_status text, p_search text, p_cursor timestamp with time zone, p_limit integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.staff_search_fans(p_query text, p_limit integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.staff_upsert_product(p_product jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.staff_upsert_trivia(p_trivia jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.staff_upsert_trivia(p_trivia jsonb, p_questions jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.start_ad_session(p_idempotency_key text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.start_trivia_attempt(p_trivia_id uuid, p_idempotency_key text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.submit_trivia_attempt(p_attempt_id uuid, p_answers jsonb, p_idempotency_key text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.unregister_push_subscription(p_endpoint text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.update_birth_date(p_birth_date date) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.update_birthday_settings(p_enabled boolean, p_title text, p_message text, p_image_url text, p_send_hour integer, p_grace_days integer, p_bonus_pearls integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.update_display_name(p_display_name text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.user_has_verified_mfa(p_uid uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.validate_crockford_base32_checksum(p_code text) TO service_role;
GRANT EXECUTE ON FUNCTION public.validate_login_modal_urls(p_image_url text, p_cta_url text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.verify_redemption_code(p_code text, p_device text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.wallet_ledger(p_type text, p_cursor timestamp with time zone, p_limit integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.wallet_summary() TO authenticated, service_role;

