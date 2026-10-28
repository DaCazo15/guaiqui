-- ============================================================================
-- Migration: 20261028000006_harden_rpc_team_authorization.sql
-- Description: Paso 0 Phase 1 Corrections:
--              Hardens all staff and admin RPC functions to enforce multi-tenant
--              team-level authorization using the resource's team_id (not client params).
--              Enforces platform admin requirements for global configurations.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Redemptions & Scanner Operations
-- ----------------------------------------------------------------------------

-- 1.1 approve_redemption
CREATE OR REPLACE FUNCTION public.approve_redemption(
    p_redemption_id UUID,
    p_note TEXT DEFAULT 'Canje aprobado por staff'::TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_staff_id UUID := auth.uid();
    v_redemption public.redemptions%ROWTYPE;
BEGIN
    SELECT * INTO v_redemption FROM public.redemptions WHERE id = p_redemption_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Redemption not found.';
    END IF;

    PERFORM public.assert_team_staff(v_redemption.team_id);

    IF v_redemption.status != 'pending' THEN
        RAISE EXCEPTION 'Solo los canjes pendientes pueden ser aprobados. Estado actual: %', v_redemption.status;
    END IF;

    UPDATE public.redemptions
    SET status = 'approved',
        approved_at = NOW(),
        approved_by = v_staff_id
    WHERE id = p_redemption_id;

    INSERT INTO public.redemption_history (redemption_id, previous_status, new_status, changed_by, note)
    VALUES (p_redemption_id, 'pending', 'approved', v_staff_id, p_note);

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_staff_id, 'approve_redemption', 'redemptions', p_redemption_id::text,
        jsonb_build_object('approved_at', NOW(), 'note', p_note, 'team_id', v_redemption.team_id)
    );

    RETURN jsonb_build_object(
        'id', p_redemption_id,
        'status', 'approved',
        'approved_at', NOW()
    );
END;
$function$;

-- 1.2 verify_redemption_code
CREATE OR REPLACE FUNCTION public.verify_redemption_code(
    p_code TEXT,
    p_device TEXT DEFAULT 'Scanner Terminal'::TEXT
)
RETURNS JSONB
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
    v_scan_enum public.scan_result;
BEGIN
    PERFORM public.assert_staff();

    -- Anti Brute-Force Rate Limiter
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

    v_clean_code := UPPER(REGEXP_REPLACE(COALESCE(p_code, ''), '[-\s]', '', 'g'));

    IF length(v_clean_code) != 12 OR NOT public.validate_crockford_base32_checksum(v_clean_code) THEN
        INSERT INTO public.scan_events (staff_id, code_hash, result, device, team_id)
        VALUES (v_staff_id, 'INVALID_FORMAT', 'invalid', p_device, public.current_staff_team_id());

        RETURN jsonb_build_object(
            'result', 'INVALID',
            'message', 'Código con formato o dígito verificador inválido.'
        );
    END IF;

    v_hash := public.compute_redemption_code_hash(v_clean_code);

    SELECT 
        r.id,
        r.team_id,
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
        INSERT INTO public.scan_events (staff_id, code_hash, result, device, team_id)
        VALUES (v_staff_id, v_hash, 'invalid', p_device, public.current_staff_team_id());

        RETURN jsonb_build_object(
            'result', 'INVALID',
            'message', 'Código no encontrado en el sistema.'
        );
    END IF;

    -- Validar que el personal pertenece al equipo del canje
    IF NOT public.is_team_staff(v_staff_id, v_redemption.team_id) THEN
        INSERT INTO public.scan_events (staff_id, code_hash, result, device, team_id)
        VALUES (v_staff_id, v_hash, 'invalid', p_device, v_redemption.team_id);

        RETURN jsonb_build_object(
            'result', 'INVALID',
            'message', 'Código de canje no pertenece a su equipo.'
        );
    END IF;

    IF v_redemption.status = 'delivered' OR v_redemption.status = 'completed' THEN
        v_result := 'ALREADY_DELIVERED';
        v_scan_enum := 'already_delivered';
        SELECT display_name INTO v_deliv_name FROM public.profiles WHERE id = v_redemption.delivered_by;
    ELSIF v_redemption.status = 'expired' OR (v_redemption.expires_at IS NOT NULL AND v_redemption.expires_at < NOW()) THEN
        v_result := 'EXPIRED';
        v_scan_enum := 'expired';
    ELSIF v_redemption.status = 'cancelled' THEN
        v_result := 'CANCELLED';
        v_scan_enum := 'invalid';
    ELSIF v_redemption.status = 'rejected' THEN
        v_result := 'REJECTED';
        v_scan_enum := 'invalid';
    ELSIF v_redemption.status = 'approved' OR v_redemption.status = 'scheduled' THEN
        v_result := 'VALID';
        v_scan_enum := 'valid';
    ELSIF v_redemption.status = 'pending' THEN
        v_result := 'PENDING_APPROVAL';
        v_scan_enum := 'invalid';
    ELSE
        v_result := 'INVALID';
        v_scan_enum := 'invalid';
    END IF;

    INSERT INTO public.scan_events (staff_id, code_hash, result, device, team_id)
    VALUES (v_staff_id, v_hash, v_scan_enum, p_device, v_redemption.team_id);

    RETURN jsonb_build_object(
        'result', v_result,
        'redemption_id', v_redemption.id,
        'status', v_redemption.status,
        'product_name', v_redemption.product_name,
        'product_category', v_redemption.product_category,
        'variant', v_redemption.variant,
        'cost_pearls', v_redemption.cost_pearls,
        'fan_display_name', v_redemption.fan_display_name,
        'fan_avatar_url', v_redemption.fan_avatar_url,
        'expires_at', v_redemption.expires_at,
        'delivered_at', v_redemption.delivered_at,
        'delivered_by_name', COALESCE(v_deliv_name, 'Personal de Taquilla')
    );
END;
$function$;

-- 1.3 check_in_redemption
CREATE OR REPLACE FUNCTION public.check_in_redemption(
    p_redemption_id UUID,
    p_idempotency_key TEXT,
    p_note TEXT DEFAULT NULL::TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_staff_id UUID := auth.uid();
    v_redemption public.redemptions%ROWTYPE;
    v_deliv_name TEXT;
BEGIN
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

    PERFORM public.assert_team_staff(v_redemption.team_id);

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
    VALUES (v_redemption.id, v_redemption.status, 'completed', v_staff_id, COALESCE(p_note, 'Check-in verificado por staff'));

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_staff_id, 'check_in_redemption', 'redemptions', v_redemption.id::text,
        jsonb_build_object('status', 'completed', 'delivered_at', NOW(), 'team_id', v_redemption.team_id)
    );

    RETURN jsonb_build_object(
        'result', 'COMPLETED',
        'status', 'completed',
        'redemption_id', v_redemption.id,
        'delivered_at', NOW()
    );
END;
$function$;

-- 1.4 deliver_redemption
CREATE OR REPLACE FUNCTION public.deliver_redemption(
    p_code TEXT,
    p_note TEXT DEFAULT NULL::TEXT
)
RETURNS JSONB
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
    v_clean_code := UPPER(REGEXP_REPLACE(COALESCE(p_code, ''), '[-\s]', '', 'g'));
    v_hash := public.compute_redemption_code_hash(v_clean_code);

    SELECT * INTO v_redemption FROM public.redemptions WHERE code_hash = v_hash FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'REDEMPTION_NOT_FOUND: Código no encontrado.';
    END IF;

    PERFORM public.assert_team_staff(v_redemption.team_id);

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
        jsonb_build_object('delivered_at', NOW(), 'note', p_note, 'team_id', v_redemption.team_id)
    );

    RETURN jsonb_build_object(
        'status', 'delivered',
        'redemption_id', v_redemption.id,
        'delivered_at', NOW()
    );
END;
$function$;

-- 1.5 reject_redemption
CREATE OR REPLACE FUNCTION public.reject_redemption(
    p_redemption_id UUID,
    p_reason TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_staff_id UUID := auth.uid();
    v_redemption public.redemptions%ROWTYPE;
BEGIN
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

    PERFORM public.assert_team_staff(v_redemption.team_id);

    IF v_redemption.status = 'rejected' THEN
        RAISE EXCEPTION 'El canje ya ha sido rechazado previamente.';
    END IF;

    IF v_redemption.status IN ('delivered', 'completed') THEN
        RAISE EXCEPTION 'No se puede rechazar un canje que ya fue entregado.';
    END IF;

    UPDATE public.redemptions
    SET status = 'rejected'
    WHERE id = p_redemption_id;

    UPDATE public.products
    SET stock = stock + 1
    WHERE id = v_redemption.product_id;

    UPDATE public.wallets
    SET balance_cache = balance_cache + v_redemption.cost_pearls
    WHERE fan_id = v_redemption.fan_id;

    INSERT INTO public.ledger_entries (fan_id, amount, type, description)
    VALUES (
        v_redemption.fan_id,
        v_redemption.cost_pearls,
        'redemption_refund',
        'Reembolso por canje rechazado: ' || p_reason
    );

    INSERT INTO public.redemption_history (redemption_id, previous_status, new_status, changed_by, note)
    VALUES (p_redemption_id, v_redemption.status, 'rejected', v_staff_id, p_reason);

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_staff_id, 'reject_redemption', 'redemptions', p_redemption_id::text,
        jsonb_build_object('status', 'rejected', 'reason', p_reason, 'team_id', v_redemption.team_id)
    );

    RETURN jsonb_build_object(
        'id', p_redemption_id,
        'status', 'rejected',
        'refunded_pearls', v_redemption.cost_pearls
    );
END;
$function$;

-- 1.6 report_redemption_issue
CREATE OR REPLACE FUNCTION public.report_redemption_issue(
    p_redemption_id UUID,
    p_reason TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_staff_id UUID := auth.uid();
    v_redemption public.redemptions%ROWTYPE;
BEGIN
    IF p_reason IS NULL OR trim(p_reason) = '' THEN
        RAISE EXCEPTION 'A reason is required to report an issue.';
    END IF;

    SELECT * INTO v_redemption FROM public.redemptions WHERE id = p_redemption_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Redemption not found.';
    END IF;

    PERFORM public.assert_team_staff(v_redemption.team_id);

    IF v_redemption.status NOT IN ('delivered', 'completed', 'scheduled') THEN
        RAISE EXCEPTION 'Issues can only be reported on active, scheduled, or delivered redemptions.';
    END IF;

    UPDATE public.redemptions
    SET status = 'reported_issue'
    WHERE id = p_redemption_id;

    INSERT INTO public.redemption_history (redemption_id, previous_status, new_status, changed_by, note)
    VALUES (p_redemption_id, v_redemption.status, 'reported_issue', v_staff_id, p_reason);

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_staff_id, 'report_redemption_issue', 'redemptions', p_redemption_id::text,
        jsonb_build_object('previous_status', v_redemption.status, 'reason', p_reason, 'team_id', v_redemption.team_id)
    );

    RETURN jsonb_build_object(
        'id', p_redemption_id,
        'status', 'reported_issue',
        'reason', p_reason
    );
