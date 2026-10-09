-- Migration: 20261007000004_additional_rpc_functions.sql
-- Description: Additional transactional RPC functions for redemption lifecycle

-- 1. Cancel Redemption (Fan or Staff can cancel pending; refunds pearls)
CREATE OR REPLACE FUNCTION cancel_redemption(
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

    -- Lock redemption FOR UPDATE
    SELECT * INTO v_redemption FROM redemptions WHERE id = p_redemption_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Redemption not found.';
    END IF;

    v_is_owner := (v_redemption.fan_id = v_actor_id);

    -- Fan can only cancel pending redemptions; staff/admin can cancel pending/approved/scheduled
    IF v_is_owner THEN
        IF v_redemption.status != 'pending' THEN
            RAISE EXCEPTION 'Only pending redemptions can be cancelled by the fan. Current status: %', v_redemption.status;
        END IF;
    ELSE
        IF NOT is_staff_or_admin(v_actor_id) THEN
            RAISE EXCEPTION 'You do not have permission to cancel this redemption.';
        END IF;
        IF v_redemption.status IN ('delivered', 'completed', 'cancelled', 'rejected') THEN
            RAISE EXCEPTION 'Cannot cancel a redemption in status %', v_redemption.status;
        END IF;
    END IF;

    -- Update redemption status
    UPDATE redemptions SET status = 'cancelled' WHERE id = v_redemption.id;

    -- Insert POSITIVE refund entry into ledger (immutable ledger pattern)
    INSERT INTO ledger_entries (
        fan_id, amount, type, status, source_type, source_id, note, created_by
    ) VALUES (
        v_redemption.fan_id, v_redemption.cost_pearls, 'refund', 'confirmed',
        'redemption', v_redemption.id::text,
        'Reembolso por cancelación: ' || COALESCE(p_reason, 'Sin motivo'),
        v_actor_id
    );

    -- Restore wallet balance
    UPDATE wallets
    SET balance_cache = balance_cache + v_redemption.cost_pearls, updated_at = NOW()
    WHERE fan_id = v_redemption.fan_id;

    -- Restore product stock
    UPDATE products SET stock = stock + 1 WHERE id = v_redemption.product_id;

    -- History log
    INSERT INTO redemption_history (redemption_id, previous_status, new_status, changed_by, note)
    VALUES (v_redemption.id, v_redemption.status, 'cancelled', v_actor_id, COALESCE(p_reason, 'Cancelado'));

    -- Audit log
    INSERT INTO audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        v_actor_id, 'cancel_redemption', 'redemptions', v_redemption.id::text,
        jsonb_build_object('status', v_redemption.status),
        jsonb_build_object('status', 'cancelled', 'reason', p_reason)
    );

    RETURN jsonb_build_object(
        'redemption_id', v_redemption.id,
        'status', 'cancelled',
        'refunded_pearls', v_redemption.cost_pearls
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 2. Approve Redemption (Staff/Admin transitions pending → approved)
CREATE OR REPLACE FUNCTION approve_redemption(
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

    -- Lock redemption FOR UPDATE
    SELECT * INTO v_redemption FROM redemptions WHERE id = p_redemption_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Redemption not found.';
    END IF;

    IF v_redemption.status != 'pending' THEN
        RAISE EXCEPTION 'Only pending redemptions can be approved. Current status: %', v_redemption.status;
    END IF;

    -- Transition to approved
    UPDATE redemptions
    SET status = 'approved',
        approved_by = v_staff_id,
        approved_at = NOW()
    WHERE id = v_redemption.id;

    -- History log
    INSERT INTO redemption_history (redemption_id, previous_status, new_status, changed_by, note)
    VALUES (v_redemption.id, 'pending', 'approved', v_staff_id, COALESCE(p_note, 'Aprobado'));

    RETURN jsonb_build_object(
        'redemption_id', v_redemption.id,
        'status', 'approved',
        'approved_by', v_staff_id,
        'approved_at', NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 3. Report Redemption Issue (Staff flags a delivered redemption with a problem)
CREATE OR REPLACE FUNCTION report_redemption_issue(
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;
