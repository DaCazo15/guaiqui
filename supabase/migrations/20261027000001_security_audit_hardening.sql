-- ============================================================================
-- Migration: 20261027000001_security_audit_hardening.sql
-- Description:
-- 1. Enforces rate limits across all fan engagement RPCs (birthday bonus, polls,
--    predictions, mystery play, flash trivia, progressive clues, who is).
-- 2. Requires a valid single-use captcha pass for high-value prize redemptions.
-- 3. Standardizes financial ledger insertions (ledger_entries, wallets.balance_cache)
--    across extended trivia RPCs to prevent schema mismatch errors.
-- 4. Ensures strict search_path, revokes public/anon access on sensitive RPCs,
--    and documents legitimate RLS helper exemptions.
-- ============================================================================

-- 1. Hardened Birthday Bonus Claim with Rate Limiting and Strict Schema
CREATE OR REPLACE FUNCTION public.claim_birthday_bonus()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_user_id UUID;
    v_profile public.profiles%ROWTYPE;
    v_card JSONB;
    v_cur_year INT;
    v_bonus INT;
    v_ref_id TEXT;
    v_entry_id UUID;
BEGIN
    v_user_id := public.assert_active_verified_fan();

    -- Rate limiting (Max 3 claim calls per 60s)
    PERFORM public.check_rate_limit(v_user_id, 'claim_birthday_bonus', 3, 60);

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
    INSERT INTO public.ledger_entries (fan_id, amount, type, status, source_type, source_id, note)
    VALUES (
        v_user_id,
        v_bonus,
        'birthday_bonus',
        'confirmed',
        'birthday_bonus',
        v_ref_id,
        'Bono de Cumpleaños ' || v_cur_year::text
    )
    RETURNING id INTO v_entry_id;

    -- Update wallet cache
    INSERT INTO public.wallets (fan_id, balance_cache)
    VALUES (v_user_id, v_bonus)
    ON CONFLICT (fan_id)
    DO UPDATE SET balance_cache = wallets.balance_cache + v_bonus, updated_at = NOW();

    RETURN jsonb_build_object('success', true, 'claimed_pearls', v_bonus);
END;
$function$;

REVOKE ALL ON FUNCTION public.claim_birthday_bonus() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_birthday_bonus() TO authenticated, service_role;


