-- ============================================================================
-- Migration: 20261023000002_optimize_postgres_performance_and_security.sql
-- Description: Comprehensive database optimization and security hardening based on
--              Postgres Best Practices:
--              1. Security: Hide trivia_options.is_correct from anon and authenticated.
--              2. Security: Lock down purge_auth_identities to service_role with assert_admin.
--              3. Security: Revoke anon execution on role check RPCs (is_admin, is_staff_or_admin).
--              4. Security: Enforce assert_active_verified_fan in redeem_product, submit_trivia_attempt, cancel_redemption.
--              5. Security: Fix search_path on mutable functions and drop test-only procedures.
--              6. Performance: Add 21 missing foreign key covering indexes.
--              7. Performance: Optimize RLS policies using scalar (SELECT auth.uid()) subqueries.
--              8. Schema: Enforce non-zero constraint on ledger_entries.amount.
--              9. Seeds: Purge hardcoded standings seed data.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. SECURITY: Column-Level Protection on trivia_options (Prevent Answer Leak)
-- ----------------------------------------------------------------------------
REVOKE SELECT ON public.trivia_options FROM anon, authenticated, public;
GRANT SELECT (id, question_id, option_text) ON public.trivia_options TO anon, authenticated;
GRANT ALL ON public.trivia_options TO service_role;

