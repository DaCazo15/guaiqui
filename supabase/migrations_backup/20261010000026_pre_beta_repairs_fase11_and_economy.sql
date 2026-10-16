-- Migration: 20261010000026_pre_beta_repairs_fase11_and_economy.sql
-- Description: Repairs redeem_product HMAC alignment, restores delete_my_account ledger safety, enforces economy caps & Caracas timezone, and separates home_summary read-only logic.

-- 1. Helper Function: Read-Only Streak Info for home_summary (Caracas Timezone)
CREATE OR REPLACE FUNCTION public.get_streak_info(p_fan_id UUID)
RETURNS JSONB AS $$
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
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.get_streak_info(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_streak_info(UUID) TO authenticated, service_role;


-- 2. Update home_summary RPC to use read-only get_streak_info
CREATE OR REPLACE FUNCTION public.home_summary()
RETURNS JSONB AS $$
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

    -- Active Trivia
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
            WHERE ta.fan_id = v_uid AND ta.trivia_id = t.id AND ta.submitted_at IS NOT NULL
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
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.home_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.home_summary() TO authenticated, service_role;


-- 3. Update calculate_and_apply_streak_bonus (Caracas Timezone & Dynamic Config from economy_settings)
CREATE OR REPLACE FUNCTION public.calculate_and_apply_streak_bonus(p_fan_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_today DATE := (NOW() AT TIME ZONE 'America/Caracas')::date;
    v_already_awarded BOOLEAN;
    v_streak_days INT := 0;
    v_day_check DATE;
    v_bonus_amount INT := 0;
    v_streak_config JSONB;
    v_bonus_7 INT := 300;
    v_bonus_3 INT := 100;
    v_bonus_1 INT := 20;
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

    -- Read dynamic milestone thresholds from economy_settings
    SELECT streak_bonus_config INTO v_streak_config
    FROM public.economy_settings
    ORDER BY created_at DESC LIMIT 1;

    IF v_streak_config IS NOT NULL THEN
        v_bonus_7 := COALESCE((v_streak_config->>'streak_7_days')::int, (v_streak_config->>'7_days')::int, 300);
        v_bonus_3 := COALESCE((v_streak_config->>'streak_3_days')::int, (v_streak_config->>'3_days')::int, 100);
        v_bonus_1 := COALESCE((v_streak_config->>'streak_1_day')::int, (v_streak_config->>'1_day')::int, 20);
    END IF;

    -- Award milestone bonus
    IF v_streak_days >= 7 THEN
        v_bonus_amount := v_bonus_7;
    ELSIF v_streak_days >= 3 THEN
        v_bonus_amount := v_bonus_3;
    ELSIF v_streak_days >= 1 THEN
        v_bonus_amount := v_bonus_1;
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.calculate_and_apply_streak_bonus(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.calculate_and_apply_streak_bonus(UUID) TO authenticated, service_role;


-- 4. Update submit_trivia_attempt (Economy Caps in Caracas Timezone + Rate Limit + Risk Retention)
CREATE OR REPLACE FUNCTION public.submit_trivia_attempt(
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
    v_raw_pearls INT := 0;
    v_final_pearls INT := 0;
    v_per_correct_pearls INT;
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

    -- Server-side grading
    FOR v_q IN SELECT q.id, q.points FROM trivia_questions q WHERE q.trivia_id = v_trivia.id LOOP
        v_chosen_option_id := (p_answers->>(v_q.id::text))::uuid;
        IF v_chosen_option_id IS NOT NULL THEN
            SELECT is_correct INTO v_is_correct 
            FROM trivia_options 
            WHERE id = v_chosen_option_id AND question_id = v_q.id;

            IF v_is_correct IS TRUE THEN
                v_score := v_score + v_q.points;
                v_raw_pearls := v_raw_pearls + v_per_correct_pearls;
            END IF;
        END IF;
    END LOOP;

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
            'Premio por trivia: ' || v_trivia.title
        );

        IF v_entry_status = 'confirmed' THEN
            INSERT INTO wallets (fan_id, balance_cache)
            VALUES (v_fan_id, v_final_pearls)
            ON CONFLICT (fan_id) 
            DO UPDATE SET balance_cache = wallets.balance_cache + v_final_pearls, updated_at = NOW();
        END IF;
    END IF;

    UPDATE trivia_attempts
    SET submitted_at = NOW(),
        answers = p_answers,
        score = v_score,
        pearls_awarded = v_final_pearls,
        suspicious = v_is_suspicious
    WHERE id = v_attempt.id;

    -- Update streak bonus if confirmed
    IF v_entry_status = 'confirmed' THEN
        PERFORM public.calculate_and_apply_streak_bonus(v_fan_id);
    END IF;

    RETURN jsonb_build_object(
        'attempt_id', v_attempt.id,
        'score', v_score,
        'pearls_awarded', v_final_pearls,
        'raw_pearls', v_raw_pearls,
        'suspicious', v_is_suspicious,
        'status', v_entry_status,
        'already_submitted', false
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.submit_trivia_attempt(UUID, JSONB, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_trivia_attempt(UUID, JSONB, TEXT) TO authenticated, service_role;


-- 5. Update redeem_product (Fase 7 HMAC QR generation + Fase 11 Rate Limit & Dynamic Friction)
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.redeem_product(UUID, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.redeem_product(UUID, TEXT, TEXT) TO authenticated, service_role;


-- 6. Update delete_my_account (Restores Fase 5 Anonymization & Preserves Ledger/Wallets + Anti-Fraud Blocks)
CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS JSONB AS $$
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

    -- Idempotent check
    IF v_status = 'deleted' THEN
        RETURN jsonb_build_object(
            'success', true,
            'message', 'La cuenta ya ha sido eliminada previamente.',
            'already_deleted', true
        );
    END IF;

    -- Block if suspended
    IF v_status = 'suspended' THEN
        RAISE EXCEPTION 'Cuentas suspendidas no pueden ser eliminadas directamente.';
    END IF;

    -- Block if unresolved risk flags
    SELECT COUNT(*) INTO v_unresolved_flags FROM risk_flags WHERE fan_id = v_uid AND resolved = false;
    IF v_unresolved_flags > 0 THEN
        RAISE EXCEPTION 'Existen verificaciones pendientes en tu cuenta. Contáctate con soporte.';
    END IF;

    -- Block if pending redemptions exist
    SELECT COUNT(*) INTO v_pending_redemptions
    FROM public.redemptions
    WHERE fan_id = v_uid AND status IN ('pending', 'approved', 'scheduled');

    IF v_pending_redemptions > 0 THEN
        RAISE EXCEPTION 'No puedes eliminar tu cuenta mientras tengas % canje(s) en proceso o pendiente(s) de entrega. Por favor completa o cancela tus canjes primero.', v_pending_redemptions;
    END IF;

    -- Block if held pearls exist
    SELECT COUNT(*) INTO v_held_entries
    FROM public.ledger_entries
    WHERE fan_id = v_uid AND status = 'held';

    IF v_held_entries > 0 THEN
        RAISE EXCEPTION 'No puedes eliminar tu cuenta mientras tengas perlitas retenidas bajo revisión de soporte.';
    END IF;

    -- Anonymize profile (Preserves wallet and immutable ledger entries)
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

    -- Audit log
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.delete_my_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated, service_role;
