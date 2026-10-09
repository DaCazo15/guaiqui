-- Migration: 20261008000010_fase7_wallet_and_redemptions.sql
-- Description: Fase 7 - Billetera, Tienda de Canje y Ciclo de Vida de Redenciones con Códigos QR HMAC

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- 1. Helper: Generación Criptográfica de Códigos Base32 Opacos (12 caracteres con dígito verificador)
CREATE OR REPLACE FUNCTION public.generate_redemption_code(p_redemption_id UUID)
RETURNS TEXT AS $$
DECLARE
    v_secret TEXT := 'guaiqueries_secret_key_2026';
    v_raw BYTEA;
    v_alphabet TEXT := '0123456789ABCDEFGHJKMNPQRSTVWXYZ'; -- Crockford Base32
    v_val BIGINT := 0;
    v_code TEXT := '';
    v_i INT;
    v_sum INT := 0;
    v_check CHAR;
BEGIN
    IF p_redemption_id IS NULL THEN
        RAISE EXCEPTION 'Redemption ID required.';
    END IF;

    -- HMAC-SHA256 del UUID del canje usando strings
    v_raw := extensions.hmac(p_redemption_id::text, v_secret, 'sha256');

    -- Extraer los primeros 7 bytes (56 bits) para derivar 11 dígitos base32
    FOR v_i IN 1..7 LOOP
        v_val := (v_val * 256) + get_byte(v_raw, v_i - 1);
    END LOOP;

    FOR v_i IN 1..11 LOOP
        v_code := substr(v_alphabet, (v_val % 32)::int + 1, 1) || v_code;
        v_val := v_val / 32;
    END LOOP;

    -- Dígito verificador ponderado mod 32
    FOR v_i IN 1..11 LOOP
        v_sum := v_sum + (position(substr(v_code, v_i, 1) in v_alphabet) - 1) * v_i;
    END LOOP;
    v_check := substr(v_alphabet, (v_sum % 32) + 1, 1);

    RETURN v_code || v_check;
END;
$$ LANGUAGE plpgsql IMMUTABLE SECURITY DEFINER SET search_path = public, extensions, pg_temp;

-- 2. Helper: Computar Hash de Código QR
CREATE OR REPLACE FUNCTION public.compute_redemption_code_hash(p_code_or_hash TEXT)
RETURNS TEXT AS $$
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
$$ LANGUAGE plpgsql IMMUTABLE SECURITY DEFINER SET search_path = public, extensions, pg_temp;

-- 3. RPC: get_redemption_qr (Solo para fanático propietario, estado approved o scheduled, no expirado)
CREATE OR REPLACE FUNCTION public.get_redemption_qr(p_redemption_id UUID)
RETURNS JSONB AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