-- ----------------------------------------------------------------------------
-- 2. SECURITY: Hardening purge_auth_identities
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.purge_auth_identities(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
    v_deleted_count INT := 0;
BEGIN
    -- Strict Admin verification
    PERFORM public.assert_admin();

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

REVOKE ALL ON FUNCTION public.purge_auth_identities(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.purge_auth_identities(uuid) TO service_role;

-- ----------------------------------------------------------------------------
-- 3. SECURITY: Revoke anon execution on administrative role inspection RPCs
-- ----------------------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION public.is_admin(uuid) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.is_staff_or_admin(uuid) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.is_admin_check() FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.assert_min_admins() FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.check_max_5_published_login_modal_slides() FROM anon, PUBLIC;

GRANT EXECUTE ON FUNCTION public.is_admin(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_staff_or_admin(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_admin_check() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.assert_min_admins() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.check_max_5_published_login_modal_slides() TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 4. SECURITY: Enforce assert_active_verified_fan in core transactional RPCs
-- ----------------------------------------------------------------------------

-- A) redeem_product
CREATE OR REPLACE FUNCTION public.redeem_product(p_product_id uuid, p_variant text, p_idempotency_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_fan_id UUID;
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
    -- Verify active, un-suspended fan
    v_fan_id := public.assert_active_verified_fan();

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
    UPDATE products SET stock = stock - 1 WHERE id = p_product_id;

    INSERT INTO ledger_entries (
        fan_id, amount, type, status, source_type, source_id, note
    ) VALUES (
        v_fan_id, -v_product.cost_pearls, 'redemption', 'confirmed', 'redemption', v_redemption_id::text,
        'Canje de premio: ' || v_product.name
    );

    UPDATE wallets 
    SET balance_cache = balance_cache - v_product.cost_pearls, updated_at = NOW() 
    WHERE fan_id = v_fan_id;

    INSERT INTO redemptions (
        id, fan_id, product_id, variant, cost_pearls, status, code_hash, idempotency_key, expires_at, created_at
    ) VALUES (
        v_redemption_id, v_fan_id, p_product_id, p_variant, v_product.cost_pearls, 'pending', v_code_hash, p_idempotency_key, NOW() + INTERVAL '30 days', NOW()
    );

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

-- B) submit_trivia_attempt
CREATE OR REPLACE FUNCTION public.submit_trivia_attempt(p_attempt_id uuid, p_answers jsonb, p_idempotency_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_fan_id UUID;
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
    -- Verify active, un-suspended fan
    v_fan_id := public.assert_active_verified_fan();

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

    -- Trivia is won ONLY if all questions are answered correctly
    v_is_won := (v_total_questions > 0 AND v_correct_count = v_total_questions);

    IF v_is_won THEN
        v_raw_pearls := v_raw_pearls + v_perfect_bonus;

        SELECT daily_pearl_cap, weekly_pearl_cap 
        INTO v_daily_cap, v_weekly_cap
        FROM public.economy_settings
        ORDER BY created_at DESC LIMIT 1;

        v_daily_cap := COALESCE(v_daily_cap, 1000);
        v_weekly_cap := COALESCE(v_weekly_cap, 5000);

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

        v_final_pearls := LEAST(v_raw_pearls, v_effective_cap);

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

        IF v_entry_status = 'confirmed' THEN
            PERFORM public.calculate_and_apply_streak_bonus(v_fan_id);
        END IF;
    ELSE
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

-- C) cancel_redemption
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
        PERFORM public.assert_active_verified_fan(v_actor_id);
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

-- ----------------------------------------------------------------------------
-- 5. SECURITY: Search path fixes and cleanup of test procedures
-- ----------------------------------------------------------------------------
ALTER FUNCTION public.prevent_ledger_mutation() SET search_path = 'public', 'pg_temp';
ALTER FUNCTION public.prevent_audit_log_mutation() SET search_path = 'public', 'pg_temp';
ALTER FUNCTION public.parse_instagram_shortcode(text) SET search_path = 'public', 'pg_temp';

DROP FUNCTION IF EXISTS public.seed_analytics_performance_data(integer, integer);
DROP FUNCTION IF EXISTS public.clean_test_records();

-- ----------------------------------------------------------------------------
-- 6. PERFORMANCE: Covering Indexes on Foreign Keys (unindexed_foreign_keys)
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_fk_profiles_favorite_player ON public.profiles(favorite_player_id);
CREATE INDEX IF NOT EXISTS idx_fk_ledger_entries_created_by ON public.ledger_entries(created_by);
CREATE INDEX IF NOT EXISTS idx_fk_ledger_hold_resolutions_resolved_by ON public.ledger_hold_resolutions(resolved_by);
CREATE INDEX IF NOT EXISTS idx_fk_redemptions_product_id ON public.redemptions(product_id);
CREATE INDEX IF NOT EXISTS idx_fk_redemptions_approved_by ON public.redemptions(approved_by);
CREATE INDEX IF NOT EXISTS idx_fk_redemptions_delivered_by ON public.redemptions(delivered_by);
CREATE INDEX IF NOT EXISTS idx_fk_redemption_history_redemption_id ON public.redemption_history(redemption_id);
CREATE INDEX IF NOT EXISTS idx_fk_redemption_history_changed_by ON public.redemption_history(changed_by);
CREATE INDEX IF NOT EXISTS idx_fk_trivia_attempts_trivia_id ON public.trivia_attempts(trivia_id);
CREATE INDEX IF NOT EXISTS idx_fk_trivia_questions_trivia_id ON public.trivia_questions(trivia_id);
CREATE INDEX IF NOT EXISTS idx_fk_trivia_options_question_id ON public.trivia_options(question_id);
CREATE INDEX IF NOT EXISTS idx_fk_trivias_target_segment_id ON public.trivias(target_segment_id);
CREATE INDEX IF NOT EXISTS idx_fk_risk_flags_fan_id ON public.risk_flags(fan_id);
CREATE INDEX IF NOT EXISTS idx_fk_audit_log_actor_id ON public.audit_log(actor_id);
CREATE INDEX IF NOT EXISTS idx_fk_scan_events_staff_id ON public.scan_events(staff_id);
CREATE INDEX IF NOT EXISTS idx_fk_system_alerts_resolved_by ON public.system_alerts(resolved_by);
CREATE INDEX IF NOT EXISTS idx_fk_mfa_recovery_codes_user_id ON public.mfa_recovery_codes(user_id);
CREATE INDEX IF NOT EXISTS idx_fk_notification_outbox_notification_id ON public.notification_outbox(notification_id);
CREATE INDEX IF NOT EXISTS idx_fk_display_name_change_logs_user_id ON public.display_name_change_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_fk_ad_reconciliation_imported_by ON public.ad_reconciliation(imported_by);
CREATE INDEX IF NOT EXISTS idx_fk_login_modal_slides_created_by ON public.login_modal_slides(created_by);

-- ----------------------------------------------------------------------------
-- 7. PERFORMANCE: RLS InitPlan Optimization ((SELECT auth.uid()))
-- ----------------------------------------------------------------------------

-- A) profiles
DROP POLICY IF EXISTS "Fan reads own profile" ON public.profiles;
CREATE POLICY "Fan reads own profile" ON public.profiles
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = id);

DROP POLICY IF EXISTS "Fan updates own profile" ON public.profiles;
CREATE POLICY "Fan updates own profile" ON public.profiles
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = id)
  WITH CHECK ((SELECT auth.uid()) = id);

DROP POLICY IF EXISTS "Admin manages all profiles" ON public.profiles;
CREATE POLICY "Admin manages all profiles" ON public.profiles
  FOR ALL TO authenticated
  USING ((SELECT public.is_admin((SELECT auth.uid()))));