-- 2. Hardened Product Redemption: Enforces Rate Limit & Captcha Pass for High-Value Items
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
    v_pass_id UUID;

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

    -- Proportional Friction & Captcha Pass Check for High Value Products
    IF v_product.cost_pearls >= v_high_val_pearls THEN
        SELECT * INTO v_profile FROM profiles WHERE id = v_fan_id;
        v_account_age_days := EXTRACT(DAY FROM (NOW() - v_profile.created_at));

        SELECT COUNT(DISTINCT trivia_id) INTO v_trivias_completed
        FROM trivia_attempts
        WHERE fan_id = v_fan_id AND submitted_at IS NOT NULL;

        IF v_account_age_days < v_min_age_days OR v_trivias_completed < v_min_trivias THEN
            RAISE EXCEPTION 'ACCOUNT_TOO_NEW: Para canjear premios de alto valor debes tener al menos % días registrado y % trivias completadas.', v_min_age_days, v_min_trivias;
        END IF;

        -- Enforce valid, unused single-use captcha pass for high-value redemptions
        SELECT id INTO v_pass_id
        FROM public.captcha_passes
        WHERE user_id = v_fan_id AND used = false AND expires_at > NOW()
        ORDER BY created_at DESC
        LIMIT 1
        FOR UPDATE;

        IF v_pass_id IS NULL THEN
            RAISE EXCEPTION 'CAPTCHA_REQUIRED' USING ERRCODE = 'P0001';
        END IF;

        UPDATE public.captcha_passes SET used = true WHERE id = v_pass_id;
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
        v_redemption_id, v_fan_id, p_product_id, p_variant, v_product.cost_pearls, 'pending', v_code_hash, p_idempotency_key,
        NOW() + INTERVAL '30 days', NOW()
    );

    INSERT INTO redemption_history (
        redemption_id, previous_status, new_status, actor_id, actor_role, note
    ) VALUES (
        v_redemption_id, NULL, 'pending', v_fan_id, 'fan', 'Canje creado por el fanático'
    );

    RETURN jsonb_build_object(
        'redemption_id', v_redemption_id,
        'code_hash', v_code_hash,
        'qr_code', v_code,
        'status', 'pending',
        'cost_pearls', v_product.cost_pearls,
        'variant', p_variant,
        'reused', false
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.redeem_product(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.redeem_product(uuid, text, text) TO authenticated, service_role;


-- 3. Rate Limit Enforcement on Encuestas (Trivia Polls)
CREATE OR REPLACE FUNCTION public.submit_trivia_poll_vote(
    p_poll_id UUID,
    p_option_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_fan_id UUID := auth.uid();
    v_poll RECORD;
    v_option RECORD;
    v_vote_id UUID;
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Usuario no autenticado.';
    END IF;

    -- Rate limit check (5 votes per 60s)
    PERFORM public.check_rate_limit(v_fan_id, 'submit_trivia_poll_vote', 5, 60);

    -- Validate active fan status
    PERFORM public.assert_active_verified_fan(v_fan_id);

    -- Load poll
    SELECT * INTO v_poll
    FROM public.trivia_polls
    WHERE id = p_poll_id;

    IF v_poll.id IS NULL THEN
        RAISE EXCEPTION 'La encuesta no existe.';
    END IF;

    IF v_poll.status <> 'published' THEN
        RAISE EXCEPTION 'La encuesta no se encuentra disponible para votación.';
    END IF;

    IF now() < v_poll.starts_at THEN
        RAISE EXCEPTION 'Esta encuesta aún no ha iniciado.';
    END IF;

    IF now() > v_poll.closes_at THEN
        RAISE EXCEPTION 'El plazo para participar en esta encuesta ya ha cerrado.';
    END IF;

    -- Validate option belongs to poll
    SELECT * INTO v_option
    FROM public.trivia_poll_options
    WHERE id = p_option_id AND poll_id = p_poll_id;

    IF v_option.id IS NULL THEN
        RAISE EXCEPTION 'Opción no válida para esta encuesta.';
    END IF;

    -- Check single participation rule
    IF EXISTS (
        SELECT 1 FROM public.trivia_poll_votes
        WHERE poll_id = p_poll_id AND fan_id = v_fan_id
    ) THEN
        RAISE EXCEPTION 'Ya has participado en esta encuesta.';
    END IF;

    -- Record vote
    INSERT INTO public.trivia_poll_votes (
        poll_id, fan_id, option_id, is_winner, pearls_awarded
    ) VALUES (
        p_poll_id, v_fan_id, p_option_id, NULL, 0
    ) RETURNING id INTO v_vote_id;

    -- Increment votes_count on option
    UPDATE public.trivia_poll_options
    SET votes_count = votes_count + 1
    WHERE id = p_option_id;

    RETURN jsonb_build_object(
        'vote_id', v_vote_id,
        'poll_id', p_poll_id,
        'option_id', p_option_id,
        'status', 'success',
        'message', 'Voto registrado con éxito. Al finalizar el partido se distribuirán los premios.'
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.submit_trivia_poll_vote(UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_trivia_poll_vote(UUID, UUID) TO authenticated;


-- 4. Rate Limit Enforcement on ¿Quién es el Jugador?
CREATE OR REPLACE FUNCTION public.submit_guess_player_vote(
    p_challenge_id UUID,
    p_selected_player_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_fan_id UUID := auth.uid();
    v_challenge RECORD;
    v_target_player RECORD;
    v_is_correct BOOLEAN;
    v_pearls INT := 0;
    v_vote_id UUID;
    v_today_earned INT;
    v_week_earned INT;
    v_daily_cap INT := 1000;
    v_weekly_cap INT := 5000;
    v_rem_daily INT;
    v_rem_weekly INT;
    v_effective_cap INT;
    v_today_start_caracas TIMESTAMPTZ := date_trunc('day', NOW() AT TIME ZONE 'America/Caracas') AT TIME ZONE 'America/Caracas';
    v_week_start_caracas TIMESTAMPTZ := date_trunc('week', NOW() AT TIME ZONE 'America/Caracas') AT TIME ZONE 'America/Caracas';
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Usuario no autenticado.';
    END IF;

    -- Rate limit check (5 attempts per 60s)
    PERFORM public.check_rate_limit(v_fan_id, 'submit_guess_player_vote', 5, 60);

    -- Validate active fan status
    PERFORM public.assert_active_verified_fan(v_fan_id);

    -- Load challenge
    SELECT * INTO v_challenge
    FROM public.guess_player_challenges
    WHERE id = p_challenge_id;

    IF v_challenge.id IS NULL THEN
        RAISE EXCEPTION 'El reto no existe.';
    END IF;

    IF v_challenge.status <> 'published' THEN
        RAISE EXCEPTION 'Este reto no se encuentra activo.';
    END IF;

    IF now() < v_challenge.starts_at THEN
        RAISE EXCEPTION 'Este reto aún no ha iniciado.';
    END IF;

    IF now() > v_challenge.closes_at THEN
        RAISE EXCEPTION 'El plazo para participar en este reto ya ha cerrado.';
    END IF;

    -- Check single participation rule
    IF EXISTS (
        SELECT 1 FROM public.guess_player_votes
        WHERE challenge_id = p_challenge_id AND fan_id = v_fan_id
    ) THEN
        RAISE EXCEPTION 'Ya has participado en este reto.';
    END IF;

    -- Validate correct answer
    v_is_correct := (p_selected_player_id = v_challenge.target_player_id);

    IF v_is_correct AND v_challenge.reward_pearls > 0 THEN
        SELECT daily_pearl_cap, weekly_pearl_cap
        INTO v_daily_cap, v_weekly_cap
        FROM public.economy_settings
        LIMIT 1;

        SELECT COALESCE(SUM(amount), 0) INTO v_today_earned
        FROM public.ledger_entries
        WHERE fan_id = v_fan_id
          AND amount > 0
          AND status IN ('confirmed', 'held')
          AND (created_at AT TIME ZONE 'America/Caracas') >= v_today_start_caracas;

        SELECT COALESCE(SUM(amount), 0) INTO v_week_earned
        FROM public.ledger_entries
        WHERE fan_id = v_fan_id
          AND amount > 0
          AND status IN ('confirmed', 'held')
          AND (created_at AT TIME ZONE 'America/Caracas') >= v_week_start_caracas;

        v_rem_daily := GREATEST(0, COALESCE(v_daily_cap, 1000) - v_today_earned);
        v_rem_weekly := GREATEST(0, COALESCE(v_weekly_cap, 5000) - v_week_earned);
        v_effective_cap := LEAST(v_rem_daily, v_rem_weekly);

        v_pearls := LEAST(v_challenge.reward_pearls, v_effective_cap);
    END IF;

    -- Record vote
    INSERT INTO public.guess_player_votes (
        challenge_id, fan_id, selected_player_id, is_correct, pearls_awarded
    ) VALUES (
        p_challenge_id, v_fan_id, p_selected_player_id, v_is_correct, v_pearls
    ) RETURNING id INTO v_vote_id;

    -- Award pearls atomically if correct and eligible
    IF v_pearls > 0 THEN
        INSERT INTO public.ledger_entries (
            fan_id, amount, type, status, source_type, source_id, note
        ) VALUES (
            v_fan_id, v_pearls, 'trivia_reward', 'confirmed', 'guess_player', p_challenge_id::text,
            'Premio por acertar ¿Quién es?: ' || v_challenge.title
        );

        INSERT INTO public.wallets (fan_id, balance_cache)
        VALUES (v_fan_id, v_pearls)
        ON CONFLICT (fan_id)
        DO UPDATE SET balance_cache = wallets.balance_cache + v_pearls, updated_at = NOW();

        PERFORM public.calculate_and_apply_streak_bonus(v_fan_id);
    END IF;

    SELECT name, jersey_number INTO v_target_player
    FROM public.players
    WHERE id = v_challenge.target_player_id;

    RETURN jsonb_build_object(
        'vote_id', v_vote_id,
        'is_correct', v_is_correct,
        'pearls_awarded', v_pearls,
        'target_player_name', v_target_player.name,
        'target_jersey_number', v_target_player.jersey_number,
        'unblurred_photo_url', v_challenge.unblurred_photo_url,
        'status', 'success'
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.submit_guess_player_vote(UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_guess_player_vote(UUID, UUID) TO authenticated;


-- 5. Rate Limit Enforcement & Ledger Standardization on Extended Modalities (Over/Under, Mystery Play, Score Prediction, Flash Trivia, Progressive Clues)

-- 5a. Over/Under
CREATE OR REPLACE FUNCTION public.submit_over_under_vote(
    p_prediction_id UUID,
    p_choice TEXT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_fan_id UUID := auth.uid();
    v_pred RECORD;
    v_vote_id UUID;
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Usuario no autenticado.';
    END IF;

    -- Rate limiting
    PERFORM public.check_rate_limit(v_fan_id, 'submit_over_under_vote', 5, 60);

    PERFORM public.assert_active_verified_fan(v_fan_id);

    IF p_choice NOT IN ('over', 'under') THEN
        RAISE EXCEPTION 'Selección inválida. Debe ser over o under.';
    END IF;

    SELECT * INTO v_pred FROM public.over_under_predictions WHERE id = p_prediction_id;
    IF v_pred.id IS NULL THEN
        RAISE EXCEPTION 'La predicción no existe.';
    END IF;

    IF v_pred.status <> 'published' THEN
        RAISE EXCEPTION 'La predicción no está abierta.';
    END IF;

    IF now() > v_pred.closes_at THEN
        RAISE EXCEPTION 'El plazo para participar ha expirado.';
    END IF;

    IF EXISTS (SELECT 1 FROM public.over_under_votes WHERE prediction_id = p_prediction_id AND fan_id = v_fan_id) THEN
        RAISE EXCEPTION 'Ya has participado en esta predicción.';
    END IF;

    INSERT INTO public.over_under_votes (
        prediction_id, fan_id, choice, is_winner, pearls_awarded
    ) VALUES (
        p_prediction_id, v_fan_id, p_choice, NULL, 0
    ) RETURNING id INTO v_vote_id;

    RETURN jsonb_build_object(
        'vote_id', v_vote_id,
        'prediction_id', p_prediction_id,
        'choice', p_choice,
        'status', 'success',
        'message', 'Pronóstico registrado con éxito. El resultado se validará al terminar el partido.'
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.submit_over_under_vote(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_over_under_vote(UUID, TEXT) TO authenticated;


-- 5b. Resolve Over/Under with Standard Ledger
CREATE OR REPLACE FUNCTION public.admin_resolve_over_under(
    p_prediction_id UUID,
    p_actual_value NUMERIC(6,1)
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_pred RECORD;
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
    PERFORM public.assert_admin();

    SELECT * INTO v_pred FROM public.over_under_predictions WHERE id = p_prediction_id;
    IF v_pred.id IS NULL THEN
        RAISE EXCEPTION 'La predicción no existe.';
    END IF;

    IF v_pred.status = 'resolved' THEN
        RAISE EXCEPTION 'Esta predicción ya fue resuelta previamente.';
    END IF;

    IF p_actual_value > v_pred.line_value THEN
        v_winning_choice := 'over';
    ELSIF p_actual_value < v_pred.line_value THEN
        v_winning_choice := 'under';
    ELSE
        v_winning_choice := 'push';
    END IF;

    v_reward_pearls := v_pred.reward_pearls;
    SELECT daily_pearl_cap, weekly_pearl_cap INTO v_daily_cap, v_weekly_cap FROM public.economy_settings LIMIT 1;

    UPDATE public.over_under_predictions
    SET status = 'resolved',
        actual_value = p_actual_value,
        winning_choice = v_winning_choice,
        resolved_at = now(),
        resolved_by = v_admin_id
    WHERE id = p_prediction_id;

    UPDATE public.over_under_votes
    SET is_winner = FALSE, pearls_awarded = 0
    WHERE prediction_id = p_prediction_id AND choice <> v_winning_choice;

    FOR v_vote IN
        SELECT id, fan_id FROM public.over_under_votes
        WHERE prediction_id = p_prediction_id AND choice = v_winning_choice
    LOOP
        v_winners_count := v_winners_count + 1;

        SELECT COALESCE(SUM(amount), 0) INTO v_today_earned
        FROM public.ledger_entries
        WHERE fan_id = v_vote.fan_id
          AND amount > 0
          AND status IN ('confirmed', 'held')
          AND (created_at AT TIME ZONE 'America/Caracas') >= v_today_start_caracas;

        SELECT COALESCE(SUM(amount), 0) INTO v_week_earned
        FROM public.ledger_entries
        WHERE fan_id = v_vote.fan_id
          AND amount > 0
          AND status IN ('confirmed', 'held')
          AND (created_at AT TIME ZONE 'America/Caracas') >= v_week_start_caracas;

        v_rem_daily := GREATEST(0, COALESCE(v_daily_cap, 1000) - v_today_earned);
        v_rem_weekly := GREATEST(0, COALESCE(v_weekly_cap, 5000) - v_week_earned);
        v_effective_cap := LEAST(v_rem_daily, v_rem_weekly);
        v_pearls_to_award := LEAST(v_reward_pearls, v_effective_cap);

        IF v_pearls_to_award > 0 THEN
            INSERT INTO public.ledger_entries (
                fan_id, amount, type, status, source_type, source_id, note
            ) VALUES (
                v_vote.fan_id, v_pearls_to_award, 'trivia_reward', 'confirmed', 'over_under', p_prediction_id::text,
                'Premio por acertar Over/Under: ' || v_pred.title
            );

            INSERT INTO public.wallets (fan_id, balance_cache)
            VALUES (v_vote.fan_id, v_pearls_to_award)
            ON CONFLICT (fan_id)
            DO UPDATE SET balance_cache = wallets.balance_cache + v_pearls_to_award, updated_at = NOW();

            PERFORM public.calculate_and_apply_streak_bonus(v_vote.fan_id);
        END IF;

        UPDATE public.over_under_votes
        SET is_winner = TRUE, pearls_awarded = v_pearls_to_award
        WHERE id = v_vote.id;

        v_total_pearls := v_total_pearls + v_pearls_to_award;
    END LOOP;

    RETURN jsonb_build_object(
        'status', 'success',
        'winning_choice', v_winning_choice,
        'winners_count', v_winners_count,
        'total_pearls_awarded', v_total_pearls
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_resolve_over_under(UUID, NUMERIC) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_resolve_over_under(UUID, NUMERIC) TO authenticated;


-- 5c. Mystery Play Vote with Rate Limiting and Standard Ledger
CREATE OR REPLACE FUNCTION public.submit_mystery_play_vote(
    p_challenge_id UUID,
    p_selected_option TEXT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_fan_id UUID := auth.uid();
    v_chal RECORD;
    v_is_correct BOOLEAN;
    v_pearls_to_award INT := 0;
    v_daily_cap INT := 1000;
    v_weekly_cap INT := 5000;
    v_rem_daily INT;
    v_rem_weekly INT;
    v_effective_cap INT;
    v_vote_id UUID;
    v_today_start_caracas TIMESTAMPTZ := date_trunc('day', NOW() AT TIME ZONE 'America/Caracas') AT TIME ZONE 'America/Caracas';
    v_week_start_caracas TIMESTAMPTZ := date_trunc('week', NOW() AT TIME ZONE 'America/Caracas') AT TIME ZONE 'America/Caracas';
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Usuario no autenticado.';
    END IF;

    -- Rate limiting
    PERFORM public.check_rate_limit(v_fan_id, 'submit_mystery_play_vote', 5, 60);

    PERFORM public.assert_active_verified_fan(v_fan_id);

    IF p_selected_option NOT IN ('A', 'B', 'C', 'D') THEN
        RAISE EXCEPTION 'Opción inválida. Debe ser A, B, C o D.';
    END IF;

    SELECT * INTO v_chal FROM public.mystery_play_challenges WHERE id = p_challenge_id;
    IF v_chal.id IS NULL THEN
        RAISE EXCEPTION 'El desafío de jugada no existe.';
    END IF;

    IF v_chal.status <> 'published' THEN
        RAISE EXCEPTION 'Este desafío ya no está abierto.';
    END IF;

    IF now() > v_chal.closes_at THEN
        RAISE EXCEPTION 'El tiempo para participar ha finalizado.';
    END IF;

    IF EXISTS (SELECT 1 FROM public.mystery_play_votes WHERE challenge_id = p_challenge_id AND fan_id = v_fan_id) THEN
        RAISE EXCEPTION 'Ya has participado en este desafío.';
    END IF;

    v_is_correct := (p_selected_option = v_chal.correct_option);

    IF v_is_correct THEN
        SELECT daily_pearl_cap, weekly_pearl_cap INTO v_daily_cap, v_weekly_cap FROM public.economy_settings LIMIT 1;

        SELECT COALESCE(SUM(amount), 0) INTO v_rem_daily
        FROM public.ledger_entries
        WHERE fan_id = v_fan_id
          AND amount > 0
          AND status IN ('confirmed', 'held')
          AND (created_at AT TIME ZONE 'America/Caracas') >= v_today_start_caracas;
        v_rem_daily := GREATEST(0, COALESCE(v_daily_cap, 1000) - v_rem_daily);

        SELECT COALESCE(SUM(amount), 0) INTO v_rem_weekly
        FROM public.ledger_entries
        WHERE fan_id = v_fan_id
          AND amount > 0
          AND status IN ('confirmed', 'held')
          AND (created_at AT TIME ZONE 'America/Caracas') >= v_week_start_caracas;
        v_rem_weekly := GREATEST(0, COALESCE(v_weekly_cap, 5000) - v_rem_weekly);

        v_effective_cap := LEAST(v_rem_daily, v_rem_weekly);
        v_pearls_to_award := LEAST(v_chal.reward_pearls, v_effective_cap);

        IF v_pearls_to_award > 0 THEN
            INSERT INTO public.ledger_entries (
                fan_id, amount, type, status, source_type, source_id, note
            ) VALUES (
                v_fan_id, v_pearls_to_award, 'trivia_reward', 'confirmed', 'mystery_play', p_challenge_id::text,
                'Premio Jugada Misteriosa: ' || v_chal.title
            );

            INSERT INTO public.wallets (fan_id, balance_cache)
            VALUES (v_fan_id, v_pearls_to_award)
            ON CONFLICT (fan_id)
            DO UPDATE SET balance_cache = wallets.balance_cache + v_pearls_to_award, updated_at = NOW();

            PERFORM public.calculate_and_apply_streak_bonus(v_fan_id);
        END IF;
    END IF;

    INSERT INTO public.mystery_play_votes (
        challenge_id, fan_id, selected_option, is_winner, pearls_awarded
    ) VALUES (
        p_challenge_id, v_fan_id, p_selected_option, v_is_correct, v_pearls_to_award
    ) RETURNING id INTO v_vote_id;

    RETURN jsonb_build_object(
        'vote_id', v_vote_id,
        'is_winner', v_is_correct,
        'pearls_awarded', v_pearls_to_award,
        'correct_option', v_chal.correct_option,
        'reveal_video_url', v_chal.reveal_video_url,
        'status', 'success'
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.submit_mystery_play_vote(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_mystery_play_vote(UUID, TEXT) TO authenticated;


-- 5d. Score Prediction Vote with Rate Limiting
CREATE OR REPLACE FUNCTION public.submit_score_prediction_vote(
    p_prediction_id UUID,
    p_guaiqueries_score INT,
    p_rival_score INT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_fan_id UUID := auth.uid();
    v_pred RECORD;
    v_vote_id UUID;
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Usuario no autenticado.';
    END IF;

    -- Rate limiting
    PERFORM public.check_rate_limit(v_fan_id, 'submit_score_prediction_vote', 5, 60);

    PERFORM public.assert_active_verified_fan(v_fan_id);

    IF p_guaiqueries_score < 0 OR p_rival_score < 0 THEN
        RAISE EXCEPTION 'El marcador no puede ser negativo.';
    END IF;

    SELECT * INTO v_pred FROM public.score_predictions WHERE id = p_prediction_id;
    IF v_pred.id IS NULL THEN
        RAISE EXCEPTION 'La predicción de marcador no existe.';
    END IF;

    IF v_pred.status <> 'published' THEN
        RAISE EXCEPTION 'Esta predicción no está abierta.';
    END IF;

    IF now() > v_pred.closes_at THEN
        RAISE EXCEPTION 'El tiempo para pronosticar ha cerrado.';
    END IF;

    IF EXISTS (SELECT 1 FROM public.score_prediction_votes WHERE prediction_id = p_prediction_id AND fan_id = v_fan_id) THEN
        RAISE EXCEPTION 'Ya has enviado tu pronóstico para este partido.';
    END IF;

    INSERT INTO public.score_prediction_votes (
        prediction_id, fan_id, predicted_guaiqueries_score, predicted_rival_score, is_exact_match, is_closest_match, pearls_awarded
    ) VALUES (
        p_prediction_id, v_fan_id, p_guaiqueries_score, p_rival_score, NULL, NULL, 0
    ) RETURNING id INTO v_vote_id;

    RETURN jsonb_build_object(
        'vote_id', v_vote_id,
        'prediction_id', p_prediction_id,
        'predicted_guaiqueries_score', p_guaiqueries_score,
        'predicted_rival_score', p_rival_score,
        'status', 'success',
        'message', 'Marcador registrado con éxito. ¡Mucha suerte al sonar la chicharra!'
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.submit_score_prediction_vote(UUID, INT, INT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_score_prediction_vote(UUID, INT, INT) TO authenticated;


-- 5e. Resolve Score Prediction with Standard Ledger
CREATE OR REPLACE FUNCTION public.admin_resolve_score_prediction(
    p_prediction_id UUID,
    p_final_guaiqueries_score INT,
    p_final_rival_score INT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_pred RECORD;
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
    PERFORM public.assert_admin();

    SELECT * INTO v_pred FROM public.score_predictions WHERE id = p_prediction_id;
    IF v_pred.id IS NULL THEN
        RAISE EXCEPTION 'La predicción no existe.';
    END IF;

    IF v_pred.status = 'resolved' THEN
        RAISE EXCEPTION 'Esta predicción ya fue resuelta.';
    END IF;

    v_exact_reward := v_pred.exact_reward_pearls;
    v_closest_reward := v_pred.closest_reward_pearls;
    SELECT daily_pearl_cap, weekly_pearl_cap INTO v_daily_cap, v_weekly_cap FROM public.economy_settings LIMIT 1;

    UPDATE public.score_predictions
    SET status = 'resolved',
        actual_guaiqueries_score = p_final_guaiqueries_score,
        actual_rival_score = p_final_rival_score,
        resolved_at = now(),
        resolved_by = v_admin_id
    WHERE id = p_prediction_id;

    -- Calculate min differential across non-exact predictions
    FOR v_vote IN SELECT id, predicted_guaiqueries_score, predicted_rival_score FROM public.score_prediction_votes WHERE prediction_id = p_prediction_id LOOP
        v_diff := ABS(v_vote.predicted_guaiqueries_score - p_final_guaiqueries_score) + ABS(v_vote.predicted_rival_score - p_final_rival_score);
        IF v_diff > 0 AND v_diff < v_min_diff THEN
            v_min_diff := v_diff;
        END IF;
    END LOOP;

    FOR v_vote IN SELECT id, fan_id, predicted_guaiqueries_score, predicted_rival_score FROM public.score_prediction_votes WHERE prediction_id = p_prediction_id LOOP
        v_diff := ABS(v_vote.predicted_guaiqueries_score - p_final_guaiqueries_score) + ABS(v_vote.predicted_rival_score - p_final_rival_score);
        v_pearls_to_award := 0;

        SELECT COALESCE(SUM(amount), 0) INTO v_today_earned
        FROM public.ledger_entries
        WHERE fan_id = v_vote.fan_id
          AND amount > 0
          AND status IN ('confirmed', 'held')
          AND (created_at AT TIME ZONE 'America/Caracas') >= v_today_start_caracas;

        SELECT COALESCE(SUM(amount), 0) INTO v_week_earned
        FROM public.ledger_entries
        WHERE fan_id = v_vote.fan_id
          AND amount > 0
          AND status IN ('confirmed', 'held')
          AND (created_at AT TIME ZONE 'America/Caracas') >= v_week_start_caracas;

        v_rem_daily := GREATEST(0, COALESCE(v_daily_cap, 1000) - v_today_earned);
        v_rem_weekly := GREATEST(0, COALESCE(v_weekly_cap, 5000) - v_week_earned);
        v_effective_cap := LEAST(v_rem_daily, v_rem_weekly);

        IF v_diff = 0 THEN
            v_exact_count := v_exact_count + 1;
            v_pearls_to_award := LEAST(v_exact_reward, v_effective_cap);

            UPDATE public.score_prediction_votes
            SET is_exact_match = TRUE, is_closest_match = FALSE, pearls_awarded = v_pearls_to_award
            WHERE id = v_vote.id;
        ELSIF v_diff = v_min_diff THEN
            v_closest_count := v_closest_count + 1;
            v_pearls_to_award := LEAST(v_closest_reward, v_effective_cap);

            UPDATE public.score_prediction_votes
            SET is_exact_match = FALSE, is_closest_match = TRUE, pearls_awarded = v_pearls_to_award
            WHERE id = v_vote.id;
        ELSE
            UPDATE public.score_prediction_votes
            SET is_exact_match = FALSE, is_closest_match = FALSE, pearls_awarded = 0
            WHERE id = v_vote.id;
        END IF;

        IF v_pearls_to_award > 0 THEN
            INSERT INTO public.ledger_entries (
                fan_id, amount, type, status, source_type, source_id, note
            ) VALUES (
                v_vote.fan_id, v_pearls_to_award, 'trivia_reward', 'confirmed', 'score_prediction', p_prediction_id::text,
                'Premio Pronóstico de Marcador: ' || v_pred.title
            );

            INSERT INTO public.wallets (fan_id, balance_cache)
            VALUES (v_vote.fan_id, v_pearls_to_award)
            ON CONFLICT (fan_id)
            DO UPDATE SET balance_cache = wallets.balance_cache + v_pearls_to_award, updated_at = NOW();

            PERFORM public.calculate_and_apply_streak_bonus(v_vote.fan_id);
            v_total_pearls := v_total_pearls + v_pearls_to_award;
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'status', 'success',
        'exact_winners_count', v_exact_count,
        'closest_winners_count', v_closest_count,
        'total_pearls_awarded', v_total_pearls
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_resolve_score_prediction(UUID, INT, INT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_resolve_score_prediction(UUID, INT, INT) TO authenticated;


-- 5f. Flash Trivia Attempt Submission with Rate Limiting and Standard Ledger
CREATE OR REPLACE FUNCTION public.submit_flash_trivia_session(
    p_challenge_id UUID,
    p_answers jsonb,
    p_time_spent_seconds INT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_fan_id UUID := auth.uid();
    v_chal RECORD;
    v_item RECORD;
    v_q RECORD;
    v_correct_count INT := 0;
    v_total_answered INT := 0;
    v_pearls_earned INT := 0;
    v_pearls_to_award INT := 0;
    v_daily_cap INT := 1000;
    v_weekly_cap INT := 5000;
    v_rem_daily INT;
    v_rem_weekly INT;
    v_effective_cap INT;
    v_attempt_id UUID;
    v_today_start_caracas TIMESTAMPTZ := date_trunc('day', NOW() AT TIME ZONE 'America/Caracas') AT TIME ZONE 'America/Caracas';
    v_week_start_caracas TIMESTAMPTZ := date_trunc('week', NOW() AT TIME ZONE 'America/Caracas') AT TIME ZONE 'America/Caracas';
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Usuario no autenticado.';
    END IF;

    -- Rate limiting
    PERFORM public.check_rate_limit(v_fan_id, 'submit_flash_trivia_attempt', 5, 60);

    PERFORM public.assert_active_verified_fan(v_fan_id);

    SELECT * INTO v_chal FROM public.flash_trivia_challenges WHERE id = p_challenge_id;
    IF v_chal.id IS NULL THEN
        RAISE EXCEPTION 'El desafío flash no existe.';
    END IF;

    IF v_chal.status <> 'published' THEN
        RAISE EXCEPTION 'Este desafío flash no está activo.';
    END IF;

    IF now() > v_chal.closes_at THEN
        RAISE EXCEPTION 'El desafío flash ya cerró.';
    END IF;

    IF EXISTS (SELECT 1 FROM public.flash_trivia_attempts WHERE challenge_id = p_challenge_id AND fan_id = v_fan_id) THEN
        RAISE EXCEPTION 'Ya has participado en esta sesión contrarreloj.';
    END IF;

    -- Evaluate answers securely on server
    FOR v_item IN SELECT * FROM jsonb_to_recordset(p_answers) AS x(question_id UUID, selected_option TEXT)
    LOOP
        v_total_answered := v_total_answered + 1;
        SELECT * INTO v_q FROM public.flash_trivia_questions WHERE id = v_item.question_id AND challenge_id = p_challenge_id;
        IF v_q.id IS NOT NULL AND v_q.correct_option = UPPER(TRIM(v_item.selected_option)) THEN
            v_correct_count := v_correct_count + 1;
        END IF;
    END LOOP;

    v_pearls_earned := v_correct_count * v_chal.pearls_per_correct;

    IF v_pearls_earned > 0 THEN
        SELECT daily_pearl_cap, weekly_pearl_cap INTO v_daily_cap, v_weekly_cap FROM public.economy_settings LIMIT 1;

        SELECT COALESCE(SUM(amount), 0) INTO v_rem_daily
        FROM public.ledger_entries
        WHERE fan_id = v_fan_id
          AND amount > 0
          AND status IN ('confirmed', 'held')
          AND (created_at AT TIME ZONE 'America/Caracas') >= v_today_start_caracas;
        v_rem_daily := GREATEST(0, COALESCE(v_daily_cap, 1000) - v_rem_daily);

        SELECT COALESCE(SUM(amount), 0) INTO v_rem_weekly
        FROM public.ledger_entries
        WHERE fan_id = v_fan_id
          AND amount > 0
          AND status IN ('confirmed', 'held')
          AND (created_at AT TIME ZONE 'America/Caracas') >= v_week_start_caracas;
        v_rem_weekly := GREATEST(0, COALESCE(v_weekly_cap, 5000) - v_rem_weekly);

        v_effective_cap := LEAST(v_rem_daily, v_rem_weekly);
        v_pearls_to_award := LEAST(v_pearls_earned, v_effective_cap);

        IF v_pearls_to_award > 0 THEN
            INSERT INTO public.ledger_entries (
                fan_id, amount, type, status, source_type, source_id, note
            ) VALUES (
                v_fan_id, v_pearls_to_award, 'trivia_reward', 'confirmed', 'flash_trivia', p_challenge_id::text,
                'Sesión Flash Contrarreloj: ' || v_chal.title
            );

            INSERT INTO public.wallets (fan_id, balance_cache)
            VALUES (v_fan_id, v_pearls_to_award)
            ON CONFLICT (fan_id)
            DO UPDATE SET balance_cache = wallets.balance_cache + v_pearls_to_award, updated_at = NOW();

            PERFORM public.calculate_and_apply_streak_bonus(v_fan_id);
        END IF;
    END IF;

    INSERT INTO public.flash_trivia_attempts (
        challenge_id, fan_id, correct_count, total_answered, time_spent_seconds, pearls_awarded
    ) VALUES (
        p_challenge_id, v_fan_id, v_correct_count, v_total_answered, p_time_spent_seconds, v_pearls_to_award
    ) RETURNING id INTO v_attempt_id;

    RETURN jsonb_build_object(
        'attempt_id', v_attempt_id,
        'correct_count', v_correct_count,
        'total_answered', v_total_answered,
        'time_spent_seconds', p_time_spent_seconds,
        'pearls_awarded', v_pearls_to_award
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.submit_flash_trivia_session(UUID, jsonb, INT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_flash_trivia_session(UUID, jsonb, INT) TO authenticated;


-- 5g. Progressive Clues Vote with Rate Limiting and Standard Ledger
CREATE OR REPLACE FUNCTION public.submit_progressive_clue_vote(
    p_challenge_id UUID,
    p_selected_player_id UUID,
    p_clues_revealed_count INT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_fan_id UUID := auth.uid();
    v_chal RECORD;
    v_is_correct BOOLEAN := FALSE;
    v_reward_base INT := 0;
    v_pearls_to_award INT := 0;
    v_daily_cap INT := 1000;
    v_weekly_cap INT := 5000;
    v_rem_daily INT;
    v_rem_weekly INT;
    v_effective_cap INT;
    v_vote_id UUID;
    v_today_start_caracas TIMESTAMPTZ := date_trunc('day', NOW() AT TIME ZONE 'America/Caracas') AT TIME ZONE 'America/Caracas';
    v_week_start_caracas TIMESTAMPTZ := date_trunc('week', NOW() AT TIME ZONE 'America/Caracas') AT TIME ZONE 'America/Caracas';
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Usuario no autenticado.';
    END IF;

    -- Rate limiting
    PERFORM public.check_rate_limit(v_fan_id, 'submit_progressive_clue_vote', 5, 60);

    PERFORM public.assert_active_verified_fan(v_fan_id);

    IF p_clues_revealed_count NOT BETWEEN 1 AND 3 THEN
        RAISE EXCEPTION 'Número de pistas inválido (1-3).';
    END IF;

    SELECT * INTO v_chal FROM public.progressive_clue_challenges WHERE id = p_challenge_id;
    IF v_chal.id IS NULL THEN
        RAISE EXCEPTION 'El desafío de pistas no existe.';
    END IF;

    IF v_chal.status <> 'published' THEN
        RAISE EXCEPTION 'Este desafío no está activo.';
    END IF;

    IF now() > v_chal.closes_at THEN
        RAISE EXCEPTION 'El desafío ya cerró.';
    END IF;

    IF EXISTS (SELECT 1 FROM public.progressive_clue_votes WHERE challenge_id = p_challenge_id AND fan_id = v_fan_id) THEN
        RAISE EXCEPTION 'Ya has participado en este desafío de pistas.';
    END IF;

    -- Validate if correct
    v_is_correct := (p_selected_player_id = v_chal.player_id);

    IF v_is_correct THEN
        IF p_clues_revealed_count = 1 THEN
            v_reward_base := v_chal.pearls_clue_1;
        ELSIF p_clues_revealed_count = 2 THEN
            v_reward_base := v_chal.pearls_clue_2;
        ELSE
            v_reward_base := v_chal.pearls_clue_3;
        END IF;

        SELECT daily_pearl_cap, weekly_pearl_cap INTO v_daily_cap, v_weekly_cap FROM public.economy_settings LIMIT 1;

        SELECT COALESCE(SUM(amount), 0) INTO v_rem_daily
        FROM public.ledger_entries
        WHERE fan_id = v_fan_id
          AND amount > 0
          AND status IN ('confirmed', 'held')
          AND (created_at AT TIME ZONE 'America/Caracas') >= v_today_start_caracas;
        v_rem_daily := GREATEST(0, COALESCE(v_daily_cap, 1000) - v_rem_daily);

        SELECT COALESCE(SUM(amount), 0) INTO v_rem_weekly
        FROM public.ledger_entries
        WHERE fan_id = v_fan_id
          AND amount > 0
          AND status IN ('confirmed', 'held')
          AND (created_at AT TIME ZONE 'America/Caracas') >= v_week_start_caracas;
        v_rem_weekly := GREATEST(0, COALESCE(v_weekly_cap, 5000) - v_rem_weekly);

        v_effective_cap := LEAST(v_rem_daily, v_rem_weekly);
        v_pearls_to_award := LEAST(v_reward_base, v_effective_cap);

        IF v_pearls_to_award > 0 THEN
            INSERT INTO public.ledger_entries (
                fan_id, amount, type, status, source_type, source_id, note
            ) VALUES (
                v_fan_id, v_pearls_to_award, 'trivia_reward', 'confirmed', 'progressive_clues', p_challenge_id::text,
                'Premio Pistas Progresivas: ' || v_chal.title
            );

            INSERT INTO public.wallets (fan_id, balance_cache)
            VALUES (v_fan_id, v_pearls_to_award)
            ON CONFLICT (fan_id)
            DO UPDATE SET balance_cache = wallets.balance_cache + v_pearls_to_award, updated_at = NOW();

            PERFORM public.calculate_and_apply_streak_bonus(v_fan_id);
        END IF;
    END IF;

    INSERT INTO public.progressive_clue_votes (
        challenge_id, fan_id, selected_player_id, clues_revealed_count, is_winner, pearls_awarded
    ) VALUES (
        p_challenge_id, v_fan_id, p_selected_player_id, p_clues_revealed_count, v_is_correct, v_pearls_to_award
    ) RETURNING id INTO v_vote_id;

    RETURN jsonb_build_object(
        'vote_id', v_vote_id,
        'is_winner', v_is_correct,
        'pearls_awarded', v_pearls_to_award,
        'target_player_name', v_chal.target_player_name,
        'reveal_photo_url', v_chal.reveal_photo_url,
        'status', 'success'
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.submit_progressive_clue_vote(UUID, UUID, INT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_progressive_clue_vote(UUID, UUID, INT) TO authenticated;

-- Ensure RLS helper permissions are explicitly intact
GRANT EXECUTE ON FUNCTION public.is_admin_check() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_staff_or_admin(uuid) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_admin(uuid) TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';
