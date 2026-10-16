-- Migration: 20261010000029_staff_and_scanner_repairs.sql
-- Description: Allows deliver_redemption for scheduled status, creates staff_upsert_product and staff_upsert_trivia with assert_staff(), and cleans emojis from default birthday_settings.

-- 1. Redefine deliver_redemption (ID-based) to accept status IN ('approved', 'scheduled')
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.deliver_redemption(UUID, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.deliver_redemption(UUID, TEXT, TEXT) TO authenticated, service_role;


-- 2. Redefine deliver_redemption (Code-based overload) to accept status IN ('approved', 'scheduled')
CREATE OR REPLACE FUNCTION public.deliver_redemption(
    p_code TEXT,
    p_note TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.deliver_redemption(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.deliver_redemption(TEXT, TEXT) TO authenticated, service_role;


-- 3. Create RPC staff_upsert_product for Staff Inventory Management
CREATE OR REPLACE FUNCTION public.staff_upsert_product(
    p_product JSONB
)
RETURNS JSONB AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.staff_upsert_product(JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.staff_upsert_product(JSONB) TO authenticated, service_role;


-- 4. Create RPC staff_upsert_trivia for Staff Trivia View
CREATE OR REPLACE FUNCTION public.staff_upsert_trivia(
    p_trivia JSONB
)
RETURNS JSONB AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.staff_upsert_trivia(JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.staff_upsert_trivia(JSONB) TO authenticated, service_role;


-- 5. Clean emoji in birthday_settings default message
UPDATE public.birthday_settings
SET message = '¡En nombre de todos los que formamos parte de los **Guaiqueríes de Margarita**, te deseamos un feliz cumpleaños, {nombre}!\n\nGracias por tu pasión y por ser parte fundamental de nuestra tribu.'
WHERE id = 1 AND message LIKE '%🏀%';
