-- Migration: 20261008000011_fase8_staff_panel.sql
-- Fase 8: Panel de Staff (Escáner, Cola de Canjes, Incidencias, Inventario, Fans)

-- 0. Adicionar columna delivery_idempotency_key si no existe
ALTER TABLE public.redemptions ADD COLUMN IF NOT EXISTS delivery_idempotency_key TEXT;

-- 0.1 Helper: Validar Crockford Base32 + dígito verificador ponderado mod 32
CREATE OR REPLACE FUNCTION public.validate_crockford_base32_checksum(p_code TEXT)
RETURNS BOOLEAN AS $$
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
$$ LANGUAGE plpgsql IMMUTABLE SECURITY DEFINER SET search_path = public, extensions, pg_temp;

-- 1. Helper assert_staff()
CREATE OR REPLACE FUNCTION public.assert_staff()
RETURNS BOOLEAN AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_active BOOLEAN;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Usuario no autenticado' USING ERRCODE = '42501';
    END IF;

    SELECT active INTO v_active
    FROM public.staff_members
    WHERE user_id = v_uid;

    IF v_active IS NOT TRUE THEN
        RAISE EXCEPTION 'Staff or Admin authorization required.';
    END IF;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

-- 2. verify_redemption_code
DROP FUNCTION IF EXISTS public.verify_redemption_code(TEXT);
DROP FUNCTION IF EXISTS public.verify_redemption_code(TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.verify_redemption_code(
    p_code TEXT,
    p_device TEXT DEFAULT 'Scanner Terminal'
)
RETURNS JSONB AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

-- 3. deliver_redemption (Entrega idempotente)
DROP FUNCTION IF EXISTS public.deliver_redemption(UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.deliver_redemption(TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.deliver_redemption(
    p_redemption_id UUID,
    p_idempotency_key TEXT,
    p_note TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_staff_id UUID := auth.uid();
    v_redemption public.redemptions%ROWTYPE;
    v_deliv_name TEXT;
BEGIN
    PERFORM assert_staff();

    IF p_idempotency_key IS NULL OR trim(p_idempotency_key) = '' THEN
        RAISE EXCEPTION 'Idempotency key is required for delivery.';
    END IF;

    -- Bloqueo FOR UPDATE para atomicidad estricta
    SELECT * INTO v_redemption
    FROM public.redemptions
    WHERE id = p_redemption_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Canje no encontrado.';
    END IF;

    -- Si la misma llave de idempotencia ya entregó este canje, responder ALREADY_DELIVERED idempotentemente
    IF v_redemption.status IN ('delivered', 'completed') OR v_redemption.delivery_idempotency_key = p_idempotency_key THEN
        SELECT display_name INTO v_deliv_name FROM public.profiles WHERE id = v_redemption.delivered_by;
        RETURN jsonb_build_object(
            'result', 'ALREADY_DELIVERED',
            'status', v_redemption.status,
            'delivered_at', v_redemption.delivered_at,
            'delivered_by_name', COALESCE(v_deliv_name, 'Personal de Staff')
        );
    END IF;

    IF v_redemption.status != 'approved' THEN
        RAISE EXCEPTION 'Solo se pueden entregar canjes en estado "approved". Estado actual: %', v_redemption.status;
    END IF;

    -- UPDATE condicional atómico
    UPDATE public.redemptions
    SET status = 'delivered',
        delivered_by = v_staff_id,
        delivered_at = NOW(),
        delivery_idempotency_key = p_idempotency_key
    WHERE id = v_redemption.id AND status = 'approved';

    -- Registrar historial y auditoría
    INSERT INTO public.redemption_history (redemption_id, previous_status, new_status, changed_by, note)
    VALUES (v_redemption.id, v_redemption.status, 'delivered', v_staff_id, COALESCE(p_note, 'Premio entregado al fanático'));

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        v_staff_id,
        'deliver_redemption',
        'redemptions',
        v_redemption.id::text,
        jsonb_build_object('status', v_redemption.status),
        jsonb_build_object('status', 'delivered', 'idempotency_key', p_idempotency_key, 'note', p_note)
    );

    SELECT display_name INTO v_deliv_name FROM public.profiles WHERE id = v_staff_id;

    RETURN jsonb_build_object(
        'result', 'SUCCESS',
        'status', 'delivered',
        'delivered_at', NOW(),
        'delivered_by_name', v_deliv_name
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

-- 4. check_in_redemption (Registro de asistencia a experiencias)
CREATE OR REPLACE FUNCTION public.check_in_redemption(
    p_redemption_id UUID,
    p_idempotency_key TEXT,
    p_note TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

-- 5. staff_redemption_queue (Cola paginada, pendientes más antiguos primero)
-- Importante: NUNCA devuelve code ni code_hash
CREATE OR REPLACE FUNCTION public.staff_redemption_queue(
    p_status TEXT DEFAULT NULL,
    p_search TEXT DEFAULT NULL,
    p_cursor TIMESTAMPTZ DEFAULT NULL,
    p_limit INT DEFAULT 20
)
RETURNS TABLE (
    id UUID,
    status redemption_status,
    variant TEXT,
    cost_pearls INT,
    created_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    fan_id UUID,
    fan_display_name TEXT,
    fan_avatar_url TEXT,
    product_id UUID,
    product_name TEXT,
    product_category product_category
) AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

-- 6. reject_redemption con reembolso de perlitas obligatorio
CREATE OR REPLACE FUNCTION public.reject_redemption(
    p_redemption_id UUID,
    p_reason TEXT
)
RETURNS JSONB AS $$
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

    -- Actualizar estado a rejected
    UPDATE public.redemptions
    SET status = 'rejected'
    WHERE id = v_redemption.id;

    -- Reembolsar perlitas exactamente una vez si no se ha reembolsado previamente
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

    RETURN jsonb_build_object(
        'redemption_id', v_redemption.id,
        'status', 'rejected',
        'refunded_pearls', v_redemption.cost_pearls
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

-- 7. report_redemption_issue
CREATE OR REPLACE FUNCTION public.report_redemption_issue(
    p_redemption_id UUID,
    p_reason TEXT,
    p_note TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
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
    VALUES (
        v_redemption.id,
        v_redemption.status,
        'issue',
        v_staff_id,
        'Incidencia: ' || p_reason || COALESCE(' - ' || p_note, '')
    );

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        v_staff_id,
        'report_redemption_issue',
        'redemptions',
        v_redemption.id::text,
        jsonb_build_object('status', v_redemption.status),
        jsonb_build_object('status', 'issue', 'reason', p_reason, 'note', p_note)
    );

    RETURN jsonb_build_object(
        'redemption_id', v_redemption.id,
        'status', 'issue',
        'reason', p_reason
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

-- 8. adjust_stock (Ajuste manual de inventario)
CREATE OR REPLACE FUNCTION public.adjust_stock(
    p_product_id UUID,
    p_delta INT,
    p_reason TEXT
)
RETURNS JSONB AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

-- 9. staff_search_fans (Búsqueda y consulta de fanáticos por personal)
-- Privado: NUNCA devuelve correo, fecha nacimiento, género ni metadatos de segmentación
CREATE OR REPLACE FUNCTION public.staff_search_fans(
    p_query TEXT,
    p_limit INT DEFAULT 20
)
RETURNS TABLE (
    id UUID,
    display_name TEXT,
    avatar_url TEXT,
    status TEXT,
    pearl_balance INT,
    last_5_redemptions JSONB
) AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

-- 10. Permisos de Ejecución y Revocaciones Estrictas
REVOKE ALL ON FUNCTION public.confirm_test_user_email(TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.validate_crockford_base32_checksum(TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.assert_staff() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.verify_redemption_code(TEXT, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.deliver_redemption(UUID, TEXT, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.check_in_redemption(UUID, TEXT, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.staff_redemption_queue(TEXT, TEXT, TIMESTAMPTZ, INT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.reject_redemption(UUID, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.report_redemption_issue(UUID, TEXT, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.adjust_stock(UUID, INT, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.staff_search_fans(TEXT, INT) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.validate_crockford_base32_checksum(TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.compute_redemption_code_hash(TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.assert_staff() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.verify_redemption_code(TEXT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.deliver_redemption(UUID, TEXT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.check_in_redemption(UUID, TEXT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.staff_redemption_queue(TEXT, TEXT, TIMESTAMPTZ, INT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.reject_redemption(UUID, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.report_redemption_issue(UUID, TEXT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.adjust_stock(UUID, INT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.staff_search_fans(TEXT, INT) TO authenticated, service_role;
