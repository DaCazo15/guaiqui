-- Migration: 20261007000002_functions_and_rpc.sql
-- Description: Transactional Security Definer RPC Functions for Economy, Trivias, and Redemptions

-- Helper: Check if current user is admin
CREATE OR REPLACE FUNCTION is_admin(user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM staff_members 
        WHERE staff_members.user_id = is_admin.user_id 
          AND role = 'admin' 
          AND active = true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- Helper: Check if current user is staff or admin
CREATE OR REPLACE FUNCTION is_staff_or_admin(user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM staff_members 
        WHERE staff_members.user_id = is_staff_or_admin.user_id 
          AND active = true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 1. Start Trivia Attempt
CREATE OR REPLACE FUNCTION start_trivia_attempt(
    p_trivia_id UUID,
    p_idempotency_key TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_fan_id UUID := auth.uid();
    v_trivia trivias%ROWTYPE;
    v_attempt_count INT;
    v_existing_attempt trivia_attempts%ROWTYPE;
    v_attempt_id UUID;
    v_expires_at TIMESTAMPTZ;
    v_seed INT;
    v_questions JSONB;
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    -- Fetch trivia
    SELECT * INTO v_trivia FROM trivias WHERE id = p_trivia_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Trivia not found.';
    END IF;

    IF v_trivia.status != 'published' THEN
        RAISE EXCEPTION 'Trivia is not active for participation.';
    END IF;

    IF NOW() < v_trivia.starts_at OR NOW() > v_trivia.ends_at THEN
        RAISE EXCEPTION 'Trivia time window is closed.';
    END IF;

    -- Check Idempotency
    SELECT * INTO v_existing_attempt 
    FROM trivia_attempts 
    WHERE fan_id = v_fan_id AND trivia_id = p_trivia_id AND idempotency_key = p_idempotency_key;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'attempt_id', v_existing_attempt.id,
            'started_at', v_existing_attempt.started_at,
            'expires_at', v_existing_attempt.expires_at,
            'seed', v_existing_attempt.seed,
            'reused', true
        );
    END IF;

    -- Check Max Attempts
    SELECT COUNT(*) INTO v_attempt_count 
    FROM trivia_attempts 
    WHERE fan_id = v_fan_id AND trivia_id = p_trivia_id;

    IF v_attempt_count >= v_trivia.max_attempts THEN
        RAISE EXCEPTION 'Maximum participation attempts reached for this trivia.';
    END IF;

    -- Create Attempt
    v_expires_at := NOW() + (v_trivia.time_limit_seconds || ' seconds')::interval;
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
        )
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 2. Submit Trivia Attempt (SERVER-SIDE GRADING & ATOMIC PAYOUT)
CREATE OR REPLACE FUNCTION submit_trivia_attempt(
    p_attempt_id UUID,
    p_answers JSONB,
    p_idempotency_key TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_fan_id UUID := auth.uid();
    v_attempt trivia_attempts%ROWTYPE;
    v_trivia trivias%ROWTYPE;
    v_time_spent_seconds NUMERIC;
    v_is_suspicious BOOLEAN := false;
    v_score INT := 0;
    v_total_pearls INT := 0;
    v_per_correct_pearls INT;
    v_q RECORD;
    v_chosen_option_id UUID;
    v_is_correct BOOLEAN;
    v_entry_status ledger_status := 'confirmed';
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    -- Lock attempt
    SELECT * INTO v_attempt FROM trivia_attempts WHERE id = p_attempt_id AND fan_id = v_fan_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Trivia attempt not found.';
    END IF;

    IF v_attempt.submitted_at IS NOT NULL THEN
        -- Already submitted (idempotent response)
        RETURN jsonb_build_object(
            'attempt_id', v_attempt.id,
            'score', v_attempt.score,
            'pearls_awarded', v_attempt.pearls_awarded,
            'suspicious', v_attempt.suspicious,
            'already_submitted', true
        );
    END IF;

    SELECT * INTO v_trivia FROM trivias WHERE id = v_attempt.trivia_id;

    -- Calculate timing
    v_time_spent_seconds := EXTRACT(EPOCH FROM (NOW() - v_attempt.started_at));

    -- Anti-cheat check: Implausible completion speed (< 3 seconds for entire trivia)
    IF v_time_spent_seconds < 3.0 THEN
        v_is_suspicious := true;
        v_entry_status := 'held';
        
        INSERT INTO risk_flags (fan_id, reason, severity)
        VALUES (v_fan_id, 'Implausible trivia completion speed (' || round(v_time_spent_seconds, 2) || 's)', 'high');
    END IF;

    v_per_correct_pearls := COALESCE((v_trivia.reward_rules->>'per_correct_pearls')::int, 50);

    -- Server-side grading of each question
    FOR v_q IN SELECT q.id, q.points FROM trivia_questions q WHERE q.trivia_id = v_trivia.id LOOP
        v_chosen_option_id := (p_answers->>(v_q.id::text))::uuid;
        
        IF v_chosen_option_id IS NOT NULL THEN
            SELECT is_correct INTO v_is_correct 
            FROM trivia_options 
            WHERE id = v_chosen_option_id AND question_id = v_q.id;

            IF v_is_correct IS TRUE THEN
                v_score := v_score + v_q.points;
                v_total_pearls := v_total_pearls + v_per_correct_pearls;
            END IF;
        END IF;
    END LOOP;

    -- Atomic Transaction: Insert into Ledger + Update Wallet
    IF v_total_pearls > 0 THEN
        INSERT INTO ledger_entries (
            fan_id, amount, type, status, source_type, source_id, note
        ) VALUES (
            v_fan_id, v_total_pearls, 'trivia_reward', v_entry_status, 'trivia_attempt', v_attempt.id::text,
            'Premio por trivia: ' || v_trivia.title
        );

        -- Update balance cache if confirmed
        IF v_entry_status = 'confirmed' THEN
            INSERT INTO wallets (fan_id, balance_cache)
            VALUES (v_fan_id, v_total_pearls)
            ON CONFLICT (fan_id) 
            DO UPDATE SET balance_cache = wallets.balance_cache + v_total_pearls, updated_at = NOW();
        END IF;
    END IF;

    -- Update attempt record
    UPDATE trivia_attempts
    SET submitted_at = NOW(),
        answers = p_answers,
        score = v_score,
        pearls_awarded = v_total_pearls,
        suspicious = v_is_suspicious
    WHERE id = v_attempt.id;

    RETURN jsonb_build_object(
        'attempt_id', v_attempt.id,
        'score', v_score,
        'pearls_awarded', v_total_pearls,
        'suspicious', v_is_suspicious,
        'already_submitted', false
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 3. Redeem Product (ATOMIC ROW-LOCKING TRANSACTION)
CREATE OR REPLACE FUNCTION redeem_product(
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
    v_code_hash TEXT;
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    -- Check Idempotency
    SELECT * INTO v_existing_redemption 
    FROM redemptions 
    WHERE fan_id = v_fan_id AND idempotency_key = p_idempotency_key;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'redemption_id', v_existing_redemption.id,
            'code_hash', v_existing_redemption.code_hash,
            'status', v_existing_redemption.status,
            'cost_pearls', v_existing_redemption.cost_pearls,
            'reused', true
        );
    END IF;

    -- Lock wallet FOR UPDATE
    SELECT * INTO v_wallet FROM wallets WHERE fan_id = v_fan_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Wallet not initialized or insufficient balance.';
    END IF;

    -- Lock product FOR UPDATE
    SELECT * INTO v_product FROM products WHERE id = p_product_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product not found.';
    END IF;

    IF NOT v_product.active THEN
        RAISE EXCEPTION 'Product is not currently available.';
    END IF;

    IF v_product.stock <= 0 THEN
        RAISE EXCEPTION 'Product is out of stock.';
    END IF;

    IF v_wallet.balance_cache < v_product.cost_pearls THEN
        RAISE EXCEPTION 'Insufficient perlitas balance. Required: %, Available: %', v_product.cost_pearls, v_wallet.balance_cache;
    END IF;

    -- Generate unique QR Code Hash
    v_code_hash := encode(extensions.gen_random_bytes(16), 'hex');

    -- Atomic Actions:
    -- 1. Deduct Stock
    UPDATE products SET stock = stock - 1 WHERE id = p_product_id;

    -- 2. Insert Negative Ledger Entry
    INSERT INTO ledger_entries (
        fan_id, amount, type, status, source_type, source_id, note
    ) VALUES (
        v_fan_id, -v_product.cost_pearls, 'redemption', 'confirmed', 'product', p_product_id::text,
        'Canje de premio: ' || v_product.name
    );

    -- 3. Update Wallet Balance Cache
    UPDATE wallets 
    SET balance_cache = balance_cache - v_product.cost_pearls, updated_at = NOW() 
    WHERE fan_id = v_fan_id;

    -- 4. Create Redemption Record
    INSERT INTO redemptions (
        fan_id, product_id, variant, cost_pearls, status, code_hash, idempotency_key, expires_at
    ) VALUES (
        v_fan_id, p_product_id, p_variant, v_product.cost_pearls, 'pending', v_code_hash, p_idempotency_key, NOW() + INTERVAL '30 days'
    )
    RETURNING id INTO v_redemption_id;

    -- 5. Audit History
    INSERT INTO redemption_history (redemption_id, previous_status, new_status, changed_by, note)
    VALUES (v_redemption_id, NULL, 'pending', v_fan_id, 'Canje iniciado por el fanático');

    RETURN jsonb_build_object(
        'redemption_id', v_redemption_id,
        'code_hash', v_code_hash,
        'status', 'pending',
        'cost_pearls', v_product.cost_pearls,
        'reused', false
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 4. Deliver Redemption (CONDITIONAL UPDATE PREVENTING DOUBLE DELIVERY)
CREATE OR REPLACE FUNCTION deliver_redemption(
    p_code_hash TEXT,
    p_device TEXT DEFAULT 'Scanner Terminal'
)
RETURNS JSONB AS $$
DECLARE
    v_staff_id UUID := auth.uid();
    v_redemption redemptions%ROWTYPE;
BEGIN
    IF NOT is_staff_or_admin(v_staff_id) THEN
        RAISE EXCEPTION 'Staff or Admin role required.';
    END IF;

    -- Lock Redemption FOR UPDATE
    SELECT * INTO v_redemption FROM redemptions WHERE code_hash = p_code_hash FOR UPDATE;
    IF NOT FOUND THEN
        INSERT INTO scan_events (staff_id, code_hash, result, device) VALUES (v_staff_id, p_code_hash, 'invalid', p_device);
        RAISE EXCEPTION 'Invalid redemption QR code.';
    END IF;

    IF v_redemption.status IN ('delivered', 'completed') THEN
        INSERT INTO scan_events (staff_id, code_hash, result, device) VALUES (v_staff_id, p_code_hash, 'already_delivered', p_device);
        RAISE EXCEPTION 'Redemption code has ALREADY been delivered on %', v_redemption.delivered_at;
    END IF;

    IF v_redemption.status = 'expired' OR (v_redemption.expires_at IS NOT NULL AND NOW() > v_redemption.expires_at) THEN
        INSERT INTO scan_events (staff_id, code_hash, result, device) VALUES (v_staff_id, p_code_hash, 'expired', p_device);
        RAISE EXCEPTION 'Redemption code has expired.';
    END IF;

    -- Atomic Conditional Update
    UPDATE redemptions
    SET status = 'delivered',
        delivered_by = v_staff_id,
        delivered_at = NOW()
    WHERE id = v_redemption.id AND status IN ('pending', 'approved', 'scheduled');

    INSERT INTO scan_events (staff_id, code_hash, result, device) 
    VALUES (v_staff_id, p_code_hash, 'success', p_device);

    INSERT INTO redemption_history (redemption_id, previous_status, new_status, changed_by, note)
    VALUES (v_redemption.id, v_redemption.status, 'delivered', v_staff_id, 'Premio entregado satisfactoriamente por escaneo');

    RETURN jsonb_build_object(
        'redemption_id', v_redemption.id,
        'status', 'delivered',
        'delivered_at', NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 5. Reject / Cancel Redemption (POSITIVE REFUND ENTRY IN LEDGER)
CREATE OR REPLACE FUNCTION reject_redemption(
    p_redemption_id UUID,
    p_reason TEXT
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

    IF v_redemption.status IN ('delivered', 'completed', 'rejected', 'cancelled') THEN
        RAISE EXCEPTION 'Cannot reject a redemption in status %', v_redemption.status;
    END IF;

    -- Update Redemption Status
    UPDATE redemptions 
    SET status = 'rejected' 
    WHERE id = v_redemption.id;

    -- Insert Refund Entry into Ledger (POSITIVE ENTRY)
    INSERT INTO ledger_entries (
        fan_id, amount, type, status, source_type, source_id, note
    ) VALUES (
        v_redemption.fan_id, v_redemption.cost_pearls, 'refund', 'confirmed', 'redemption', v_redemption.id::text,
        'Reembolso por canje rechazado: ' || p_reason
    );

    -- Update Wallet
    UPDATE wallets 
    SET balance_cache = balance_cache + v_redemption.cost_pearls, updated_at = NOW()
    WHERE fan_id = v_redemption.fan_id;

    -- Restore Product Stock
    UPDATE products 
    SET stock = stock + 1 
    WHERE id = v_redemption.product_id;

    -- History
    INSERT INTO redemption_history (redemption_id, previous_status, new_status, changed_by, note)
    VALUES (v_redemption.id, v_redemption.status, 'rejected', v_staff_id, p_reason);

    RETURN jsonb_build_object('redemption_id', v_redemption.id, 'status', 'rejected', 'refunded_pearls', v_redemption.cost_pearls);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 6. Verify Redemption Code Card (READ ONLY FOR STAFF)
CREATE OR REPLACE FUNCTION verify_redemption_code(p_code_hash TEXT)
RETURNS JSONB AS $$
DECLARE
    v_res JSONB;
BEGIN
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
    WHERE r.code_hash = p_code_hash;

    IF v_res IS NULL THEN
        RAISE EXCEPTION 'Redemption code not found.';
    END IF;

    RETURN v_res;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 7. Admin Adjust Pearls (AUDIT LOG + MANDATORY REASON)
CREATE OR REPLACE FUNCTION admin_adjust_pearls(
    p_fan_id UUID,
    p_amount INT,
    p_reason TEXT
)
RETURNS JSONB AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;