END;
$function$;

-- 1.7 admin_resolve_redemption_issue
CREATE OR REPLACE FUNCTION public.admin_resolve_redemption_issue(
    p_redemption_id UUID,
    p_action TEXT,
    p_note TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_redemption public.redemptions%ROWTYPE;
    v_old_status public.redemption_status;
    v_new_status public.redemption_status;
    v_old_balance INT := 0;
    v_new_balance INT := 0;
BEGIN
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

    PERFORM public.assert_team_admin(v_redemption.team_id);

    IF v_redemption.status != 'reported_issue' THEN
        RAISE EXCEPTION 'Solo los canjes con incidencia reportada pueden resolverse.';
    END IF;

    v_old_status := v_redemption.status;

    IF p_action = 'close' THEN
        v_new_status := 'completed';
        UPDATE public.redemptions SET status = v_new_status WHERE id = p_redemption_id;

    ELSIF p_action = 'refund' THEN
        v_new_status := 'cancelled';
        UPDATE public.redemptions SET status = v_new_status WHERE id = p_redemption_id;

        SELECT balance_cache INTO v_old_balance FROM public.wallets WHERE fan_id = v_redemption.fan_id FOR UPDATE;
        v_new_balance := COALESCE(v_old_balance, 0) + v_redemption.cost_pearls;

        UPDATE public.wallets SET balance_cache = v_new_balance WHERE fan_id = v_redemption.fan_id;

        INSERT INTO public.ledger_entries (fan_id, amount, type, description)
        VALUES (
            v_redemption.fan_id,
            v_redemption.cost_pearls,
            'redemption_refund',
            'Reembolso administrativo por resolución de incidencia: ' || p_note
        );

        UPDATE public.products SET stock = stock + 1 WHERE id = v_redemption.product_id;

    ELSIF p_action = 'reissue' THEN
        v_new_status := 'approved';
        UPDATE public.redemptions
        SET status = v_new_status,
            expires_at = NOW() + INTERVAL '14 days'
        WHERE id = p_redemption_id;
    END IF;

    INSERT INTO public.redemption_history (redemption_id, previous_status, new_status, changed_by, note)
    VALUES (p_redemption_id, v_old_status, v_new_status, v_admin_id, p_action || ': ' || p_note);

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        v_admin_id, 'resolve_redemption_issue', 'redemptions', p_redemption_id::text,
        jsonb_build_object('status', v_old_status),
        jsonb_build_object('status', v_new_status, 'action', p_action, 'note', p_note, 'team_id', v_redemption.team_id)
    );

    RETURN jsonb_build_object(
        'id', p_redemption_id,
        'status', v_new_status,
        'action', p_action,
        'resolved_by', v_admin_id
    );
END;
$function$;