-- B) wallets
DROP POLICY IF EXISTS "Fan reads own wallet" ON public.wallets;
CREATE POLICY "Fan reads own wallet" ON public.wallets
  FOR SELECT TO authenticated
  USING (fan_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Admin manages wallets" ON public.wallets;
CREATE POLICY "Admin manages wallets" ON public.wallets
  FOR ALL TO authenticated
  USING ((SELECT public.is_admin((SELECT auth.uid()))));

-- C) ledger_entries
DROP POLICY IF EXISTS "Fan reads own ledger entries" ON public.ledger_entries;
CREATE POLICY "Fan reads own ledger entries" ON public.ledger_entries
  FOR SELECT TO authenticated
  USING (fan_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Admin manages ledger" ON public.ledger_entries;
CREATE POLICY "Admin manages ledger" ON public.ledger_entries
  FOR ALL TO authenticated
  USING ((SELECT public.is_admin((SELECT auth.uid()))));

-- D) trivia_attempts
DROP POLICY IF EXISTS "Fan reads own attempts" ON public.trivia_attempts;
CREATE POLICY "Fan reads own attempts" ON public.trivia_attempts
  FOR SELECT TO authenticated
  USING (fan_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Admin manages attempts" ON public.trivia_attempts;
CREATE POLICY "Admin manages attempts" ON public.trivia_attempts
  FOR ALL TO authenticated
  USING ((SELECT public.is_admin((SELECT auth.uid()))));

-- E) redemptions
DROP POLICY IF EXISTS "Fan reads own redemptions" ON public.redemptions;
CREATE POLICY "Fan reads own redemptions" ON public.redemptions
  FOR SELECT TO authenticated
  USING (fan_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Staff manages redemptions" ON public.redemptions;
CREATE POLICY "Staff manages redemptions" ON public.redemptions
  FOR ALL TO authenticated
  USING ((SELECT public.is_staff_or_admin((SELECT auth.uid()))));

-- F) notifications
DROP POLICY IF EXISTS "notifications_select_policy" ON public.notifications;
CREATE POLICY "notifications_select_policy" ON public.notifications
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "notifications_update_policy" ON public.notifications;
CREATE POLICY "notifications_update_policy" ON public.notifications
  FOR UPDATE TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

-- G) sponsor_videos
DROP POLICY IF EXISTS "sponsor_videos_select_active" ON public.sponsor_videos;
CREATE POLICY "sponsor_videos_select_active" ON public.sponsor_videos
  FOR SELECT TO public
  USING (is_active = true OR (EXISTS (SELECT 1 FROM public.staff_members WHERE staff_members.user_id = (SELECT auth.uid()) AND staff_members.active = true)));

DROP POLICY IF EXISTS "sponsor_videos_insert_staff" ON public.sponsor_videos;
CREATE POLICY "sponsor_videos_insert_staff" ON public.sponsor_videos
  FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.staff_members WHERE staff_members.user_id = (SELECT auth.uid()) AND staff_members.active = true));

DROP POLICY IF EXISTS "sponsor_videos_update_staff" ON public.sponsor_videos;
CREATE POLICY "sponsor_videos_update_staff" ON public.sponsor_videos
  FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.staff_members WHERE staff_members.user_id = (SELECT auth.uid()) AND staff_members.active = true))
  WITH CHECK (EXISTS (SELECT 1 FROM public.staff_members WHERE staff_members.user_id = (SELECT auth.uid()) AND staff_members.active = true));

DROP POLICY IF EXISTS "sponsor_videos_delete_staff" ON public.sponsor_videos;
CREATE POLICY "sponsor_videos_delete_staff" ON public.sponsor_videos
  FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.staff_members WHERE staff_members.user_id = (SELECT auth.uid()) AND staff_members.active = true));

-- ----------------------------------------------------------------------------
-- 8. SCHEMA: Enforce Non-Zero Check on ledger_entries
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'ledger_entries_nonzero_amount'
    ) THEN
        ALTER TABLE public.ledger_entries 
        ADD CONSTRAINT ledger_entries_nonzero_amount CHECK (amount <> 0);
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 9. SEEDS PURGE: Remove Fake / Hardcoded Standings Records
-- ----------------------------------------------------------------------------
DELETE FROM public.standings
WHERE id IN (
  '8947635b-fc5c-44c3-af02-d495cd54be61',
  'cccb7749-5ff5-4165-9732-786e1c8ee0b3',
  '34cc3886-25a4-4f4e-9c62-562ac091e38c',
  'b67d104c-b672-4fd6-93ce-ef12378bc67f',
  '9d8c31eb-65dd-4a57-947f-59789558a994'
);