-- 4. RPC: redeem_product (Transacción atómica con bloqueo FOR UPDATE, congelación de costo e idempotencia)
CREATE OR REPLACE FUNCTION public.redeem_product(
    p_product_id UUID,
    p_variant TEXT,
    p_idempotency_key TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_fan_id UUID := auth.uid();
    v_product products%ROWTYPE;
    v_wallet wallets%ROWTYPE;
    v_existing_redemption redemptions%ROWTYPE;
    v_redemption_id UUID;
    v_code TEXT;
    v_code_hash TEXT;
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    IF p_idempotency_key IS NULL OR trim(p_idempotency_key) = '' THEN
        RAISE EXCEPTION 'Idempotency key is required.';
    END IF;

    -- 1. Check Idempotencia exacta para este usuario
    SELECT * INTO v_existing_redemption 
    FROM redemptions 
    WHERE fan_id = v_fan_id AND idempotency_key = p_idempotency_key;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'redemption_id', v_existing_redemption.id,
            'status', v_existing_redemption.status,
            'cost_pearls', v_existing_redemption.cost_pearls,
            'variant', v_existing_redemption.variant,
            'reused', true
        );
    END IF;

    -- 2. Bloqueo FOR UPDATE en billetera del fan
    SELECT * INTO v_wallet FROM wallets WHERE fan_id = v_fan_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'INSUFFICIENT_PERLITAS: Billetera no inicializada.';
    END IF;

    -- 3. Bloqueo FOR UPDATE en producto
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

    IF v_wallet.balance_cache < v_product.cost_pearls THEN
        RAISE EXCEPTION 'INSUFFICIENT_PERLITAS: Saldo insuficiente (Requerido: %, Disponible: %).', v_product.cost_pearls, v_wallet.balance_cache;
    END IF;

    -- 4. Generar ID y Hash determinista
    v_redemption_id := gen_random_uuid();
    v_code := generate_redemption_code(v_redemption_id);
    v_code_hash := compute_redemption_code_hash(v_code);

    -- 5. Transacción atómica:
    -- A) Descontar stock
    UPDATE products SET stock = stock - 1 WHERE id = p_product_id;

    -- B) Insertar entrada de egreso en el libro inmutable
    INSERT INTO ledger_entries (
        fan_id, amount, type, status, source_type, source_id, note
    ) VALUES (
        v_fan_id, -v_product.cost_pearls, 'redemption', 'confirmed', 'redemption', v_redemption_id::text,
        'Canje de premio: ' || v_product.name
    );

    -- C) Actualizar saldo en caché de billetera
    UPDATE wallets 
    SET balance_cache = balance_cache - v_product.cost_pearls, updated_at = NOW() 
    WHERE fan_id = v_fan_id;

    -- D) Crear registro de canje con costo congelado
    INSERT INTO redemptions (
        id, fan_id, product_id, variant, cost_pearls, status, code_hash, idempotency_key, expires_at, created_at
    ) VALUES (
        v_redemption_id, v_fan_id, p_product_id, p_variant, v_product.cost_pearls, 'pending', v_code_hash, p_idempotency_key, NOW() + INTERVAL '30 days', NOW()
    );

    -- E) Registrar en auditoría de historial
    INSERT INTO redemption_history (redemption_id, previous_status, new_status, changed_by, note)
    VALUES (v_redemption_id, NULL, 'pending', v_fan_id, 'Canje iniciado por el fanático');

    RETURN jsonb_build_object(
        'redemption_id', v_redemption_id,
        'status', 'pending',
        'cost_pearls', v_product.cost_pearls,
        'variant', p_variant,
        'reused', false
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

-- 5. RPC: cancel_redemption (Fanático solo puede cancelar estado pending; reembolso atómico)
CREATE OR REPLACE FUNCTION public.cancel_redemption(
    p_redemption_id UUID,
    p_reason TEXT DEFAULT 'Cancelado por el usuario'
)
RETURNS JSONB AS $$
DECLARE
    v_actor_id UUID := auth.uid();
    v_redemption redemptions%ROWTYPE;
    v_is_owner BOOLEAN;
BEGIN
    IF v_actor_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    -- Bloqueo FOR UPDATE
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

    -- Actualizar estado
    UPDATE redemptions SET status = 'cancelled' WHERE id = v_redemption.id;

    -- Registrar reembolso positivo en ledger
    INSERT INTO ledger_entries (
        fan_id, amount, type, status, source_type, source_id, note, created_by
    ) VALUES (
        v_redemption.fan_id, v_redemption.cost_pearls, 'refund', 'confirmed',
        'redemption', v_redemption.id::text,
        'Reembolso por cancelación de canje: ' || COALESCE(p_reason, 'Sin motivo'),
        v_actor_id
    );

    -- Restaurar saldo en caché de billetera
    UPDATE wallets
    SET balance_cache = balance_cache + v_redemption.cost_pearls, updated_at = NOW()
    WHERE fan_id = v_redemption.fan_id;

    -- Restaurar stock del producto exactamente 1 vez
    UPDATE products SET stock = stock + 1 WHERE id = v_redemption.product_id;

    -- Historial
    INSERT INTO redemption_history (redemption_id, previous_status, new_status, changed_by, note)
    VALUES (v_redemption.id, v_redemption.status, 'cancelled', v_actor_id, COALESCE(p_reason, 'Cancelado'));

    -- Auditoría
    INSERT INTO audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        v_actor_id, 'cancel_redemption', 'redemptions', v_redemption.id::text,
        jsonb_build_object('status', v_redemption.status, 'cost_pearls', v_redemption.cost_pearls),
        jsonb_build_object('status', 'cancelled', 'reason', p_reason, 'refunded_pearls', v_redemption.cost_pearls)
    );

    RETURN jsonb_build_object(
        'redemption_id', v_redemption.id,
        'status', 'cancelled',
        'refunded_pearls', v_redemption.cost_pearls
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

-- 6. RPC: approve_redemption (Staff/Admin pasa de pending -> approved)
CREATE OR REPLACE FUNCTION public.approve_redemption(
    p_redemption_id UUID,
    p_note TEXT DEFAULT 'Canje aprobado por staff'
)
RETURNS JSONB AS $$
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

    RETURN jsonb_build_object(
        'redemption_id', v_redemption.id,
        'status', 'approved',
        'approved_by', v_staff_id,
        'approved_at', NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

-- 7. RPC: verify_redemption_code (Búsqueda por código o hash)
DROP FUNCTION IF EXISTS public.verify_redemption_code(TEXT);
CREATE OR REPLACE FUNCTION public.verify_redemption_code(p_code_or_hash TEXT)
RETURNS JSONB AS $$
DECLARE
    v_staff_id UUID := auth.uid();
    v_hash TEXT := compute_redemption_code_hash(p_code_or_hash);
    v_res JSONB;
BEGIN
    IF NOT is_staff_or_admin(v_staff_id) THEN
        RAISE EXCEPTION 'Staff or Admin authorization required.';
    END IF;

    SELECT jsonb_build_object(
        'redemption_id', r.id,
        'status', r.status,
        'cost_pearls', r.cost_pearls,
        'variant', r.variant,
        'created_at', r.created_at,
        'expires_at', r.expires_at,
        'delivered_at', r.delivered_at,
        'fan_name', p.display_name,
        'product_name', pr.name,
        'product_category', pr.category
    ) INTO v_res
    FROM redemptions r
    JOIN profiles p ON p.id = r.fan_id
    JOIN products pr ON pr.id = r.product_id
    WHERE r.code_hash = v_hash;

    IF v_res IS NULL THEN
        RAISE EXCEPTION 'Redemption code not found or invalid.';
    END IF;

    RETURN v_res;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

-- 8. RPC: deliver_redemption (Entrega con validación de código o hash)
DROP FUNCTION IF EXISTS public.deliver_redemption(TEXT, TEXT);
CREATE OR REPLACE FUNCTION public.deliver_redemption(
    p_code_or_hash TEXT,
    p_device TEXT DEFAULT 'Scanner Terminal'
)
RETURNS JSONB AS $$
DECLARE
    v_staff_id UUID := auth.uid();
    v_hash TEXT := compute_redemption_code_hash(p_code_or_hash);
    v_redemption redemptions%ROWTYPE;
BEGIN
    IF NOT is_staff_or_admin(v_staff_id) THEN
        RAISE EXCEPTION 'Staff or Admin role required.';
    END IF;

    SELECT * INTO v_redemption FROM redemptions WHERE code_hash = v_hash FOR UPDATE;
    IF NOT FOUND THEN
        INSERT INTO scan_events (staff_id, code_hash, result, device) VALUES (v_staff_id, COALESCE(v_hash, 'unknown'), 'invalid', p_device);
        RAISE EXCEPTION 'Invalid redemption QR code.';
    END IF;

    IF v_redemption.status IN ('delivered', 'completed') THEN
        INSERT INTO scan_events (staff_id, code_hash, result, device) VALUES (v_staff_id, v_hash, 'already_delivered', p_device);
        RAISE EXCEPTION 'Redemption code has ALREADY been delivered on %', v_redemption.delivered_at;
    END IF;

    IF v_redemption.status = 'expired' OR (v_redemption.expires_at IS NOT NULL AND NOW() > v_redemption.expires_at) THEN
        INSERT INTO scan_events (staff_id, code_hash, result, device) VALUES (v_staff_id, v_hash, 'expired', p_device);
        RAISE EXCEPTION 'Redemption code has expired.';
    END IF;

    UPDATE redemptions
    SET status = 'delivered',
        delivered_by = v_staff_id,
        delivered_at = NOW()
    WHERE id = v_redemption.id AND status IN ('pending', 'approved', 'scheduled');

    INSERT INTO scan_events (staff_id, code_hash, result, device) 
    VALUES (v_staff_id, v_hash, 'success', p_device);

    INSERT INTO redemption_history (redemption_id, previous_status, new_status, changed_by, note)
    VALUES (v_redemption.id, v_redemption.status, 'delivered', v_staff_id, 'Premio entregado satisfactoriamente');

    RETURN jsonb_build_object(
        'redemption_id', v_redemption.id,
        'status', 'delivered',
        'delivered_at', NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

-- 9. RPC: wallet_summary (Saldo, ganadas/gastadas mes, en revisión)
CREATE OR REPLACE FUNCTION public.wallet_summary()
RETURNS JSONB AS $$
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

    -- Perlitas retenidas o en revisión
    SELECT COALESCE(SUM(amount), 0) INTO v_held_pearls
    FROM ledger_entries
    WHERE fan_id = v_fan_id
      AND status = 'held';

    RETURN jsonb_build_object(
        'balance', v_balance,
        'earned_month', v_earned_month,
        'spent_month', v_spent_month,
        'held_pearls', v_held_pearls
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

-- 10. RPC: wallet_ledger (Historial paginado por cursor con descripción legible)
CREATE OR REPLACE FUNCTION public.wallet_ledger(
    p_type TEXT DEFAULT NULL,
    p_cursor TIMESTAMPTZ DEFAULT NULL,
    p_limit INT DEFAULT 20
)
RETURNS JSONB AS $$
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
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

-- 11. RPC: confirm_test_user_email (Solo para ambiente de testing/CI)
CREATE OR REPLACE FUNCTION public.confirm_test_user_email(p_email TEXT)
RETURNS VOID AS $$
BEGIN
    UPDATE auth.users SET email_confirmed_at = NOW() WHERE email = p_email;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 12. RPC: reconcile_wallets (Solo service_role o admin)
CREATE OR REPLACE FUNCTION public.reconcile_wallets()
RETURNS TABLE (
    fan_id UUID,
    balance_cache INT,
    computed_balance INT,
    difference INT
) AS $$
DECLARE
    v_actor_id UUID := auth.uid();
BEGIN
    -- Permitir service_role (auth.uid() IS NULL con rol backend) o admin autenticado
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 12. Actualizar RLS en redemption_history para que los fanáticos puedan leer su propio historial
DROP POLICY IF EXISTS "Fan reads own redemption history" ON redemption_history;
CREATE POLICY "Fan reads own redemption history"
ON redemption_history FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM redemptions r 
        WHERE r.id = redemption_history.redemption_id 
          AND r.fan_id = auth.uid()
    ) 
    OR is_staff_or_admin(auth.uid())
);

-- 13. Permisos y Revocaciones Granulares
REVOKE ALL ON FUNCTION public.generate_redemption_code(UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.compute_redemption_code_hash(TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_redemption_qr(UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.redeem_product(UUID, TEXT, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.cancel_redemption(UUID, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.approve_redemption(UUID, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.verify_redemption_code(TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.deliver_redemption(TEXT, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.wallet_summary() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.wallet_ledger(TEXT, TIMESTAMPTZ, INT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.reconcile_wallets() FROM PUBLIC, anon, authenticated;

-- Grants a roles correspondientes
GRANT EXECUTE ON FUNCTION public.get_redemption_qr(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.redeem_product(UUID, TEXT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.cancel_redemption(UUID, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.approve_redemption(UUID, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.verify_redemption_code(TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.deliver_redemption(TEXT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.wallet_summary() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.wallet_ledger(TEXT, TIMESTAMPTZ, INT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.reconcile_wallets() TO service_role;