-- 1.8 staff_redemption_queue
CREATE OR REPLACE FUNCTION public.staff_redemption_queue(
    p_status TEXT DEFAULT NULL::TEXT,
    p_search TEXT DEFAULT NULL::TEXT,
    p_cursor TIMESTAMPTZ DEFAULT NULL::TIMESTAMPTZ,
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE(
    id UUID,
    status public.redemption_status,
    variant TEXT,
    cost_pearls INTEGER,
    created_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    fan_id UUID,
    fan_display_name TEXT,
    fan_avatar_url TEXT,
    product_id UUID,
    product_name TEXT,
    product_category public.product_category
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_eff_limit INT := LEAST(GREATEST(p_limit, 1), 50);
    v_caller_id UUID := auth.uid();
    v_is_platform_admin BOOLEAN := public.is_platform_admin(v_caller_id);
    v_team_id UUID := public.current_staff_team_id();
BEGIN
    PERFORM public.assert_staff();

    IF NOT v_is_platform_admin AND v_team_id IS NULL THEN
        RAISE EXCEPTION 'Club staff must belong to an active team.' USING ERRCODE = '42501';
    END IF;

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
    WHERE (v_is_platform_admin OR r.team_id = v_team_id)
      AND (p_status IS NULL OR p_status = '' OR r.status::text = p_status)
      AND (p_search IS NULL OR p_search = '' OR (p.display_name ILIKE '%' || p_search || '%' OR pr.name ILIKE '%' || p_search || '%'))
      AND (p_cursor IS NULL OR r.created_at < p_cursor)
    ORDER BY r.created_at DESC
    LIMIT v_eff_limit;
END;
$function$;

-- 1.9 staff_search_fans
CREATE OR REPLACE FUNCTION public.staff_search_fans(
    p_query TEXT,
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE(
    id UUID,
    display_name TEXT,
    avatar_url TEXT,
    status TEXT,
    pearl_balance INTEGER,
    last_5_redemptions JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_staff_id UUID := auth.uid();
    v_eff_limit INT := LEAST(GREATEST(p_limit, 1), 20);
    v_clean_query TEXT := trim(COALESCE(p_query, ''));
    v_is_platform_admin BOOLEAN := public.is_platform_admin(v_staff_id);
    v_team_id UUID := public.current_staff_team_id();
BEGIN
    PERFORM public.assert_staff();

    IF length(v_clean_query) < 3 THEN
        RAISE EXCEPTION 'La búsqueda requiere al menos 3 caracteres.';
    END IF;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        v_staff_id,
        'staff_search_fans',
        'profiles',
        v_staff_id::text,
        NULL,
        jsonb_build_object('query', v_clean_query, 'team_id', v_team_id)
    );

    RETURN QUERY
    SELECT 
        p.id,
        p.display_name,
        p.avatar_url,
        p.status::text,
        COALESCE(w.balance_cache, 0) AS pearl_balance,
        COALESCE((
            SELECT jsonb_agg(to_jsonb(sub))
            FROM (
                SELECT 
                    r.id,
                    r.status,
                    r.variant,
                    r.cost_pearls,
                    r.created_at,
                    pr.name AS product_name
                FROM public.redemptions r
                JOIN public.products pr ON pr.id = r.product_id
                WHERE r.fan_id = p.id
                  AND (v_is_platform_admin OR r.team_id = v_team_id)
                ORDER BY r.created_at DESC
                LIMIT 5
            ) sub
        ), '[]'::jsonb) AS last_5_redemptions
    FROM public.profiles p
    LEFT JOIN public.wallets w ON w.fan_id = p.id
    WHERE (
        p.display_name ILIKE '%' || v_clean_query || '%'
        OR p.id::text ILIKE '%' || v_clean_query || '%'
    )
    ORDER BY p.display_name ASC
    LIMIT v_eff_limit;
END;
$function$;

-- ----------------------------------------------------------------------------
-- 2. Catalog & Trivia Management
-- ----------------------------------------------------------------------------

-- 2.1 admin_upsert_product
CREATE OR REPLACE FUNCTION public.admin_upsert_product(p_product JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_product_id UUID;
    v_cost INT;
    v_stock INT;
    v_team_id UUID;
BEGIN
    v_product_id := (p_product->>'id')::UUID;
    v_cost := (p_product->>'cost_pearls')::INT;
    v_stock := (p_product->>'stock')::INT;

    IF v_cost <= 0 THEN
        RAISE EXCEPTION 'El costo en perlitas debe ser mayor a cero.';
    END IF;

    IF v_stock < 0 THEN
        RAISE EXCEPTION 'El stock no puede ser negativo.';
    END IF;

    IF v_product_id IS NOT NULL THEN
        SELECT team_id INTO v_team_id FROM public.products WHERE id = v_product_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Producto no encontrado.';
        END IF;
        PERFORM public.assert_team_admin(v_team_id);
    ELSE
        v_team_id := COALESCE((p_product->>'team_id')::UUID, public.current_staff_team_id());
        PERFORM public.assert_team_admin(v_team_id);
    END IF;

    IF v_product_id IS NULL THEN
        INSERT INTO public.products (
            team_id, name, description, category, cost_pearls, stock, variants, active, image_url, valid_until
        ) VALUES (
            v_team_id,
            p_product->>'name',
            p_product->>'description',
            (p_product->>'category')::product_category,
            v_cost,
            v_stock,
            COALESCE(p_product->'variants', '[]'::jsonb),
            COALESCE((p_product->>'active')::BOOLEAN, true),
            p_product->>'image_url',
            (p_product->>'valid_until')::TIMESTAMPTZ
        ) RETURNING id INTO v_product_id;
    ELSE
        UPDATE public.products SET
            name = COALESCE(p_product->>'name', name),
            description = COALESCE(p_product->>'description', description),
            category = COALESCE((p_product->>'category')::product_category, category),
            cost_pearls = COALESCE(v_cost, cost_pearls),
            stock = COALESCE(v_stock, stock),
            variants = COALESCE(p_product->'variants', variants),
            active = COALESCE((p_product->>'active')::BOOLEAN, active),
            image_url = COALESCE(p_product->>'image_url', image_url),
            valid_until = COALESCE((p_product->>'valid_until')::TIMESTAMPTZ, valid_until)
        WHERE id = v_product_id;
    END IF;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'upsert_product', 'products', v_product_id::text,
        jsonb_build_object('product', p_product, 'team_id', v_team_id)
    );

    RETURN jsonb_build_object('id', v_product_id, 'status', 'success');
END;
$function$;

-- 2.2 staff_upsert_product
CREATE OR REPLACE FUNCTION public.staff_upsert_product(p_product JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_staff_id UUID := auth.uid();
    v_product_id UUID;
    v_team_id UUID;
    v_is_new BOOLEAN := false;
BEGIN
    IF p_product->>'id' IS NOT NULL AND (p_product->>'id') != '' THEN
        v_product_id := (p_product->>'id')::UUID;
        SELECT team_id INTO v_team_id FROM public.products WHERE id = v_product_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Producto no encontrado.';
        END IF;
        PERFORM public.assert_team_staff(v_team_id);
    ELSE
        v_product_id := gen_random_uuid();
        v_team_id := COALESCE((p_product->>'team_id')::UUID, public.current_staff_team_id());
        PERFORM public.assert_team_staff(v_team_id);
        v_is_new := true;
    END IF;

    IF v_is_new THEN
        INSERT INTO public.products (
            id, team_id, name, description, category, cost_pearls, stock, active, image_url, valid_until
        ) VALUES (
            v_product_id,
            v_team_id,
            p_product->>'name',
            p_product->>'description',
            (p_product->>'category')::product_category,
            (p_product->>'cost_pearls')::INT,
            (p_product->>'stock')::INT,
            COALESCE((p_product->>'active')::BOOLEAN, true),
            p_product->>'image_url',
            (p_product->>'valid_until')::TIMESTAMPTZ
        );
    ELSE
        UPDATE public.products SET
            name = COALESCE(p_product->>'name', name),
            description = COALESCE(p_product->>'description', description),
            category = COALESCE((p_product->>'category')::product_category, category),
            cost_pearls = COALESCE((p_product->>'cost_pearls')::INT, cost_pearls),
            stock = COALESCE((p_product->>'stock')::INT, stock),
            active = COALESCE((p_product->>'active')::BOOLEAN, active),
            image_url = COALESCE(p_product->>'image_url', image_url),
            valid_until = COALESCE((p_product->>'valid_until')::TIMESTAMPTZ, valid_until)
        WHERE id = v_product_id;
    END IF;

    RETURN jsonb_build_object('id', v_product_id, 'team_id', v_team_id);
END;
$function$;

-- 2.3 admin_upsert_trivia
CREATE OR REPLACE FUNCTION public.admin_upsert_trivia(
    p_trivia JSONB,
    p_questions JSONB DEFAULT NULL::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_trivia_id UUID;
    v_team_id UUID;
    v_existing_status trivia_status;
    v_attempt_count INT := 0;
    v_q_elem JSONB;
    v_opt_elem JSONB;
    v_q_id UUID;
BEGIN
    v_trivia_id := (p_trivia->>'id')::UUID;

    IF v_trivia_id IS NOT NULL THEN
        SELECT team_id, status INTO v_team_id, v_existing_status FROM public.trivias WHERE id = v_trivia_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Trivia no encontrada.';
        END IF;

        PERFORM public.assert_team_admin(v_team_id);

        SELECT COUNT(*) INTO v_attempt_count FROM public.trivia_attempts WHERE trivia_id = v_trivia_id;

        IF v_attempt_count > 0 AND p_questions IS NOT NULL THEN
            RAISE EXCEPTION 'No se pueden modificar preguntas u opciones de una trivia con intentos registrados. Duplique o archive la trivia.';
        END IF;
    ELSE
        v_team_id := COALESCE((p_trivia->>'team_id')::UUID, public.current_staff_team_id());
        PERFORM public.assert_team_admin(v_team_id);
    END IF;

    IF v_trivia_id IS NULL THEN
        INSERT INTO public.trivias (
            team_id, title, description, status, starts_at, ends_at, time_limit_seconds, reward_rules, max_attempts, target_segment_id
        ) VALUES (
            v_team_id,
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

    IF p_questions IS NOT NULL AND v_attempt_count = 0 THEN
        DELETE FROM public.trivia_questions WHERE trivia_id = v_trivia_id;

        FOR v_q_elem IN SELECT * FROM jsonb_array_elements(p_questions)
        LOOP
            INSERT INTO public.trivia_questions (
                team_id, trivia_id, question_text, points, order_index
            ) VALUES (
                v_team_id,
                v_trivia_id,
                v_q_elem->>'question_text',
                COALESCE((v_q_elem->>'points')::INT, 50),
                COALESCE((v_q_elem->>'order_index')::INT, 0)
            ) RETURNING id INTO v_q_id;

            IF v_q_elem->'options' IS NOT NULL THEN
                FOR v_opt_elem IN SELECT * FROM jsonb_array_elements(v_q_elem->'options')
                LOOP
                    INSERT INTO public.trivia_options (
                        team_id, question_id, option_text, is_correct, order_index
                    ) VALUES (
                        v_team_id,
                        v_q_id,
                        v_opt_elem->>'option_text',
                        COALESCE((v_opt_elem->>'is_correct')::BOOLEAN, false),
                        COALESCE((v_opt_elem->>'order_index')::INT, 0)
                    );
                END LOOP;
            END IF;
        END LOOP;
    END IF;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'upsert_trivia', 'trivias', v_trivia_id::text,
        jsonb_build_object('trivia', p_trivia, 'team_id', v_team_id)
    );

    RETURN jsonb_build_object('id', v_trivia_id, 'status', 'success');
END;
$function$;

-- 2.4 staff_upsert_trivia
CREATE OR REPLACE FUNCTION public.staff_upsert_trivia(p_trivia JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_staff_id UUID := auth.uid();
    v_trivia_id UUID;
    v_team_id UUID;
    v_is_new BOOLEAN := false;
BEGIN
    IF p_trivia->>'id' IS NOT NULL AND (p_trivia->>'id') != '' THEN
        v_trivia_id := (p_trivia->>'id')::UUID;
        SELECT team_id INTO v_team_id FROM public.trivias WHERE id = v_trivia_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Trivia no encontrada.';
        END IF;
        PERFORM public.assert_team_staff(v_team_id);
    ELSE
        v_trivia_id := gen_random_uuid();
        v_team_id := COALESCE((p_trivia->>'team_id')::UUID, public.current_staff_team_id());
        PERFORM public.assert_team_staff(v_team_id);
        v_is_new := true;
    END IF;

    IF v_is_new THEN
        INSERT INTO public.trivias (
            id, team_id, title, description, starts_at, ends_at, status, max_attempts, time_limit_seconds, reward_rules
        ) VALUES (
            v_trivia_id,
            v_team_id,
            p_trivia->>'title',
            p_trivia->>'description',
            (p_trivia->>'starts_at')::TIMESTAMPTZ,
            (p_trivia->>'ends_at')::TIMESTAMPTZ,
            COALESCE((p_trivia->>'status')::trivia_status, 'draft'::trivia_status),
            COALESCE((p_trivia->>'max_attempts')::INT, 1),
            COALESCE((p_trivia->>'time_limit_seconds')::INT, 60),
            COALESCE(p_trivia->'reward_rules', '{"per_correct_pearls": 50, "perfect_score_bonus": 100}'::jsonb)
        );
    ELSE
        UPDATE public.trivias SET
            title = COALESCE(p_trivia->>'title', title),
            description = COALESCE(p_trivia->>'description', description),
            starts_at = COALESCE((p_trivia->>'starts_at')::TIMESTAMPTZ, starts_at),
            ends_at = COALESCE((p_trivia->>'ends_at')::TIMESTAMPTZ, ends_at),
            status = COALESCE((p_trivia->>'status')::trivia_status, status),
            max_attempts = COALESCE((p_trivia->>'max_attempts')::INT, max_attempts),
            time_limit_seconds = COALESCE((p_trivia->>'time_limit_seconds')::INT, time_limit_seconds),
            reward_rules = COALESCE(p_trivia->'reward_rules', reward_rules)
        WHERE id = v_trivia_id;
    END IF;

    RETURN jsonb_build_object('id', v_trivia_id, 'team_id', v_team_id);
END;
$function$;

-- 2.5 admin_publish_trivia
CREATE OR REPLACE FUNCTION public.admin_publish_trivia(p_trivia_id UUID)
RETURNS JSONB
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
    SELECT * INTO v_trivia FROM public.trivias WHERE id = p_trivia_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Trivia no encontrada.';
    END IF;

    PERFORM public.assert_team_admin(v_trivia.team_id);

    IF v_trivia.starts_at >= v_trivia.ends_at THEN
        RAISE EXCEPTION 'La fecha de inicio debe ser anterior a la fecha de fin.';
    END IF;

    IF v_trivia.time_limit_seconds <= 0 THEN
        RAISE EXCEPTION 'El tiempo límite debe ser mayor a 0 segundos.';
    END IF;

    SELECT COUNT(*) INTO v_q_count FROM public.trivia_questions WHERE trivia_id = p_trivia_id;
    IF v_q_count < 1 THEN
        RAISE EXCEPTION 'La trivia debe contener al menos 1 pregunta para ser publicada.';
    END IF;

    SELECT COUNT(*) INTO v_invalid_q
    FROM public.trivia_questions q
    WHERE q.trivia_id = p_trivia_id
      AND (
          SELECT COUNT(*) FROM public.trivia_options o 
          WHERE o.question_id = q.id AND o.is_correct = true
      ) != 1;

    IF v_invalid_q > 0 THEN
        RAISE EXCEPTION 'Cada pregunta debe tener exactamente UNA opción correcta.';
    END IF;

    v_per_correct := COALESCE((v_trivia.reward_rules->>'per_correct_pearls')::INT, 50);
    v_perfect_bonus := COALESCE((v_trivia.reward_rules->>'perfect_score_bonus')::INT, 100);
    v_max_possible := (v_q_count * v_per_correct) + v_perfect_bonus;

    SELECT daily_max_pearls_trivia INTO v_daily_cap FROM public.economy_settings LIMIT 1;
    v_daily_cap := COALESCE(v_daily_cap, 500);

    IF v_max_possible > v_daily_cap THEN
        RAISE EXCEPTION 'La recompensa máxima posible (%) excede el tope diario de perlitas permitido por la economía (%).', v_max_possible, v_daily_cap;
    END IF;

    UPDATE public.trivias SET status = 'published' WHERE id = p_trivia_id;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'publish_trivia', 'trivias', p_trivia_id::text,
        jsonb_build_object('status', 'published', 'max_possible_pearls', v_max_possible, 'team_id', v_trivia.team_id)
    );

    RETURN jsonb_build_object('id', p_trivia_id, 'status', 'published');
END;
$function$;

-- 2.6 admin_archive_trivia
CREATE OR REPLACE FUNCTION public.admin_archive_trivia(p_trivia_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_trivia public.trivias%ROWTYPE;
BEGIN
    SELECT * INTO v_trivia FROM public.trivias WHERE id = p_trivia_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Trivia no encontrada.';
    END IF;

    PERFORM public.assert_team_admin(v_trivia.team_id);

    UPDATE public.trivias SET status = 'archived' WHERE id = p_trivia_id;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (v_admin_id, 'archive_trivia', 'trivias', p_trivia_id::text, jsonb_build_object('status', 'archived', 'team_id', v_trivia.team_id));

    RETURN jsonb_build_object('id', p_trivia_id, 'status', 'archived');
END;
$function$;

-- 2.7 admin_duplicate_trivia
CREATE OR REPLACE FUNCTION public.admin_duplicate_trivia(p_trivia_id UUID)
RETURNS JSONB
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
    SELECT * INTO v_orig FROM public.trivias WHERE id = p_trivia_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Trivia original no encontrada.';
    END IF;

    PERFORM public.assert_team_admin(v_orig.team_id);

    INSERT INTO public.trivias (
        team_id, title, description, status, starts_at, ends_at, time_limit_seconds, reward_rules, max_attempts, target_segment_id
    ) VALUES (
        v_orig.team_id,
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

    FOR v_q IN SELECT * FROM public.trivia_questions WHERE trivia_id = p_trivia_id ORDER BY order_index LOOP
        INSERT INTO public.trivia_questions (
            team_id, trivia_id, question_text, points, order_index
        ) VALUES (
            v_orig.team_id, v_new_id, v_q.question_text, v_q.points, v_q.order_index
        ) RETURNING id INTO v_new_q_id;

        INSERT INTO public.trivia_options (team_id, question_id, option_text, is_correct, order_index)
        SELECT v_orig.team_id, v_new_q_id, option_text, is_correct, order_index
        FROM public.trivia_options
        WHERE question_id = v_q.id;
    END LOOP;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'duplicate_trivia', 'trivias', v_new_id::text,
        jsonb_build_object('source_id', p_trivia_id, 'new_id', v_new_id, 'team_id', v_orig.team_id)
    );

    RETURN jsonb_build_object('original_id', p_trivia_id, 'new_id', v_new_id);
END;
$function$;

-- ----------------------------------------------------------------------------
-- 3. Games & Players Management
-- ----------------------------------------------------------------------------

-- 3.1 admin_upsert_game
CREATE OR REPLACE FUNCTION public.admin_upsert_game(p_game JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_game_id UUID;
    v_team_id UUID;
BEGIN
    v_game_id := (p_game->>'id')::UUID;

    IF v_game_id IS NOT NULL THEN
        SELECT team_id INTO v_team_id FROM public.games WHERE id = v_game_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Partido no encontrado.';
        END IF;
        PERFORM public.assert_team_admin(v_team_id);
    ELSE
        v_team_id := COALESCE((p_game->>'team_id')::UUID, public.current_staff_team_id());
        PERFORM public.assert_team_admin(v_team_id);
    END IF;

    IF v_game_id IS NULL THEN
        INSERT INTO public.games (
            team_id, opponent, opponent_logo_url, location, game_date, is_home, status, our_score, opponent_score
        ) VALUES (
            v_team_id,
            p_game->>'opponent',
            p_game->>'opponent_logo_url',
            p_game->>'location',
            (p_game->>'game_date')::TIMESTAMPTZ,
            COALESCE((p_game->>'is_home')::BOOLEAN, true),
            COALESCE((p_game->>'status')::game_status, 'scheduled'::game_status),
            (p_game->>'our_score')::INT,
            (p_game->>'opponent_score')::INT
        ) RETURNING id INTO v_game_id;
    ELSE
        UPDATE public.games SET
            opponent = COALESCE(p_game->>'opponent', opponent),
            opponent_logo_url = CASE WHEN p_game ? 'opponent_logo_url' THEN p_game->>'opponent_logo_url' ELSE opponent_logo_url END,
            location = COALESCE(p_game->>'location', location),
            game_date = COALESCE((p_game->>'game_date')::TIMESTAMPTZ, game_date),
            is_home = COALESCE((p_game->>'is_home')::BOOLEAN, is_home),
            status = COALESCE((p_game->>'status')::game_status, status),
            our_score = CASE WHEN p_game ? 'our_score' THEN (p_game->>'our_score')::INT ELSE our_score END,
            opponent_score = CASE WHEN p_game ? 'opponent_score' THEN (p_game->>'opponent_score')::INT ELSE opponent_score END
        WHERE id = v_game_id;
    END IF;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'upsert_game', 'games', v_game_id::text,
        jsonb_build_object('game', p_game, 'team_id', v_team_id)
    );

    RETURN jsonb_build_object('id', v_game_id, 'status', 'success');
END;
$function$;

-- 3.2 admin_delete_game
CREATE OR REPLACE FUNCTION public.admin_delete_game(p_game_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_team_id UUID;
BEGIN
    SELECT team_id INTO v_team_id FROM public.games WHERE id = p_game_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Partido no encontrado.';
    END IF;

    PERFORM public.assert_team_admin(v_team_id);

    UPDATE public.games SET status = 'cancelled' WHERE id = p_game_id;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (v_admin_id, 'cancel_game', 'games', p_game_id::text, jsonb_build_object('status', 'cancelled', 'team_id', v_team_id));

    RETURN jsonb_build_object('id', p_game_id, 'status', 'cancelled');
END;
$function$;

-- 3.3 admin_upsert_player
CREATE OR REPLACE FUNCTION public.admin_upsert_player(p_player JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_player_id UUID;
    v_team_id UUID;
BEGIN
    v_player_id := (p_player->>'id')::UUID;

    IF v_player_id IS NOT NULL THEN
        SELECT team_id INTO v_team_id FROM public.players WHERE id = v_player_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Jugador no encontrado.';
        END IF;
        PERFORM public.assert_team_admin(v_team_id);
    ELSE
        v_team_id := COALESCE((p_player->>'team_id')::UUID, public.current_staff_team_id());
        PERFORM public.assert_team_admin(v_team_id);
    END IF;

    IF v_player_id IS NULL THEN
        INSERT INTO public.players (
            team_id, name, jersey_number, position, height, age, nationality, bio, is_active, is_star, instagram_url
        ) VALUES (
            v_team_id,
            p_player->>'name',
            (p_player->>'jersey_number')::INT,
            p_player->>'position',
            p_player->>'height',
            (p_player->>'age')::INT,
            p_player->>'nationality',
            p_player->>'bio',
            COALESCE((p_player->>'is_active')::BOOLEAN, true),
            COALESCE((p_player->>'is_star')::BOOLEAN, false),
            p_player->>'instagram_url'
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
            is_star = COALESCE((p_player->>'is_star')::BOOLEAN, is_star),
            instagram_url = CASE WHEN p_player ? 'instagram_url' THEN p_player->>'instagram_url' ELSE instagram_url END
        WHERE id = v_player_id;
    END IF;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'upsert_player', 'players', v_player_id::text,
        jsonb_build_object('player', p_player, 'team_id', v_team_id)
    );

    RETURN jsonb_build_object('id', v_player_id, 'status', 'success');
END;
$function$;

-- 3.4 admin_delete_player
CREATE OR REPLACE FUNCTION public.admin_delete_player(p_player_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_team_id UUID;
BEGIN
    SELECT team_id INTO v_team_id FROM public.players WHERE id = p_player_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Jugador no encontrado.';
    END IF;

    PERFORM public.assert_team_admin(v_team_id);

    UPDATE public.players SET is_active = false WHERE id = p_player_id;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (v_admin_id, 'deactivate_player', 'players', p_player_id::text, jsonb_build_object('status', 'deactivated', 'team_id', v_team_id));

    RETURN jsonb_build_object('id', p_player_id, 'status', 'deactivated');
END;
$function$;

-- ----------------------------------------------------------------------------
-- 4. Segments Management
-- ----------------------------------------------------------------------------

-- 4.1 segment_count
CREATE OR REPLACE FUNCTION public.segment_count(p_segment_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_filters JSONB;
    v_count INT;
    v_team_id UUID;
BEGIN
    SELECT team_id, filters INTO v_team_id, v_filters FROM public.segments WHERE id = p_segment_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Segmento no encontrado.';
    END IF;

    PERFORM public.assert_team_admin(v_team_id);

    SELECT COUNT(*) INTO v_count
    FROM public.profiles p
    WHERE 
        ((v_filters->>'municipality') IS NULL OR p.municipality = (v_filters->>'municipality'))
        AND ((v_filters->>'gender') IS NULL OR p.gender = (v_filters->>'gender'))
        AND ((v_filters->>'shirt_size') IS NULL OR p.shirt_size = (v_filters->>'shirt_size'))
        AND ((v_filters->>'favorite_player_id') IS NULL OR p.favorite_player_id = (v_filters->>'favorite_player_id')::UUID)
        AND ((v_filters->>'status') IS NULL OR p.status::TEXT = (v_filters->>'status'))
        AND (
            (v_filters->>'min_age') IS NULL 
            OR p.birth_date <= (CURRENT_DATE - ((v_filters->>'min_age')::INT * INTERVAL '1 year'))
        )
        AND (
            (v_filters->>'max_age') IS NULL 
            OR p.birth_date >= (CURRENT_DATE - (((v_filters->>'max_age')::INT + 1) * INTERVAL '1 year'))
        );

    RETURN v_count;
END;
$function$;

-- 4.2 segment_members
CREATE OR REPLACE FUNCTION public.segment_members(
    p_segment_id UUID,
    p_limit INTEGER DEFAULT 50,
    p_cursor UUID DEFAULT NULL::UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_filters JSONB;
    v_res JSONB;
    v_team_id UUID;
BEGIN
    SELECT team_id, filters INTO v_team_id, v_filters FROM public.segments WHERE id = p_segment_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Segmento no encontrado.';
    END IF;

    PERFORM public.assert_team_admin(v_team_id);

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
            AND ((v_filters->>'status') IS NULL OR p.status::TEXT = (v_filters->>'status'))
            AND (
                (v_filters->>'min_age') IS NULL 
                OR p.birth_date <= (CURRENT_DATE - ((v_filters->>'min_age')::INT * INTERVAL '1 year'))
            )
            AND (
                (v_filters->>'max_age') IS NULL 
                OR p.birth_date >= (CURRENT_DATE - (((v_filters->>'max_age')::INT + 1) * INTERVAL '1 year'))
            )
            AND (p_cursor IS NULL OR p.id > p_cursor)
        ORDER BY p.id ASC
        LIMIT LEAST(GREATEST(p_limit, 1), 5000)
    ) sub;

    RETURN v_res;
END;
$function$;

-- 4.3 admin_upsert_segment
CREATE OR REPLACE FUNCTION public.admin_upsert_segment(p_segment JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_segment_id UUID;
    v_team_id UUID;
    v_filters JSONB;
    v_key TEXT;
    v_allowed_keys TEXT[] := ARRAY['municipality', 'gender', 'shirt_size', 'favorite_player_id', 'status', 'min_age', 'max_age'];
BEGIN
    v_segment_id := (p_segment->>'id')::UUID;
    v_filters := COALESCE(p_segment->'filters', '{}'::jsonb);

    FOR v_key IN SELECT jsonb_object_keys(v_filters)
    LOOP
        IF NOT (v_key = ANY(v_allowed_keys)) THEN
            RAISE EXCEPTION 'Campo de filtro no permitido en segmentos: %', v_key;
        END IF;
    END LOOP;

    IF v_segment_id IS NOT NULL THEN
        SELECT team_id INTO v_team_id FROM public.segments WHERE id = v_segment_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Segmento no encontrado.';
        END IF;
        PERFORM public.assert_team_admin(v_team_id);
    ELSE
        v_team_id := COALESCE((p_segment->>'team_id')::UUID, public.current_staff_team_id());
        PERFORM public.assert_team_admin(v_team_id);
    END IF;

    IF v_segment_id IS NULL THEN
        INSERT INTO public.segments (
            team_id, name, description, filters
        ) VALUES (
            v_team_id,
            p_segment->>'name',
            p_segment->>'description',
            v_filters
        ) RETURNING id INTO v_segment_id;
    ELSE
        UPDATE public.segments SET
            name = COALESCE(p_segment->>'name', name),
            description = COALESCE(p_segment->>'description', description),
            filters = v_filters
        WHERE id = v_segment_id;
    END IF;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'upsert_segment', 'segments', v_segment_id::text,
        jsonb_build_object('segment', p_segment, 'team_id', v_team_id)
    );

    RETURN jsonb_build_object('id', v_segment_id, 'status', 'success');
END;
$function$;

-- ----------------------------------------------------------------------------
-- 5. Interactive Challenges Management
-- ----------------------------------------------------------------------------

-- 5.1 admin_delete_guess_player_challenge
CREATE OR REPLACE FUNCTION public.admin_delete_guess_player_challenge(p_challenge_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_team_id UUID;
BEGIN
    SELECT team_id INTO v_team_id FROM public.guess_player_challenges WHERE id = p_challenge_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Desafío no encontrado.';
    END IF;

    PERFORM public.assert_team_admin(v_team_id);

    DELETE FROM public.guess_player_challenges WHERE id = p_challenge_id;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (v_admin_id, 'delete_guess_player_challenge', 'guess_player_challenges', p_challenge_id::text, jsonb_build_object('team_id', v_team_id));

    RETURN jsonb_build_object('id', p_challenge_id, 'status', 'deleted');
END;
$function$;

-- 5.2 admin_delete_trivia_poll
CREATE OR REPLACE FUNCTION public.admin_delete_trivia_poll(p_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_team_id UUID;
BEGIN
    SELECT team_id INTO v_team_id FROM public.trivia_polls WHERE id = p_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Encuesta no encontrada.';
    END IF;

    PERFORM public.assert_team_admin(v_team_id);

    DELETE FROM public.trivia_polls WHERE id = p_id;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (v_admin_id, 'delete_trivia_poll', 'trivia_polls', p_id::text, jsonb_build_object('team_id', v_team_id));

    RETURN jsonb_build_object('id', p_id, 'status', 'deleted');
END;
$function$;

-- 5.3 admin_resolve_trivia_poll
CREATE OR REPLACE FUNCTION public.admin_resolve_trivia_poll(
    p_poll_id UUID,
    p_correct_option_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_poll public.trivia_polls%ROWTYPE;
    v_option RECORD;
    v_vote RECORD;
    v_winners_count INT := 0;
    v_total_pearls INT := 0;
    v_reward_pearls INT;
    v_today_earned INT;
    v_week_earned INT;
    v_daily_cap INT := 1000;
    v_weekly_cap INT := 5000;
    v_rem_daily INT;
    v_rem_weekly INT;
    v_effective_cap INT;
    v_pearls_to_award INT;
    v_today_start_caracas TIMESTAMPTZ := date_trunc('day', NOW() AT TIME ZONE 'America/Caracas') AT TIME ZONE 'America/Caracas';
    v_week_start_caracas TIMESTAMPTZ := date_trunc('week', NOW() AT TIME ZONE 'America/Caracas') AT TIME ZONE 'America/Caracas';
BEGIN
    SELECT * INTO v_poll FROM public.trivia_polls WHERE id = p_poll_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Encuesta no encontrada.';
    END IF;

    PERFORM public.assert_team_admin(v_poll.team_id);

    IF v_poll.status = 'resolved' THEN
        RAISE EXCEPTION 'Esta encuesta ya ha sido resuelta previamente.';
    END IF;

    SELECT * INTO v_option FROM public.trivia_poll_options WHERE id = p_correct_option_id AND poll_id = p_poll_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La opción ganadora especificada no pertenece a esta encuesta.';
    END IF;

    UPDATE public.trivia_poll_options SET is_correct = (id = p_correct_option_id) WHERE poll_id = p_poll_id;
    v_reward_pearls := v_poll.reward_pearls;

    FOR v_vote IN 
        SELECT v.fan_id, v.id as vote_id
        FROM public.trivia_poll_votes v
        WHERE v.poll_id = p_poll_id AND v.option_id = p_correct_option_id
        FOR UPDATE
    LOOP
        SELECT COALESCE(SUM(amount), 0) INTO v_today_earned
        FROM public.ledger_entries
        WHERE fan_id = v_vote.fan_id AND created_at >= v_today_start_caracas AND amount > 0;

        SELECT COALESCE(SUM(amount), 0) INTO v_week_earned
        FROM public.ledger_entries
        WHERE fan_id = v_vote.fan_id AND created_at >= v_week_start_caracas AND amount > 0;

        v_rem_daily := GREATEST(0, v_daily_cap - v_today_earned);
        v_rem_weekly := GREATEST(0, v_weekly_cap - v_week_earned);
        v_effective_cap := LEAST(v_rem_daily, v_rem_weekly);
        v_pearls_to_award := LEAST(v_reward_pearls, v_effective_cap);

        IF v_pearls_to_award > 0 THEN
            UPDATE public.wallets 
            SET balance_cache = balance_cache + v_pearls_to_award 
            WHERE fan_id = v_vote.fan_id;

            INSERT INTO public.ledger_entries (fan_id, amount, type, description)
            VALUES (
                v_vote.fan_id,
                v_pearls_to_award,
                'poll_reward',
                'Premio por acertar encuesta: ' || v_poll.title
            );

            v_total_pearls := v_total_pearls + v_pearls_to_award;
        END IF;

        v_winners_count := v_winners_count + 1;
    END LOOP;

    UPDATE public.trivia_polls SET status = 'resolved' WHERE id = p_poll_id;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'resolve_trivia_poll', 'trivia_polls', p_poll_id::text,
        jsonb_build_object(
            'correct_option_id', p_correct_option_id,
            'winners_count', v_winners_count,
            'total_pearls_awarded', v_total_pearls,
            'team_id', v_poll.team_id
        )
    );

    RETURN jsonb_build_object(
        'poll_id', p_poll_id,
        'status', 'resolved',
        'winners_count', v_winners_count,
        'total_pearls_awarded', v_total_pearls
    );
END;
$function$;

-- 5.4 admin_resolve_over_under
CREATE OR REPLACE FUNCTION public.admin_resolve_over_under(
    p_prediction_id UUID,
    p_actual_value NUMERIC(6,1)
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_pred public.over_under_predictions%ROWTYPE;
    v_winning_choice TEXT;
    v_vote RECORD;
    v_winners_count INT := 0;
    v_total_pearls INT := 0;
    v_reward_pearls INT;
    v_today_earned INT;
    v_week_earned INT;
    v_daily_cap INT := 1000;
    v_weekly_cap INT := 5000;
    v_rem_daily INT;
    v_rem_weekly INT;
    v_effective_cap INT;
    v_pearls_to_award INT;
    v_today_start_caracas TIMESTAMPTZ := date_trunc('day', NOW() AT TIME ZONE 'America/Caracas') AT TIME ZONE 'America/Caracas';
    v_week_start_caracas TIMESTAMPTZ := date_trunc('week', NOW() AT TIME ZONE 'America/Caracas') AT TIME ZONE 'America/Caracas';
BEGIN
    SELECT * INTO v_pred FROM public.over_under_predictions WHERE id = p_prediction_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Predicción Over/Under no encontrada.';
    END IF;

    PERFORM public.assert_team_admin(v_pred.team_id);

    IF v_pred.status = 'resolved' THEN
        RAISE EXCEPTION 'Esta predicción ya ha sido resuelta previamente.';
    END IF;

    IF p_actual_value > v_pred.line_value THEN
        v_winning_choice := 'OVER';
    ELSIF p_actual_value < v_pred.line_value THEN
        v_winning_choice := 'UNDER';
    ELSE
        v_winning_choice := 'PUSH';
    END IF;

    v_reward_pearls := v_pred.reward_pearls;

    IF v_winning_choice != 'PUSH' THEN
        FOR v_vote IN 
            SELECT fan_id 
            FROM public.over_under_votes 
            WHERE prediction_id = p_prediction_id AND choice = v_winning_choice
            FOR UPDATE
        LOOP
            SELECT COALESCE(SUM(amount), 0) INTO v_today_earned
            FROM public.ledger_entries
            WHERE fan_id = v_vote.fan_id AND created_at >= v_today_start_caracas AND amount > 0;

            SELECT COALESCE(SUM(amount), 0) INTO v_week_earned
            FROM public.ledger_entries
            WHERE fan_id = v_vote.fan_id AND created_at >= v_week_start_caracas AND amount > 0;

            v_rem_daily := GREATEST(0, v_daily_cap - v_today_earned);
            v_rem_weekly := GREATEST(0, v_weekly_cap - v_week_earned);
            v_effective_cap := LEAST(v_rem_daily, v_rem_weekly);
            v_pearls_to_award := LEAST(v_reward_pearls, v_effective_cap);

            IF v_pearls_to_award > 0 THEN
                UPDATE public.wallets 
                SET balance_cache = balance_cache + v_pearls_to_award 
                WHERE fan_id = v_vote.fan_id;

                INSERT INTO public.ledger_entries (fan_id, amount, type, description)
                VALUES (
                    v_vote.fan_id,
                    v_pearls_to_award,
                    'prediction_reward',
                    'Premio por acertar Over/Under: ' || v_pred.title
                );

                v_total_pearls := v_total_pearls + v_pearls_to_award;
            END IF;

            v_winners_count := v_winners_count + 1;
        END LOOP;
    END IF;

    UPDATE public.over_under_predictions 
    SET status = 'resolved', actual_value = p_actual_value 
    WHERE id = p_prediction_id;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'resolve_over_under', 'over_under_predictions', p_prediction_id::text,
        jsonb_build_object(
            'actual_value', p_actual_value,
            'winning_choice', v_winning_choice,
            'winners_count', v_winners_count,
            'total_pearls', v_total_pearls,
            'team_id', v_pred.team_id
        )
    );

    RETURN jsonb_build_object(
        'prediction_id', p_prediction_id,
        'status', 'resolved',
        'winning_choice', v_winning_choice,
        'winners_count', v_winners_count,
        'total_pearls_awarded', v_total_pearls
    );
END;
$function$;

-- 5.5 admin_resolve_score_prediction
CREATE OR REPLACE FUNCTION public.admin_resolve_score_prediction(
    p_prediction_id UUID,
    p_final_guaiqueries_score INT,
    p_final_rival_score INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_pred public.score_predictions%ROWTYPE;
    v_vote RECORD;
    v_exact_count INT := 0;
    v_closest_count INT := 0;
    v_total_pearls INT := 0;
    v_min_diff INT := 999999;
    v_diff INT;
    v_exact_reward INT;
    v_closest_reward INT;
    v_today_earned INT;
    v_week_earned INT;
    v_daily_cap INT := 1000;
    v_weekly_cap INT := 5000;
    v_rem_daily INT;
    v_rem_weekly INT;
    v_effective_cap INT;
    v_pearls_to_award INT;
    v_today_start_caracas TIMESTAMPTZ := date_trunc('day', NOW() AT TIME ZONE 'America/Caracas') AT TIME ZONE 'America/Caracas';
    v_week_start_caracas TIMESTAMPTZ := date_trunc('week', NOW() AT TIME ZONE 'America/Caracas') AT TIME ZONE 'America/Caracas';
BEGIN
    SELECT * INTO v_pred FROM public.score_predictions WHERE id = p_prediction_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Predicción de marcador no encontrada.';
    END IF;

    PERFORM public.assert_team_admin(v_pred.team_id);

    IF v_pred.status = 'resolved' THEN
        RAISE EXCEPTION 'Esta predicción ya ha sido resuelta previamente.';
    END IF;

    v_exact_reward := v_pred.exact_reward_pearls;
    v_closest_reward := v_pred.closest_reward_pearls;

    -- 1. Premiar aciertos exactos
    FOR v_vote IN 
        SELECT fan_id 
        FROM public.score_prediction_votes 
        WHERE prediction_id = p_prediction_id 
          AND predicted_guaiqueries_score = p_final_guaiqueries_score
          AND predicted_rival_score = p_final_rival_score
        FOR UPDATE
    LOOP
        SELECT COALESCE(SUM(amount), 0) INTO v_today_earned
        FROM public.ledger_entries
        WHERE fan_id = v_vote.fan_id AND created_at >= v_today_start_caracas AND amount > 0;

        SELECT COALESCE(SUM(amount), 0) INTO v_week_earned
        FROM public.ledger_entries
        WHERE fan_id = v_vote.fan_id AND created_at >= v_week_start_caracas AND amount > 0;

        v_rem_daily := GREATEST(0, v_daily_cap - v_today_earned);
        v_rem_weekly := GREATEST(0, v_weekly_cap - v_week_earned);
        v_effective_cap := LEAST(v_rem_daily, v_rem_weekly);
        v_pearls_to_award := LEAST(v_exact_reward, v_effective_cap);

        IF v_pearls_to_award > 0 THEN
            UPDATE public.wallets 
            SET balance_cache = balance_cache + v_pearls_to_award 
            WHERE fan_id = v_vote.fan_id;

            INSERT INTO public.ledger_entries (fan_id, amount, type, description)
            VALUES (
                v_vote.fan_id,
                v_pearls_to_award,
                'prediction_reward',
                'Premio exacto por predicción de marcador: ' || v_pred.title
            );

            v_total_pearls := v_total_pearls + v_pearls_to_award;
        END IF;

        v_exact_count := v_exact_count + 1;
    END LOOP;

    -- 2. Si no hubo exactos, buscar los más cercanos
    IF v_exact_count = 0 THEN
        SELECT MIN(
            abs(predicted_guaiqueries_score - p_final_guaiqueries_score) +
            abs(predicted_rival_score - p_final_rival_score)
        ) INTO v_min_diff
        FROM public.score_prediction_votes
        WHERE prediction_id = p_prediction_id;

        IF v_min_diff IS NOT NULL THEN
            FOR v_vote IN 
                SELECT fan_id 
                FROM public.score_prediction_votes 
                WHERE prediction_id = p_prediction_id 
                  AND (
                      abs(predicted_guaiqueries_score - p_final_guaiqueries_score) +
                      abs(predicted_rival_score - p_final_rival_score)
                  ) = v_min_diff
                FOR UPDATE
            LOOP
                SELECT COALESCE(SUM(amount), 0) INTO v_today_earned
                FROM public.ledger_entries
                WHERE fan_id = v_vote.fan_id AND created_at >= v_today_start_caracas AND amount > 0;

                SELECT COALESCE(SUM(amount), 0) INTO v_week_earned
                FROM public.ledger_entries
                WHERE fan_id = v_vote.fan_id AND created_at >= v_week_start_caracas AND amount > 0;

                v_rem_daily := GREATEST(0, v_daily_cap - v_today_earned);
                v_rem_weekly := GREATEST(0, v_weekly_cap - v_week_earned);
                v_effective_cap := LEAST(v_rem_daily, v_rem_weekly);
                v_pearls_to_award := LEAST(v_closest_reward, v_effective_cap);

                IF v_pearls_to_award > 0 THEN
                    UPDATE public.wallets 
                    SET balance_cache = balance_cache + v_pearls_to_award 
                    WHERE fan_id = v_vote.fan_id;

                    INSERT INTO public.ledger_entries (fan_id, amount, type, description)
                    VALUES (
                        v_vote.fan_id,
                        v_pearls_to_award,
                        'prediction_reward',
                        'Premio al más cercano por predicción de marcador: ' || v_pred.title
                    );

                    v_total_pearls := v_total_pearls + v_pearls_to_award;
                END IF;

                v_closest_count := v_closest_count + 1;
            END LOOP;
        END IF;
    END IF;

    UPDATE public.score_predictions 
    SET status = 'resolved',
        final_guaiqueries_score = p_final_guaiqueries_score,
        final_rival_score = p_final_rival_score
    WHERE id = p_prediction_id;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'resolve_score_prediction', 'score_predictions', p_prediction_id::text,
        jsonb_build_object(
            'final_guaiqueries', p_final_guaiqueries_score,
            'final_rival', p_final_rival_score,
            'exact_count', v_exact_count,
            'closest_count', v_closest_count,
            'total_pearls', v_total_pearls,
            'team_id', v_pred.team_id
        )
    );

    RETURN jsonb_build_object(
        'prediction_id', p_prediction_id,
        'status', 'resolved',
        'exact_winners', v_exact_count,
        'closest_winners', v_closest_count,
        'total_pearls_awarded', v_total_pearls
    );
END;
$function$;

-- ----------------------------------------------------------------------------
-- 6. Landing CMS & Birthday Settings
-- ----------------------------------------------------------------------------

-- 6.1 activate_landing_cta
CREATE OR REPLACE FUNCTION public.activate_landing_cta(p_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_target public.landing_ctas%ROWTYPE;
BEGIN
    SELECT * INTO v_target FROM public.landing_ctas WHERE id = p_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Landing CTA no encontrado.';
    END IF;

    PERFORM public.assert_team_admin(v_target.team_id);

    UPDATE public.landing_ctas
    SET is_active = (id = p_id),
        updated_at = NOW()
    WHERE placement = v_target.placement AND team_id = v_target.team_id;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'activate_landing_cta', 'landing_ctas', p_id::text,
        jsonb_build_object('placement', v_target.placement, 'team_id', v_target.team_id)
    );
END;
$function$;

-- 6.2 admin_delete_login_modal_slide
CREATE OR REPLACE FUNCTION public.admin_delete_login_modal_slide(p_slide_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_team_id UUID;
BEGIN
    SELECT team_id INTO v_team_id FROM public.login_modal_slides WHERE id = p_slide_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Diapositiva no encontrada.';
    END IF;

    PERFORM public.assert_team_admin(v_team_id);

    DELETE FROM public.login_modal_slides WHERE id = p_slide_id;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'admin_delete_login_modal_slide', 'login_modal_slides', p_slide_id::text,
        jsonb_build_object('deleted_id', p_slide_id, 'team_id', v_team_id)
    );

    RETURN jsonb_build_object('id', p_slide_id, 'status', 'deleted');
END;
$function$;

-- 6.3 admin_update_notification_template
CREATE OR REPLACE FUNCTION public.admin_update_notification_template(
    p_template_id TEXT,
    p_title_template TEXT,
    p_body_template TEXT,
    p_is_active BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_team_id UUID := public.current_staff_team_id();
    v_is_platform_admin BOOLEAN := public.is_platform_admin(v_admin_id);
    v_updated_template public.notification_templates%ROWTYPE;
BEGIN
    IF trim(COALESCE(p_title_template, '')) = '' THEN
        RAISE EXCEPTION 'El título de la plantilla no puede estar vacío.';
    END IF;

    IF trim(COALESCE(p_body_template, '')) = '' THEN
        RAISE EXCEPTION 'El cuerpo de la plantilla no puede estar vacío.';
    END IF;

    IF NOT v_is_platform_admin THEN
        IF v_team_id IS NULL THEN
            RAISE EXCEPTION 'Club admin must belong to an active team.' USING ERRCODE = '42501';
        END IF;
        PERFORM public.assert_team_admin(v_team_id);
    END IF;

    UPDATE public.notification_templates
    SET title_template = trim(p_title_template),
        body_template = trim(p_body_template),
        is_active = p_is_active,
        updated_at = NOW()
    WHERE template_id = p_template_id
      AND (v_is_platform_admin OR team_id = v_team_id)
    RETURNING * INTO v_updated_template;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Plantilla de notificación no encontrada o sin autorización.';
    END IF;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'update_notification_template', 'notification_templates', p_template_id,
        jsonb_build_object('template_id', p_template_id, 'is_active', p_is_active, 'team_id', v_updated_template.team_id)
    );

    RETURN to_jsonb(v_updated_template);
END;
$function$;

-- 6.4 update_birthday_settings
CREATE OR REPLACE FUNCTION public.update_birthday_settings(
    p_enabled BOOLEAN,
    p_title TEXT,
    p_message TEXT,
    p_image_url TEXT,
    p_send_hour INTEGER,
    p_grace_days INTEGER,
    p_bonus_pearls INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_team_id UUID := public.current_staff_team_id();
    v_is_platform_admin BOOLEAN := public.is_platform_admin(v_admin_id);
BEGIN
    IF NOT v_is_platform_admin THEN
        IF v_team_id IS NULL THEN
            RAISE EXCEPTION 'Club admin must belong to an active team.' USING ERRCODE = '42501';
        END IF;
        PERFORM public.assert_team_admin(v_team_id);
    ELSE
        -- Default to team #1 for platform admin if not set
        v_team_id := COALESCE(v_team_id, 'a0000000-0000-0000-0000-000000000001'::UUID);
    END IF;

    UPDATE public.birthday_settings
    SET enabled = p_enabled,
        title = TRIM(p_title),
        message = TRIM(p_message),
        image_url = p_image_url,
        send_hour = p_send_hour,
        grace_days = p_grace_days,
        bonus_pearls = p_bonus_pearls,
        updated_at = NOW()
    WHERE team_id = v_team_id;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'update_birthday_settings', 'birthday_settings', v_team_id::text,
        jsonb_build_object('enabled', p_enabled, 'bonus_pearls', p_bonus_pearls, 'team_id', v_team_id)
    );

    RETURN jsonb_build_object('status', 'success', 'team_id', v_team_id);
END;
$function$;

-- ----------------------------------------------------------------------------
-- 7. Platform Admin Only RPCs
-- ----------------------------------------------------------------------------

-- 7.1 admin_suspend_fan (Platform Admin Only)
CREATE OR REPLACE FUNCTION public.admin_suspend_fan(p_fan_id UUID, p_reason TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
BEGIN
    PERFORM public.assert_platform_admin();

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

-- 7.2 admin_reactivate_fan (Platform Admin Only)
CREATE OR REPLACE FUNCTION public.admin_reactivate_fan(p_fan_id UUID, p_reason TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
BEGIN
    PERFORM public.assert_platform_admin();

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

-- 7.3 admin_update_economy_settings (Platform Admin Only)
CREATE OR REPLACE FUNCTION public.admin_update_economy_settings(
    p_daily_max_pearls_trivia INTEGER,
    p_trivia_daily_attempt_limit INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
BEGIN
    PERFORM public.assert_platform_admin();

    UPDATE public.economy_settings
    SET daily_max_pearls_trivia = p_daily_max_pearls_trivia,
        trivia_daily_attempt_limit = p_trivia_daily_attempt_limit,
        updated_at = NOW();

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'update_economy_settings', 'economy_settings', 'global',
        jsonb_build_object('daily_max_pearls_trivia', p_daily_max_pearls_trivia)
    );

    RETURN jsonb_build_object('status', 'success');
END;
$function$;

-- 7.4 admin_update_ads_settings (Platform Admin Only)
CREATE OR REPLACE FUNCTION public.admin_update_ads_settings(
    p_rewarded_video_pearls INTEGER,
    p_daily_cap_impressions INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
BEGIN
    PERFORM public.assert_platform_admin();

    UPDATE public.ads_settings
    SET rewarded_video_pearls = p_rewarded_video_pearls,
        daily_cap_impressions = p_daily_cap_impressions,
        updated_at = NOW();

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'update_ads_settings', 'ads_settings', 'global',
        jsonb_build_object('rewarded_video_pearls', p_rewarded_video_pearls)
    );

    RETURN jsonb_build_object('status', 'success');
END;
$function$;

-- 7.5 import_ad_report (Platform Admin Only)
CREATE OR REPLACE FUNCTION public.import_ad_report(
    p_day DATE,
    p_google_rewarded_impressions INTEGER,
    p_notes TEXT DEFAULT NULL::TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_db_completed INT;
    v_diff INT;
    v_discrepancy_pct NUMERIC;
BEGIN
    PERFORM public.assert_platform_admin();

    SELECT COUNT(*) INTO v_db_completed
    FROM public.ad_sessions
    WHERE day = p_day AND status = 'completed';

    v_diff := abs(COALESCE(p_google_rewarded_impressions, 0) - v_db_completed);
    IF COALESCE(p_google_rewarded_impressions, 0) > 0 THEN
        v_discrepancy_pct := round((v_diff::NUMERIC / p_google_rewarded_impressions::NUMERIC) * 100, 2);
    ELSE
        v_discrepancy_pct := 0;
    END IF;

    INSERT INTO public.ad_reconciliation (
        day, google_rewarded_impressions, db_completed_sessions,
        discrepancy_pct, imported_by, notes
    ) VALUES (
        p_day, p_google_rewarded_impressions, v_db_completed,
        v_discrepancy_pct, v_admin_id, p_notes
    )
    ON CONFLICT (day) DO UPDATE
    SET google_rewarded_impressions = EXCLUDED.google_rewarded_impressions,
        db_completed_sessions = EXCLUDED.db_completed_sessions,
        discrepancy_pct = EXCLUDED.discrepancy_pct,
        imported_by = EXCLUDED.imported_by,
        imported_at = NOW(),
        notes = EXCLUDED.notes;

    RETURN jsonb_build_object('status', 'success', 'day', p_day);
END;
$function$;

-- ----------------------------------------------------------------------------
-- 8. Analytics Multi-Tenant Scoping (all 10 functions)
-- ----------------------------------------------------------------------------

-- 8.1 analytics_overview
CREATE OR REPLACE FUNCTION public.analytics_overview(
    p_start_date TIMESTAMPTZ DEFAULT NULL::TIMESTAMPTZ,
    p_end_date TIMESTAMPTZ DEFAULT NULL::TIMESTAMPTZ,
    p_team_id UUID DEFAULT NULL::UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_is_platform_admin BOOLEAN := public.is_platform_admin(v_caller_id);
    v_staff_team_id UUID := public.current_staff_team_id();
    v_team_id UUID;
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

    IF v_is_platform_admin THEN
        v_team_id := p_team_id;
    ELSE
        IF v_staff_team_id IS NULL THEN
            RAISE EXCEPTION 'Club admin must belong to an active team.' USING ERRCODE = '42501';
        END IF;
        IF p_team_id IS NOT NULL AND p_team_id != v_staff_team_id THEN
            RAISE EXCEPTION 'No tienes autorización para consultar analítica de otro equipo.' USING ERRCODE = '42501';
        END IF;
        v_team_id := v_staff_team_id;
    END IF;

    -- DAU
    SELECT COUNT(DISTINCT fan_id) INTO v_dau
    FROM public.mv_daily_fan_activity
    WHERE activity_date = (NOW() AT TIME ZONE 'America/Caracas')::date
      AND (v_team_id IS NULL OR team_id = v_team_id);

    -- WAU
    SELECT COUNT(DISTINCT fan_id) INTO v_wau
    FROM public.mv_daily_fan_activity
    WHERE activity_date >= ((NOW() - INTERVAL '7 days') AT TIME ZONE 'America/Caracas')::date
      AND (v_team_id IS NULL OR team_id = v_team_id);

    -- MAU
    SELECT COUNT(DISTINCT fan_id) INTO v_mau
    FROM public.mv_daily_fan_activity
    WHERE activity_date >= ((NOW() - INTERVAL '30 days') AT TIME ZONE 'America/Caracas')::date
      AND (v_team_id IS NULL OR team_id = v_team_id);

    -- New registrations
    SELECT COUNT(*) INTO v_new_registrations
    FROM public.profiles
    WHERE created_at >= v_start AND created_at <= v_end;

    -- Pearls issued / spent
    SELECT 
        COALESCE(SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END), 0)
    INTO v_pearls_issued, v_pearls_spent
    FROM public.ledger_entries
    WHERE created_at >= v_start AND created_at <= v_end;

    -- Redemptions breakdown
    SELECT jsonb_object_agg(COALESCE(status::text, 'unknown'), cnt)
    INTO v_redemptions_by_status
    FROM (
        SELECT status, COUNT(*) AS cnt
        FROM public.redemptions
        WHERE created_at >= v_start AND created_at <= v_end
          AND (v_team_id IS NULL OR team_id = v_team_id)
        GROUP BY status
    ) sub;

    -- Average fulfillment time
    SELECT ROUND(AVG(EXTRACT(EPOCH FROM (delivered_at - approved_at)) / 3600.0)::NUMERIC, 2)
    INTO v_avg_fulfillment_hours
    FROM public.redemptions
    WHERE delivered_at IS NOT NULL AND approved_at IS NOT NULL
      AND created_at >= v_start AND created_at <= v_end
      AND (v_team_id IS NULL OR team_id = v_team_id);

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

-- 8.2 analytics_active_users
CREATE OR REPLACE FUNCTION public.analytics_active_users(
    p_start_date TIMESTAMPTZ DEFAULT NULL::TIMESTAMPTZ,
    p_end_date TIMESTAMPTZ DEFAULT NULL::TIMESTAMPTZ,
    p_granularity TEXT DEFAULT 'day'::TEXT,
    p_team_id UUID DEFAULT NULL::UUID
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_is_platform_admin BOOLEAN := public.is_platform_admin(v_caller_id);
    v_staff_team_id UUID := public.current_staff_team_id();
    v_team_id UUID;
    v_start TIMESTAMPTZ := COALESCE(p_start_date, NOW() - INTERVAL '30 days');
    v_end TIMESTAMPTZ := COALESCE(p_end_date, NOW());
    v_gran TEXT := CASE WHEN p_granularity = 'month' THEN 'month' WHEN p_granularity = 'week' THEN 'week' ELSE 'day' END;
    v_step INTERVAL := CASE WHEN p_granularity = 'month' THEN '1 month' WHEN p_granularity = 'week' THEN '1 week' ELSE '1 day' END;
    v_result JSONB;
BEGIN
    PERFORM public.assert_admin();

    IF v_is_platform_admin THEN
        v_team_id := p_team_id;
    ELSE
        IF v_staff_team_id IS NULL THEN
            RAISE EXCEPTION 'Club admin must belong to an active team.' USING ERRCODE = '42501';
        END IF;
        IF p_team_id IS NOT NULL AND p_team_id != v_staff_team_id THEN
            RAISE EXCEPTION 'No tienes autorización para consultar analítica de otro equipo.' USING ERRCODE = '42501';
        END IF;
        v_team_id := v_staff_team_id;
    END IF;

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
          AND (v_team_id IS NULL OR team_id = v_team_id)
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

-- 8.3 analytics_products
CREATE OR REPLACE FUNCTION public.analytics_products(
    p_start_date TIMESTAMPTZ DEFAULT NULL::TIMESTAMPTZ,
    p_end_date TIMESTAMPTZ DEFAULT NULL::TIMESTAMPTZ,
    p_team_id UUID DEFAULT NULL::UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_is_platform_admin BOOLEAN := public.is_platform_admin(v_caller_id);
    v_staff_team_id UUID := public.current_staff_team_id();
    v_team_id UUID;
    v_start TIMESTAMPTZ := COALESCE(p_start_date, NOW() - INTERVAL '30 days');
    v_end TIMESTAMPTZ := COALESCE(p_end_date, NOW());
    v_top_products JSONB;
    v_low_stock JSONB;
BEGIN
    PERFORM public.assert_admin();

    IF v_is_platform_admin THEN
        v_team_id := p_team_id;
    ELSE
        IF v_staff_team_id IS NULL THEN
            RAISE EXCEPTION 'Club admin must belong to an active team.' USING ERRCODE = '42501';
        END IF;
        IF p_team_id IS NOT NULL AND p_team_id != v_staff_team_id THEN
            RAISE EXCEPTION 'No tienes autorización para consultar analítica de otro equipo.' USING ERRCODE = '42501';
        END IF;
        v_team_id := v_staff_team_id;
    END IF;

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
        WHERE (v_team_id IS NULL OR p.team_id = v_team_id)
        GROUP BY p.id, p.name, p.cost_pearls
    ) sub;

    SELECT jsonb_agg(
        jsonb_build_object(
            'product_id', id,
            'name', name,
            'stock', stock,
            'active', active
        ) ORDER BY stock ASC
    ) INTO v_low_stock
    FROM public.products
    WHERE stock <= 3 AND active = true
      AND (v_team_id IS NULL OR team_id = v_team_id);

    RETURN jsonb_build_object(
        'top_products', COALESCE(v_top_products, '[]'::jsonb),
        'low_stock_alerts', COALESCE(v_low_stock, '[]'::jsonb)
    );
END;
$function$;

-- 8.4 analytics_trivias
CREATE OR REPLACE FUNCTION public.analytics_trivias(
    p_start_date TIMESTAMPTZ DEFAULT NULL::TIMESTAMPTZ,
    p_end_date TIMESTAMPTZ DEFAULT NULL::TIMESTAMPTZ,
    p_team_id UUID DEFAULT NULL::UUID
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_is_platform_admin BOOLEAN := public.is_platform_admin(v_caller_id);
    v_staff_team_id UUID := public.current_staff_team_id();
    v_team_id UUID;
    v_start TIMESTAMPTZ := COALESCE(p_start_date, NOW() - INTERVAL '30 days');
    v_end TIMESTAMPTZ := COALESCE(p_end_date, NOW());
    v_popular JSONB;
    v_hardest_questions JSONB;
BEGIN
    PERFORM public.assert_admin();

    IF v_is_platform_admin THEN
        v_team_id := p_team_id;
    ELSE
        IF v_staff_team_id IS NULL THEN
            RAISE EXCEPTION 'Club admin must belong to an active team.' USING ERRCODE = '42501';
        END IF;
        IF p_team_id IS NOT NULL AND p_team_id != v_staff_team_id THEN
            RAISE EXCEPTION 'No tienes autorización para consultar analítica de otro equipo.' USING ERRCODE = '42501';
        END IF;
        v_team_id := v_staff_team_id;
    END IF;

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
        WHERE (v_team_id IS NULL OR t.team_id = v_team_id)
        GROUP BY t.id, t.title
    ) sub;

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
          AND (v_team_id IS NULL OR t.team_id = v_team_id)
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

-- 8.5 analytics_funnel
CREATE OR REPLACE FUNCTION public.analytics_funnel(
    p_start_date TIMESTAMPTZ DEFAULT NULL::TIMESTAMPTZ,
    p_end_date TIMESTAMPTZ DEFAULT NULL::TIMESTAMPTZ,
    p_team_id UUID DEFAULT NULL::UUID
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_is_platform_admin BOOLEAN := public.is_platform_admin(v_caller_id);
    v_staff_team_id UUID := public.current_staff_team_id();
    v_team_id UUID;
    v_start TIMESTAMPTZ := COALESCE(p_start_date, NOW() - INTERVAL '30 days');
    v_end TIMESTAMPTZ := COALESCE(p_end_date, NOW());
    v_total_registered INT := 0;
    v_email_verified INT := 0;
    v_first_trivia INT := 0;
    v_first_redemption INT := 0;
BEGIN
    PERFORM public.assert_admin();

    IF v_is_platform_admin THEN
        v_team_id := p_team_id;
    ELSE
        IF v_staff_team_id IS NULL THEN
            RAISE EXCEPTION 'Club admin must belong to an active team.' USING ERRCODE = '42501';
        END IF;
        IF p_team_id IS NOT NULL AND p_team_id != v_staff_team_id THEN
            RAISE EXCEPTION 'No tienes autorización para consultar analítica de otro equipo.' USING ERRCODE = '42501';
        END IF;
        v_team_id := v_staff_team_id;
    END IF;

    SELECT COUNT(*) INTO v_total_registered
    FROM public.profiles
    WHERE created_at >= v_start AND created_at <= v_end;

    SELECT COUNT(p.id) INTO v_email_verified
    FROM public.profiles p
    JOIN auth.users u ON u.id = p.id
    WHERE p.created_at >= v_start AND p.created_at <= v_end
      AND (u.email_confirmed_at IS NOT NULL OR u.confirmed_at IS NOT NULL);

    SELECT COUNT(DISTINCT p.id) INTO v_first_trivia
    FROM public.profiles p
    JOIN public.trivia_attempts ta ON ta.fan_id = p.id AND ta.submitted_at IS NOT NULL
    WHERE p.created_at >= v_start AND p.created_at <= v_end
      AND (v_team_id IS NULL OR ta.team_id = v_team_id);

    SELECT COUNT(DISTINCT p.id) INTO v_first_redemption
    FROM public.profiles p
    JOIN public.redemptions r ON r.fan_id = p.id
    WHERE p.created_at >= v_start AND p.created_at <= v_end
      AND (v_team_id IS NULL OR r.team_id = v_team_id);

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

-- 8.6 analytics_engagement_hours
CREATE OR REPLACE FUNCTION public.analytics_engagement_hours(
    p_start_date TIMESTAMPTZ DEFAULT NULL::TIMESTAMPTZ,
    p_end_date TIMESTAMPTZ DEFAULT NULL::TIMESTAMPTZ,
    p_team_id UUID DEFAULT NULL::UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_is_platform_admin BOOLEAN := public.is_platform_admin(v_caller_id);
    v_staff_team_id UUID := public.current_staff_team_id();
    v_team_id UUID;
    v_start TIMESTAMPTZ := COALESCE(p_start_date, NOW() - INTERVAL '30 days');
    v_end TIMESTAMPTZ := COALESCE(p_end_date, NOW());
    v_result JSONB;
BEGIN
    PERFORM public.assert_admin();

    IF v_is_platform_admin THEN
        v_team_id := p_team_id;
    ELSE
        IF v_staff_team_id IS NULL THEN
            RAISE EXCEPTION 'Club admin must belong to an active team.' USING ERRCODE = '42501';
        END IF;
        IF p_team_id IS NOT NULL AND p_team_id != v_staff_team_id THEN
            RAISE EXCEPTION 'No tienes autorización para consultar analítica de otro equipo.' USING ERRCODE = '42501';
        END IF;
        v_team_id := v_staff_team_id;
    END IF;

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
          AND (v_team_id IS NULL OR team_id = v_team_id)
        GROUP BY 1, 2
        ORDER BY 1, 2
    ) sub;

    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$function$;

-- 8.7 analytics_top_fans
CREATE OR REPLACE FUNCTION public.analytics_top_fans(
    p_limit INTEGER DEFAULT 10,
    p_start_date TIMESTAMPTZ DEFAULT NULL::TIMESTAMPTZ,
    p_end_date TIMESTAMPTZ DEFAULT NULL::TIMESTAMPTZ,
    p_team_id UUID DEFAULT NULL::UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_is_platform_admin BOOLEAN := public.is_platform_admin(v_caller_id);
    v_staff_team_id UUID := public.current_staff_team_id();
    v_team_id UUID;
    v_start TIMESTAMPTZ := COALESCE(p_start_date, NOW() - INTERVAL '30 days');
    v_end TIMESTAMPTZ := COALESCE(p_end_date, NOW());
    v_result JSONB;
BEGIN
    PERFORM public.assert_admin();

    IF v_is_platform_admin THEN
        v_team_id := p_team_id;
    ELSE
        IF v_staff_team_id IS NULL THEN
            RAISE EXCEPTION 'Club admin must belong to an active team.' USING ERRCODE = '42501';
        END IF;
        IF p_team_id IS NOT NULL AND p_team_id != v_staff_team_id THEN
            RAISE EXCEPTION 'No tienes autorización para consultar analítica de otro equipo.' USING ERRCODE = '42501';
        END IF;
        v_team_id := v_staff_team_id;
    END IF;

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
          AND (v_team_id IS NULL OR ta.team_id = v_team_id)
        GROUP BY p.id, p.display_name, p.avatar_url
        ORDER BY pearls_earned DESC
        LIMIT LEAST(GREATEST(p_limit, 1), 100)
    ) sub;

    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$function$;

-- 8.8 audit_search (scoped to team for club admin)
CREATE OR REPLACE FUNCTION public.audit_search(
    p_actor_id UUID DEFAULT NULL::UUID,
    p_action TEXT DEFAULT NULL::TEXT,
    p_entity TEXT DEFAULT NULL::TEXT,
    p_from TIMESTAMPTZ DEFAULT NULL::TIMESTAMPTZ,
    p_to TIMESTAMPTZ DEFAULT NULL::TIMESTAMPTZ,
    p_limit INTEGER DEFAULT 50,
    p_cursor UUID DEFAULT NULL::UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_is_platform_admin BOOLEAN := public.is_platform_admin(v_caller_id);
    v_staff_team_id UUID := public.current_staff_team_id();
    v_res JSONB;
BEGIN
    PERFORM public.assert_admin();

    IF NOT v_is_platform_admin AND v_staff_team_id IS NULL THEN
        RAISE EXCEPTION 'Club admin must belong to an active team.' USING ERRCODE = '42501';
    END IF;

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
            AND (
                v_is_platform_admin
                OR a.actor_id IN (SELECT user_id FROM public.staff_members WHERE team_id = v_staff_team_id)
                OR a.after->>'team_id' = v_staff_team_id::text
            )
        ORDER BY a.created_at DESC
        LIMIT LEAST(GREATEST(p_limit, 1), 100)
    ) sub;

    RETURN v_res;
END;
$function$;

-- ----------------------------------------------------------------------------
-- 9. Grants & Permissions (Rule 1 compliance)
-- ----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.approve_redemption(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.approve_redemption(UUID, TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.verify_redemption_code(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.verify_redemption_code(TEXT, TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.check_in_redemption(UUID, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_in_redemption(UUID, TEXT, TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.deliver_redemption(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.deliver_redemption(TEXT, TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.reject_redemption(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reject_redemption(UUID, TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.report_redemption_issue(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.report_redemption_issue(UUID, TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_resolve_redemption_issue(UUID, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_resolve_redemption_issue(UUID, TEXT, TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.staff_redemption_queue(TEXT, TEXT, TIMESTAMPTZ, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.staff_redemption_queue(TEXT, TEXT, TIMESTAMPTZ, INTEGER) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.staff_search_fans(TEXT, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.staff_search_fans(TEXT, INTEGER) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_upsert_product(JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_upsert_product(JSONB) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.staff_upsert_product(JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.staff_upsert_product(JSONB) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_upsert_trivia(JSONB, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_upsert_trivia(JSONB, JSONB) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.staff_upsert_trivia(JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.staff_upsert_trivia(JSONB) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_publish_trivia(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_publish_trivia(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_archive_trivia(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_archive_trivia(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_duplicate_trivia(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_duplicate_trivia(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_upsert_game(JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_upsert_game(JSONB) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_delete_game(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_delete_game(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_upsert_player(JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_upsert_player(JSONB) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_delete_player(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_delete_player(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.segment_count(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.segment_count(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.segment_members(UUID, INTEGER, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.segment_members(UUID, INTEGER, UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_upsert_segment(JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_upsert_segment(JSONB) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_delete_guess_player_challenge(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_delete_guess_player_challenge(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_delete_trivia_poll(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_delete_trivia_poll(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_resolve_trivia_poll(UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_resolve_trivia_poll(UUID, UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_resolve_over_under(UUID, NUMERIC) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_resolve_over_under(UUID, NUMERIC) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_resolve_score_prediction(UUID, INT, INT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_resolve_score_prediction(UUID, INT, INT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.activate_landing_cta(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.activate_landing_cta(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_delete_login_modal_slide(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_delete_login_modal_slide(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_update_notification_template(TEXT, TEXT, TEXT, BOOLEAN) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_notification_template(TEXT, TEXT, TEXT, BOOLEAN) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.update_birthday_settings(BOOLEAN, TEXT, TEXT, TEXT, INTEGER, INTEGER, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_birthday_settings(BOOLEAN, TEXT, TEXT, TEXT, INTEGER, INTEGER, INTEGER) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_suspend_fan(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_suspend_fan(UUID, TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_reactivate_fan(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_reactivate_fan(UUID, TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_update_economy_settings(INTEGER, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_economy_settings(INTEGER, INTEGER) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_update_ads_settings(INTEGER, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_ads_settings(INTEGER, INTEGER) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.import_ad_report(DATE, INTEGER, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.import_ad_report(DATE, INTEGER, TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.analytics_overview(TIMESTAMPTZ, TIMESTAMPTZ, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.analytics_overview(TIMESTAMPTZ, TIMESTAMPTZ, UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.analytics_active_users(TIMESTAMPTZ, TIMESTAMPTZ, TEXT, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.analytics_active_users(TIMESTAMPTZ, TIMESTAMPTZ, TEXT, UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.analytics_products(TIMESTAMPTZ, TIMESTAMPTZ, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.analytics_products(TIMESTAMPTZ, TIMESTAMPTZ, UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.analytics_trivias(TIMESTAMPTZ, TIMESTAMPTZ, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.analytics_trivias(TIMESTAMPTZ, TIMESTAMPTZ, UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.analytics_funnel(TIMESTAMPTZ, TIMESTAMPTZ, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.analytics_funnel(TIMESTAMPTZ, TIMESTAMPTZ, UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.analytics_engagement_hours(TIMESTAMPTZ, TIMESTAMPTZ, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.analytics_engagement_hours(TIMESTAMPTZ, TIMESTAMPTZ, UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.analytics_top_fans(INTEGER, TIMESTAMPTZ, TIMESTAMPTZ, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.analytics_top_fans(INTEGER, TIMESTAMPTZ, TIMESTAMPTZ, UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.audit_search(UUID, TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, INTEGER, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.audit_search(UUID, TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, INTEGER, UUID) TO authenticated, service_role;
