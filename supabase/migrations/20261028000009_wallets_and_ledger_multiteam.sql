-- ============================================================================
-- Migration: 20261028000009_wallets_and_ledger_multiteam.sql
-- Description: Paso 2 — Wallets y Ledger Multi-Equipo:
--              1. Alter ledger_entries, ledger_hold_resolutions, wallets:
--                 Add team_id NOT NULL with team #1 default, then drop default.
--                 Change wallets PK to (fan_id, team_id).
--              2. Update handle_new_user to stop creating wallets on signup.
--              3. RPC get_wallet_summary(): computed unified total + per-team breakdown.
--              4. Rewrite submit_trivia_attempt, redeem_product, cancel_redemption,
--                 claim_birthday_bonus, admin_adjust_pearls, admin_release/revoke_held_pearls,
--                 reconcile_wallets, claim_video_points, wallet_ledger.
--              5. Scope admin_list_fans, admin_get_fan, analytics_economy by team followers.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Schema Alterations (Preserving Ledger Immutability)
-- ----------------------------------------------------------------------------

-- 1.1 ledger_entries: Add team_id with default team #1, then drop default
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'ledger_entries' AND column_name = 'team_id'
    ) THEN
        ALTER TABLE public.ledger_entries 
        ADD COLUMN team_id UUID NOT NULL DEFAULT 'a0000000-0000-0000-0000-000000000001' REFERENCES public.teams(id) ON DELETE CASCADE;

        ALTER TABLE public.ledger_entries ALTER COLUMN team_id DROP DEFAULT;

        CREATE INDEX IF NOT EXISTS idx_ledger_entries_fan_team ON public.ledger_entries (fan_id, team_id);
    END IF;
END$$;

-- 1.2 ledger_hold_resolutions: Add team_id with default team #1, then drop default
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'ledger_hold_resolutions' AND column_name = 'team_id'
    ) THEN
        ALTER TABLE public.ledger_hold_resolutions 
        ADD COLUMN team_id UUID NOT NULL DEFAULT 'a0000000-0000-0000-0000-000000000001' REFERENCES public.teams(id) ON DELETE CASCADE;

        ALTER TABLE public.ledger_hold_resolutions ALTER COLUMN team_id DROP DEFAULT;
    END IF;
END$$;

-- 1.3 wallets: Add team_id, backfill to team #1, and composite primary key (fan_id, team_id)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'wallets' AND column_name = 'team_id'
    ) THEN
        ALTER TABLE public.wallets 
        ADD COLUMN team_id UUID NOT NULL DEFAULT 'a0000000-0000-0000-0000-000000000001' REFERENCES public.teams(id) ON DELETE CASCADE;

        ALTER TABLE public.wallets ALTER COLUMN team_id DROP DEFAULT;

        ALTER TABLE public.wallets DROP CONSTRAINT IF EXISTS wallets_pkey;
        ALTER TABLE public.wallets ADD CONSTRAINT wallets_pkey PRIMARY KEY (fan_id, team_id);

        CREATE INDEX IF NOT EXISTS idx_wallets_fan_team ON public.wallets (fan_id, team_id);
    END IF;
END$$;

-- ----------------------------------------------------------------------------
-- 2. handle_new_user: Remove wallet creation (wallets are created on follow_team)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
    v_raw_meta JSONB;
    v_display_name TEXT;
    v_avatar_url TEXT;
    v_municipality TEXT;
    v_birth_date DATE;
    v_gender TEXT;
    v_fav_player UUID;
    v_shirt_size TEXT;
    v_referral TEXT;
    v_terms_at TIMESTAMPTZ;
    v_terms_ver TEXT;
    v_priv_at TIMESTAMPTZ;
    v_priv_ver TEXT;
    v_pearls_at TIMESTAMPTZ;
    v_pearls_ver TEXT;
BEGIN
    v_raw_meta := COALESCE(NEW.raw_user_meta_data, '{}'::jsonb);

    v_display_name := trim(COALESCE(v_raw_meta->>'display_name', v_raw_meta->>'full_name', ''));
    IF v_display_name = '' THEN
        v_display_name := 'Fanático ' || LPAD(FLOOR(random() * 10000)::TEXT, 4, '0');
    END IF;

    v_avatar_url := NULLIF(trim(COALESCE(v_raw_meta->>'avatar_url', v_raw_meta->>'picture', '')), '');
    v_municipality := NULLIF(trim(COALESCE(v_raw_meta->>'municipality', '')), '');
    v_gender := NULLIF(trim(COALESCE(v_raw_meta->>'gender', '')), '');
    v_shirt_size := NULLIF(trim(COALESCE(v_raw_meta->>'shirt_size', '')), '');
    v_referral := NULLIF(trim(COALESCE(v_raw_meta->>'referral_source', '')), '');

    BEGIN
        v_birth_date := (v_raw_meta->>'birth_date')::date;
    EXCEPTION WHEN OTHERS THEN
        v_birth_date := NULL;
    END;

    BEGIN
        v_fav_player := (v_raw_meta->>'favorite_player_id')::uuid;
    EXCEPTION WHEN OTHERS THEN
        v_fav_player := NULL;
    END;

    BEGIN
        v_terms_at := (v_raw_meta->>'terms_accepted_at')::timestamptz;
        v_terms_ver := NULLIF(trim(COALESCE(v_raw_meta->>'terms_version', '')), '');
        v_priv_at := (v_raw_meta->>'privacy_accepted_at')::timestamptz;
        v_priv_ver := NULLIF(trim(COALESCE(v_raw_meta->>'privacy_version', '')), '');
        v_pearls_at := (v_raw_meta->>'pearls_rules_accepted_at')::timestamptz;
        v_pearls_ver := NULLIF(trim(COALESCE(v_raw_meta->>'pearls_rules_version', '')), '');
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    INSERT INTO public.profiles (
        id, display_name, avatar_url, municipality, birth_date, gender,
        favorite_player_id, shirt_size, referral_source, status,
        terms_accepted_at, terms_version, privacy_accepted_at, privacy_version,
        pearls_rules_accepted_at, pearls_rules_version, created_at, updated_at
    )
    VALUES (
        NEW.id, v_display_name, v_avatar_url, v_municipality, v_birth_date, v_gender,
        v_fav_player, v_shirt_size, v_referral, 'active',
        v_terms_at, v_terms_ver, v_priv_at, v_priv_ver,
        v_pearls_at, v_pearls_ver, NOW(), NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        display_name = COALESCE(NULLIF(EXCLUDED.display_name, ''), profiles.display_name),
        avatar_url = COALESCE(NULLIF(profiles.avatar_url, ''), EXCLUDED.avatar_url),
        municipality = COALESCE(EXCLUDED.municipality, profiles.municipality),
        birth_date = COALESCE(EXCLUDED.birth_date, profiles.birth_date),
        gender = COALESCE(EXCLUDED.gender, profiles.gender),
        favorite_player_id = COALESCE(EXCLUDED.favorite_player_id, profiles.favorite_player_id),
        shirt_size = COALESCE(EXCLUDED.shirt_size, profiles.shirt_size),
        referral_source = COALESCE(EXCLUDED.referral_source, profiles.referral_source);

    -- NOTA FASE 2: La billetera ya no se crea al registrarse.
    -- Se inicializa con saldo 0 cuando el fanático sigue a un equipo (follow_team).

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    BEGIN
        INSERT INTO public.auth_trigger_errors (user_id, error_message)
        VALUES (NEW.id, SQLERRM);
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;
    RAISE WARNING 'handle_new_user error for user %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$function$;

-- ----------------------------------------------------------------------------
-- 3. RPC get_wallet_summary(): Total unificado + desglose por equipo
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_wallet_summary()
RETURNS JSONB
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_fan_id UUID := auth.uid();
    v_total_balance INT := 0;
    v_total_held INT := 0;
    v_earned_month INT := 0;
    v_spent_month INT := 0;
    v_start_of_month TIMESTAMPTZ := date_trunc('month', NOW());
    v_teams_data JSONB;
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    -- Saldo total: suma calculada de balance_cache de todos los equipos
    SELECT COALESCE(SUM(balance_cache), 0)
    INTO v_total_balance
    FROM public.wallets
    WHERE fan_id = v_fan_id;

    -- Total retenido: suma de ledger_entries en estado held pendientes de resolución
    SELECT COALESCE(SUM(le.amount), 0)
    INTO v_total_held
    FROM public.ledger_entries le
    WHERE le.fan_id = v_fan_id
      AND le.status = 'held'
      AND NOT EXISTS (
          SELECT 1 FROM public.ledger_hold_resolutions r WHERE r.ledger_id = le.id
      );

    -- Ganadas del mes (entradas positivas confirmadas sumando todos los equipos)
    SELECT COALESCE(SUM(amount), 0)
    INTO v_earned_month
    FROM public.ledger_entries
    WHERE fan_id = v_fan_id
      AND amount > 0
      AND status = 'confirmed'
      AND created_at >= v_start_of_month;

    -- Gastadas del mes (entradas negativas confirmadas en valor absoluto)
    SELECT COALESCE(ABS(SUM(amount)), 0)
    INTO v_spent_month
    FROM public.ledger_entries
    WHERE fan_id = v_fan_id
      AND amount < 0
      AND status = 'confirmed'
      AND created_at >= v_start_of_month;

    -- Desglose por equipo: incluye seguidos O equipos no seguidos con saldo > 0
    SELECT COALESCE(jsonb_agg(team_summary ORDER BY is_following DESC, balance DESC, team_name ASC), '[]'::jsonb)
    INTO v_teams_data
    FROM (
        SELECT jsonb_build_object(
            'team_id', t.id,
            'name', t.name,
            'slug', t.slug,
            'short_name', t.short_name,
            'logo_url', t.logo_url,
            'primary_color', t.primary_color,
            'secondary_color', t.secondary_color,
            'status', t.status,
            'balance', COALESCE(w.balance_cache, 0),
            'held_pearls', COALESCE(h.held_amount, 0),
            'is_following', (tf.user_id IS NOT NULL)
        ) AS team_summary,
        (tf.user_id IS NOT NULL) AS is_following,
        COALESCE(w.balance_cache, 0) AS balance,
        t.name AS team_name
        FROM public.teams t
        LEFT JOIN public.wallets w ON w.team_id = t.id AND w.fan_id = v_fan_id
        LEFT JOIN public.team_follows tf ON tf.team_id = t.id AND tf.user_id = v_fan_id
        LEFT JOIN (
            SELECT le.team_id, SUM(le.amount) AS held_amount
            FROM public.ledger_entries le
            WHERE le.fan_id = v_fan_id AND le.status = 'held'
              AND NOT EXISTS (SELECT 1 FROM public.ledger_hold_resolutions r WHERE r.ledger_id = le.id)
            GROUP BY le.team_id
        ) h ON h.team_id = t.id
        WHERE tf.user_id IS NOT NULL
           OR COALESCE(w.balance_cache, 0) > 0
           OR COALESCE(h.held_amount, 0) > 0
    ) sub;

    RETURN jsonb_build_object(
        'total_balance', v_total_balance,
        'balance', v_total_balance,
        'total_held', v_total_held,
        'held_pearls', v_total_held,
        'earned_month', v_earned_month,
        'spent_month', v_spent_month,
        'teams', v_teams_data
    );
END;
$function$;

-- Alias wallet_summary() para mantener compatibilidad
CREATE OR REPLACE FUNCTION public.wallet_summary()
RETURNS JSONB
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
    SELECT public.get_wallet_summary();
$$;

-- ----------------------------------------------------------------------------
-- 4. RPC wallet_ledger(p_team_id, p_type, p_cursor, p_limit)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.wallet_ledger(
    p_team_id UUID DEFAULT NULL::UUID,
    p_type TEXT DEFAULT NULL::TEXT,
    p_cursor TIMESTAMPTZ DEFAULT NULL::TIMESTAMPTZ,
    p_limit INTEGER DEFAULT 20
)
RETURNS JSONB
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
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    SELECT COALESCE(jsonb_agg(entry_data), '[]'::jsonb) INTO v_entries
    FROM (
        SELECT jsonb_build_object(
            'id', le.id,
            'team_id', le.team_id,
            'team_name', t.name,
            'team_logo_url', t.logo_url,
            'amount', le.amount,
            'type', le.type,
            'status', le.status,
            'note', le.note,
            'source_type', le.source_type,
            'source_id', le.source_id,
            'created_at', le.created_at,
            'description', CASE
                WHEN le.type = 'trivia_reward' THEN 'Premio por trivia (' || COALESCE(t.short_name, t.name) || ')'
                WHEN le.type = 'redemption' THEN 'Canje de premio (' || COALESCE(t.short_name, t.name) || ')'
                WHEN le.type = 'refund' THEN 'Reembolso de canje (' || COALESCE(t.short_name, t.name) || ')'
                WHEN le.type = 'bonus' THEN 'Bono de evento (' || COALESCE(t.short_name, t.name) || ')'
                WHEN le.type = 'streak_bonus' THEN 'Bono de racha (' || COALESCE(t.short_name, t.name) || ')'
                WHEN le.type = 'birthday_bonus' THEN 'Bono de cumpleaños (' || COALESCE(t.short_name, t.name) || ')'
                WHEN le.type = 'admin_adjustment' THEN 'Ajuste administrativo (' || COALESCE(t.short_name, t.name) || ')'
                ELSE COALESCE(le.note, 'Movimiento de perlitas')
            END
        ) AS entry_data
        FROM public.ledger_entries le
        JOIN public.teams t ON t.id = le.team_id
        WHERE le.fan_id = v_fan_id
          AND (p_team_id IS NULL OR le.team_id = p_team_id)
          AND (p_type IS NULL OR p_type = 'all' OR le.type::text = p_type)
          AND (p_cursor IS NULL OR le.created_at < p_cursor)
        ORDER BY le.created_at DESC
        LIMIT v_limit
    ) sub;

    RETURN v_entries;
END;
$function$;

-- ----------------------------------------------------------------------------
-- 5. RPC submit_trivia_attempt (Derives team_id, requires following active team)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_trivia_attempt(p_attempt_id UUID, p_answers JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_fan_id UUID;
    v_attempt trivia_attempts%ROWTYPE;
    v_trivia trivias%ROWTYPE;
    v_team_id UUID;
    v_team_status public.team_status;
    v_score INT := 0;
    v_correct_count INT := 0;
    v_total_questions INT := 0;
    v_raw_pearls INT := 0;
    v_final_pearls INT := 0;
    v_is_won BOOLEAN := false;
    v_time_spent_seconds NUMERIC;
    v_is_suspicious BOOLEAN := false;
    v_entry_status ledger_status := 'confirmed';
    v_daily_cap INT;
    v_weekly_cap INT;
    v_today_earned INT;
    v_week_earned INT;
    v_rem_daily INT;
    v_rem_weekly INT;
    v_effective_cap INT;
    v_today_caracas DATE := (NOW() AT TIME ZONE 'America/Caracas')::date;
    v_week_start_caracas TIMESTAMPTZ := date_trunc('week', NOW() AT TIME ZONE 'America/Caracas') AT TIME ZONE 'America/Caracas';
    v_per_correct_pearls INT;
    v_perfect_bonus INT;
    v_unresolved_flags INT;
    v_q RECORD;
    v_chosen_option_id UUID;
    v_is_correct BOOLEAN;
BEGIN
    v_fan_id := public.assert_active_verified_fan();

    IF p_attempt_id IS NULL THEN
        RAISE EXCEPTION 'Attempt ID is required.';
    END IF;

    PERFORM public.check_rate_limit(v_fan_id, 'submit_trivia_attempt', 5, 60);

    SELECT * INTO v_attempt FROM public.trivia_attempts WHERE id = p_attempt_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'ATTEMPT_NOT_FOUND: El intento de trivia no existe.';
    END IF;

    IF v_attempt.fan_id != v_fan_id THEN
        RAISE EXCEPTION 'UNAUTHORIZED: No puedes enviar respuestas para el intento de otro usuario.' USING ERRCODE = '42501';
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

    SELECT * INTO v_trivia FROM public.trivias WHERE id = v_attempt.trivia_id;
    v_team_id := v_trivia.team_id;

    -- Validar que el equipo exista y esté activo
    SELECT status INTO v_team_status FROM public.teams WHERE id = v_team_id;
    IF v_team_status != 'active' THEN
        RAISE EXCEPTION 'No se pueden ganar perlitas de un equipo inactivo.' USING ERRCODE = '42501';
    END IF;

    -- Validar que el fanático siga al equipo
    IF NOT EXISTS (
        SELECT 1 FROM public.team_follows
        WHERE user_id = v_fan_id AND team_id = v_team_id
    ) THEN
        RAISE EXCEPTION 'Debes seguir a este equipo para poder jugar su trivia y ganar sus perlitas.' USING ERRCODE = '42501';
    END IF;

    v_time_spent_seconds := EXTRACT(EPOCH FROM (NOW() - v_attempt.started_at));

    SELECT COUNT(*) INTO v_unresolved_flags
    FROM public.risk_flags
    WHERE fan_id = v_fan_id AND resolved = false;

    IF v_time_spent_seconds < 3.0 OR v_unresolved_flags > 0 THEN
        v_is_suspicious := true;
        v_entry_status := 'held';

        IF v_time_spent_seconds < 3.0 THEN
            INSERT INTO public.risk_flags (fan_id, team_id, reason, severity)
            VALUES (v_fan_id, v_team_id, 'Velocidad inverosímil al responder trivia (' || round(v_time_spent_seconds, 2) || 's)', 'high');
        END IF;
    END IF;

    v_per_correct_pearls := COALESCE((v_trivia.reward_rules->>'per_correct_pearls')::int, 50);
    v_perfect_bonus := COALESCE((v_trivia.reward_rules->>'perfect_score_bonus')::int, 100);

    FOR v_q IN SELECT q.id, q.points FROM public.trivia_questions q WHERE q.trivia_id = v_trivia.id LOOP
        v_total_questions := v_total_questions + 1;
        v_chosen_option_id := (p_answers->>(v_q.id::text))::uuid;
        IF v_chosen_option_id IS NOT NULL THEN
            SELECT is_correct INTO v_is_correct 
            FROM public.trivia_options 
            WHERE id = v_chosen_option_id AND question_id = v_q.id;

            IF v_is_correct IS TRUE THEN
                v_correct_count := v_correct_count + 1;
                v_score := v_score + v_q.points;
                v_raw_pearls := v_raw_pearls + v_per_correct_pearls;
            END IF;
        END IF;
    END LOOP;

    v_is_won := (v_total_questions > 0 AND v_correct_count = v_total_questions);

    IF v_is_won THEN
        v_raw_pearls := v_raw_pearls + v_perfect_bonus;

        -- Topes de economía: globales por usuario sumando todos los equipos
        SELECT daily_pearl_cap, weekly_pearl_cap 
        INTO v_daily_cap, v_weekly_cap
        FROM public.economy_settings
        ORDER BY created_at DESC LIMIT 1;

        v_daily_cap := COALESCE(v_daily_cap, 1000);
        v_weekly_cap := COALESCE(v_weekly_cap, 5000);

        SELECT COALESCE(SUM(amount), 0) INTO v_today_earned
        FROM public.ledger_entries
        WHERE fan_id = v_fan_id
          AND amount > 0
          AND status IN ('confirmed', 'held')
          AND (created_at AT TIME ZONE 'America/Caracas')::date = v_today_caracas;

        SELECT COALESCE(SUM(amount), 0) INTO v_week_earned
        FROM public.ledger_entries
        WHERE fan_id = v_fan_id
          AND amount > 0
          AND status IN ('confirmed', 'held')
          AND (created_at AT TIME ZONE 'America/Caracas') >= v_week_start_caracas;

        v_rem_daily := GREATEST(0, v_daily_cap - v_today_earned);
        v_rem_weekly := GREATEST(0, v_weekly_cap - v_week_earned);
        v_effective_cap := LEAST(v_rem_daily, v_rem_weekly);

        v_final_pearls := LEAST(v_raw_pearls, v_effective_cap);

        IF v_final_pearls > 0 THEN
            INSERT INTO public.ledger_entries (
                fan_id, team_id, amount, type, status, source_type, source_id, note
            ) VALUES (
                v_fan_id, v_team_id, v_final_pearls, 'trivia_reward', v_entry_status, 'trivia_attempt', v_attempt.id::text,
                'Premio por trivia: ' || v_trivia.title
            );

            IF v_entry_status = 'confirmed' THEN
                INSERT INTO public.wallets (fan_id, team_id, balance_cache, updated_at)
                VALUES (v_fan_id, v_team_id, v_final_pearls, NOW())
                ON CONFLICT (fan_id, team_id) 
                DO UPDATE SET balance_cache = public.wallets.balance_cache + v_final_pearls, updated_at = NOW();
            END IF;
        END IF;

        IF v_entry_status = 'confirmed' THEN
            PERFORM public.calculate_and_apply_streak_bonus(v_fan_id);
        END IF;
    END IF;

    UPDATE public.trivia_attempts
    SET score = v_score,
        pearls_awarded = v_final_pearls,
        answers = p_answers,
        submitted_at = NOW(),
        suspicious = v_is_suspicious
    WHERE id = v_attempt.id;

    RETURN jsonb_build_object(
        'attempt_id', v_attempt.id,
        'team_id', v_team_id,
        'score', v_score,
        'correct_count', v_correct_count,
        'total_questions', v_total_questions,
        'pearls_awarded', v_final_pearls,
        'is_won', v_is_won,
        'suspicious', v_is_suspicious
    );
END;
$function$;

-- ----------------------------------------------------------------------------
-- 6. RPC redeem_product (Spends from product's team wallet)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.redeem_product(
    p_product_id UUID,
    p_idempotency_key TEXT,
    p_variant JSONB DEFAULT NULL::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_fan_id UUID;
    v_product public.products%ROWTYPE;
    v_team_id UUID;
    v_team_status public.team_status;
    v_wallet public.wallets%ROWTYPE;
    v_existing_redemption public.redemptions%ROWTYPE;
    v_redemption_id UUID;
    v_raw_code TEXT;
    v_code_hash TEXT;
    v_hmac_secret TEXT;
    v_expires_at TIMESTAMPTZ;
    v_profile public.profiles%ROWTYPE;
    v_high_val_pearls INT := 500;
    v_min_age_days INT := 7;
    v_min_trivias INT := 3;
    v_account_age_days INT;
    v_trivias_completed INT;
    v_setting_record RECORD;
BEGIN
    v_fan_id := public.assert_active_verified_fan();

    IF p_idempotency_key IS NULL OR trim(p_idempotency_key) = '' THEN
        RAISE EXCEPTION 'Idempotency key is required.';
    END IF;

    PERFORM public.check_rate_limit(v_fan_id, 'redeem_product', 3, 60);

    -- 1. Idempotency Check
    SELECT * INTO v_existing_redemption 
    FROM public.redemptions 
    WHERE fan_id = v_fan_id AND idempotency_key = p_idempotency_key;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'redemption_id', v_existing_redemption.id,
            'team_id', v_existing_redemption.team_id,
            'code_hash', v_existing_redemption.code_hash,
            'status', v_existing_redemption.status,
            'cost_pearls', v_existing_redemption.cost_pearls,
            'variant', v_existing_redemption.variant,
            'reused', true
        );
    END IF;

    -- 2. Lock product FOR UPDATE
    SELECT * INTO v_product FROM public.products WHERE id = p_product_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'PRODUCT_NOT_FOUND: El producto solicitado no existe.';
    END IF;

    IF NOT v_product.active THEN
        RAISE EXCEPTION 'PRODUCT_INACTIVE: El producto no está disponible.';
    END IF;

    v_team_id := v_product.team_id;

    -- Validate that team is active
    SELECT status INTO v_team_status FROM public.teams WHERE id = v_team_id;
    IF v_team_status != 'active' THEN
        RAISE EXCEPTION 'El equipo se encuentra inactivo y no permite canjes de premios.' USING ERRCODE = '42501';
    END IF;

    IF v_product.valid_until IS NOT NULL AND NOW() > v_product.valid_until THEN
        RAISE EXCEPTION 'PRODUCT_EXPIRED: La oferta de este premio ha expirado.';
    END IF;

    IF v_product.stock <= 0 THEN
        RAISE EXCEPTION 'OUT_OF_STOCK: El producto está agotado.';
    END IF;

    -- 3. Dynamic Risk Thresholds
    FOR v_setting_record IN SELECT key, value FROM public.risk_settings LOOP
        IF v_setting_record.key = 'high_value_product_pearls' THEN
            v_high_val_pearls := (v_setting_record.value#>>'{}')::int;
        ELSIF v_setting_record.key = 'min_account_age_days' THEN
            v_min_age_days := (v_setting_record.value#>>'{}')::int;
        ELSIF v_setting_record.key = 'min_trivias_completed' THEN
            v_min_trivias := (v_setting_record.value#>>'{}')::int;
        END IF;
    END LOOP;

    IF v_product.cost_pearls >= v_high_val_pearls THEN
        SELECT * INTO v_profile FROM public.profiles WHERE id = v_fan_id;
        v_account_age_days := EXTRACT(DAY FROM (NOW() - v_profile.created_at));

        SELECT COUNT(DISTINCT trivia_id) INTO v_trivias_completed
        FROM public.trivia_attempts
        WHERE fan_id = v_fan_id AND submitted_at IS NOT NULL;

        IF v_account_age_days < v_min_age_days OR v_trivias_completed < v_min_trivias THEN
            RAISE EXCEPTION 'ACCOUNT_TOO_NEW: Para canjear premios de alto valor debes tener al menos % días registrado y % trivias completadas.', v_min_age_days, v_min_trivias;
        END IF;
    END IF;

    -- 4. Lock team wallet FOR UPDATE
    SELECT * INTO v_wallet 
    FROM public.wallets 
    WHERE fan_id = v_fan_id AND team_id = v_team_id 
    FOR UPDATE;

    IF NOT FOUND OR v_wallet.balance_cache < v_product.cost_pearls THEN
        RAISE EXCEPTION 'INSUFFICIENT_PERLITAS: Saldo insuficiente de perlitas de este equipo (Requerido: %, Disponible: %).',
            v_product.cost_pearls, COALESCE(v_wallet.balance_cache, 0);
    END IF;

    -- 5. Generate secure redemption QR hash
    v_redemption_id := gen_random_uuid();
    v_expires_at := NOW() + INTERVAL '30 days';

    SELECT value#>>'{}' INTO v_hmac_secret
    FROM public.risk_settings
    WHERE key = 'qr_hmac_secret';

    IF v_hmac_secret IS NULL OR trim(v_hmac_secret) = '' THEN
        v_hmac_secret := 'guaiqueries_production_vault_secret_key_2026';
    END IF;

    v_raw_code := v_redemption_id::text || ':' || v_fan_id::text || ':' || v_expires_at::text;
    v_code_hash := encode(extensions.hmac(v_raw_code::bytea, v_hmac_secret::bytea, 'sha256'), 'hex');

    -- 6. Insert Redemptions
    INSERT INTO public.redemptions (
        id, team_id, fan_id, product_id, cost_pearls, status,
        code_hash, expires_at, idempotency_key, variant, created_at
    ) VALUES (
        v_redemption_id, v_team_id, v_fan_id, v_product.id, v_product.cost_pearls, 'pending',
        v_code_hash, v_expires_at, p_idempotency_key, p_variant, NOW()
    );

    -- 7. Insert Ledger Entry
    INSERT INTO public.ledger_entries (
        fan_id, team_id, amount, type, status, source_type, source_id, note
    ) VALUES (
        v_fan_id, v_team_id, -v_product.cost_pearls, 'product_redemption', 'confirmed', 'redemption', v_redemption_id::text,
        'Canje de producto: ' || v_product.name
    );

    -- 8. Deduct Pearl Balance from Team Wallet
    UPDATE public.wallets
    SET balance_cache = balance_cache - v_product.cost_pearls, updated_at = NOW()
    WHERE fan_id = v_fan_id AND team_id = v_team_id;

    -- 9. Decrement stock
    UPDATE public.products
    SET stock = stock - 1, updated_at = NOW()
    WHERE id = v_product.id;

    -- 10. Audit log & redemption history
    INSERT INTO public.redemption_history (redemption_id, previous_status, new_status, changed_by, note)
    VALUES (v_redemption_id, NULL, 'pending', v_fan_id, 'Canje iniciado por el fanático');

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_fan_id, 'create_redemption', 'redemptions', v_redemption_id::text,
        jsonb_build_object('team_id', v_team_id, 'product_id', v_product.id, 'cost_pearls', v_product.cost_pearls)
    );

    RETURN jsonb_build_object(
        'redemption_id', v_redemption_id,
        'team_id', v_team_id,
        'code_hash', v_code_hash,
        'status', 'pending',
        'cost_pearls', v_product.cost_pearls,
        'expires_at', v_expires_at,
        'reused', false
    );
END;
$function$;

-- ----------------------------------------------------------------------------
-- 7. RPC cancel_redemption (Refunds to the product's team wallet)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cancel_redemption(p_redemption_id UUID, p_reason TEXT DEFAULT 'Cancelado por el usuario'::TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_actor_id UUID := auth.uid();
    v_redemption public.redemptions%ROWTYPE;
    v_is_owner BOOLEAN;
BEGIN
    IF v_actor_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_redemption FROM public.redemptions WHERE id = p_redemption_id FOR UPDATE;
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
        IF NOT public.is_staff_or_admin(v_actor_id) THEN
            RAISE EXCEPTION 'No tienes permisos para cancelar este canje.' USING ERRCODE = '42501';
        END IF;
        IF NOT public.is_platform_admin(v_actor_id) THEN
            IF public.current_staff_team_id() != v_redemption.team_id THEN
                RAISE EXCEPTION 'No puedes cancelar canjes pertenecientes a otro club.' USING ERRCODE = '42501';
            END IF;
        END IF;
        IF v_redemption.status IN ('delivered', 'completed', 'cancelled', 'rejected') THEN
            RAISE EXCEPTION 'No se puede cancelar un canje en estado %', v_redemption.status;
        END IF;
    END IF;

    UPDATE public.redemptions SET status = 'cancelled' WHERE id = v_redemption.id;

    -- Reembolso al libro contable con el team_id correspondiente
    INSERT INTO public.ledger_entries (
        fan_id, team_id, amount, type, status, source_type, source_id, note, created_by
    ) VALUES (
        v_redemption.fan_id, v_redemption.team_id, v_redemption.cost_pearls, 'refund', 'confirmed',
        'redemption', v_redemption.id::text,
        'Reembolso por cancelación de canje: ' || COALESCE(p_reason, 'Sin motivo'),
        v_actor_id
    );

    -- Reembolso al wallet del equipo correspondiente
    INSERT INTO public.wallets (fan_id, team_id, balance_cache, updated_at)
    VALUES (v_redemption.fan_id, v_redemption.team_id, v_redemption.cost_pearls, NOW())
    ON CONFLICT (fan_id, team_id)
    DO UPDATE SET balance_cache = public.wallets.balance_cache + v_redemption.cost_pearls, updated_at = NOW();

    -- Reposición de inventario
    UPDATE public.products SET stock = stock + 1 WHERE id = v_redemption.product_id;

    INSERT INTO public.redemption_history (redemption_id, previous_status, new_status, changed_by, note)
    VALUES (v_redemption.id, v_redemption.status, 'cancelled', v_actor_id, COALESCE(p_reason, 'Cancelado'));

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        v_actor_id, 'cancel_redemption', 'redemptions', v_redemption.id::text,
        jsonb_build_object('status', v_redemption.status, 'cost_pearls', v_redemption.cost_pearls, 'team_id', v_redemption.team_id),
        jsonb_build_object('status', 'cancelled', 'reason', p_reason, 'refunded_pearls', v_redemption.cost_pearls, 'team_id', v_redemption.team_id)
    );

    RETURN jsonb_build_object('status', 'cancelled', 'refunded_pearls', v_redemption.cost_pearls, 'team_id', v_redemption.team_id);
END;
$function$;

-- ----------------------------------------------------------------------------
-- 8. RPC claim_birthday_bonus(p_team_id) (Once per year and team)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.claim_birthday_bonus(p_team_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_user_id UUID;
    v_profile public.profiles%ROWTYPE;
    v_card JSONB;
    v_bonus INT;
    v_cur_year INT;
    v_ref_id TEXT;
    v_entry_id UUID;
    v_team_status public.team_status;
BEGIN
    v_user_id := public.assert_active_verified_fan();

    IF p_team_id IS NULL THEN
        RAISE EXCEPTION 'El identificador del equipo es obligatorio.';
    END IF;

    PERFORM public.check_rate_limit(v_user_id, 'claim_birthday_bonus', 3, 60);

    -- Validar que el equipo exista y esté activo
    SELECT status INTO v_team_status FROM public.teams WHERE id = p_team_id;
    IF NOT FOUND OR v_team_status != 'active' THEN
        RAISE EXCEPTION 'El equipo especificado no se encuentra activo.' USING ERRCODE = '42501';
    END IF;

    -- Validar que el fanático siga al equipo
    IF NOT EXISTS (
        SELECT 1 FROM public.team_follows
        WHERE user_id = v_user_id AND team_id = p_team_id
    ) THEN
        RAISE EXCEPTION 'Debes seguir al equipo para reclamar su bono de cumpleaños.' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_profile FROM public.profiles WHERE id = v_user_id;

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

    -- Validación anual por equipo
    v_cur_year := EXTRACT(YEAR FROM (NOW() AT TIME ZONE 'America/Caracas'))::int;
    v_ref_id := 'birthday_bonus_' || v_user_id::text || '_' || p_team_id::text || '_' || v_cur_year::text;

    IF EXISTS (
        SELECT 1 FROM public.ledger_entries
        WHERE fan_id = v_user_id AND team_id = p_team_id AND source_type = 'birthday_bonus' AND source_id = v_ref_id
    ) THEN
        RETURN jsonb_build_object('success', true, 'message', 'El bono de cumpleaños ya fue reclamado para este equipo este año.', 'already_claimed', true);
    END IF;

    -- Inserción en el libro y wallet del equipo
    INSERT INTO public.ledger_entries (fan_id, team_id, amount, type, status, source_type, source_id, note)
    VALUES (
        v_user_id, p_team_id, v_bonus, 'birthday_bonus', 'confirmed',
        'birthday_bonus', v_ref_id, 'Bono de Cumpleaños ' || v_cur_year::text
    )
    RETURNING id INTO v_entry_id;

    INSERT INTO public.wallets (fan_id, team_id, balance_cache, updated_at)
    VALUES (v_user_id, p_team_id, v_bonus, NOW())
    ON CONFLICT (fan_id, team_id)
    DO UPDATE SET balance_cache = public.wallets.balance_cache + v_bonus, updated_at = NOW();

    RETURN jsonb_build_object(
        'success', true,
        'team_id', p_team_id,
        'bonus_awarded', v_bonus,
        'entry_id', v_entry_id,
        'message', '¡Feliz Cumpleaños! Tus perlitas han sido acreditadas a tu billetera del equipo.'
    );
END;
$function$;

-- ----------------------------------------------------------------------------
-- 9. RPC admin_adjust_pearls (Scoped by club team)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_adjust_pearls(
    p_fan_id UUID,
    p_amount INTEGER,
    p_reason TEXT,
    p_team_id UUID DEFAULT NULL::UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_is_platform_admin BOOLEAN := public.is_platform_admin(v_admin_id);
    v_staff_team_id UUID := public.current_staff_team_id();
    v_team_id UUID;
    v_old_balance INT := 0;
    v_new_balance INT;
BEGIN
    PERFORM public.assert_admin();

    IF p_reason IS NULL OR trim(p_reason) = '' THEN
        RAISE EXCEPTION 'Mandatory justification reason required for manual pearl adjustment.';
    END IF;

    IF v_is_platform_admin THEN
        v_team_id := COALESCE(p_team_id, 'a0000000-0000-0000-0000-000000000001'::uuid);
    ELSE
        IF v_staff_team_id IS NULL THEN
            RAISE EXCEPTION 'Club admin must belong to an active team.' USING ERRCODE = '42501';
        END IF;
        IF p_team_id IS NOT NULL AND p_team_id != v_staff_team_id THEN
            RAISE EXCEPTION 'No tienes autorización para ajustar perlitas de otro equipo.' USING ERRCODE = '42501';
        END IF;
        v_team_id := v_staff_team_id;
    END IF;

    SELECT balance_cache INTO v_old_balance 
    FROM public.wallets 
    WHERE fan_id = p_fan_id AND team_id = v_team_id 
    FOR UPDATE;

    v_old_balance := COALESCE(v_old_balance, 0);
    v_new_balance := v_old_balance + p_amount;

    IF v_new_balance < 0 THEN
        RAISE EXCEPTION 'Adjustment would result in negative balance for this team (Current: %, Adjustment: %).', v_old_balance, p_amount;
    END IF;

    INSERT INTO public.ledger_entries (
        fan_id, team_id, amount, type, status, source_type, source_id, note, created_by
    ) VALUES (
        p_fan_id, v_team_id, p_amount, 'admin_adjustment', 'confirmed', 'admin', gen_random_uuid()::text,
        p_reason, v_admin_id
    );

    INSERT INTO public.wallets (fan_id, team_id, balance_cache, updated_at)
    VALUES (p_fan_id, v_team_id, v_new_balance, NOW())
    ON CONFLICT (fan_id, team_id) 
    DO UPDATE SET balance_cache = v_new_balance, updated_at = NOW();

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, before, after)
    VALUES (
        v_admin_id, 'admin_adjust_pearls', 'wallets', p_fan_id::text,
        jsonb_build_object('team_id', v_team_id, 'balance', v_old_balance),
        jsonb_build_object('team_id', v_team_id, 'balance', v_new_balance, 'adjustment', p_amount, 'reason', p_reason)
    );

    RETURN jsonb_build_object(
        'fan_id', p_fan_id,
        'team_id', v_team_id,
        'old_balance', v_old_balance,
        'new_balance', v_new_balance,
        'adjustment', p_amount
    );
END;
$function$;

-- ----------------------------------------------------------------------------
-- 10. RPCs admin_release_held_pearls & admin_revoke_held_pearls (Scoped by team)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_release_held_pearls(p_ledger_id UUID, p_note TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_is_platform_admin BOOLEAN := public.is_platform_admin(v_admin_id);
    v_staff_team_id UUID := public.current_staff_team_id();
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

    IF NOT v_is_platform_admin THEN
        IF v_staff_team_id IS NULL OR v_entry.team_id != v_staff_team_id THEN
            RAISE EXCEPTION 'No tienes autorización para liberar perlitas de otro equipo.' USING ERRCODE = '42501';
        END IF;
    END IF;

    IF v_entry.status != 'held' THEN
        RAISE EXCEPTION 'El registro no se encuentra en estado retenido (held).';
    END IF;

    IF EXISTS (SELECT 1 FROM public.ledger_hold_resolutions WHERE ledger_id = p_ledger_id) THEN
        RAISE EXCEPTION 'El registro retenido ya ha sido resuelto previamente (liberado o revocado).';
    END IF;

    INSERT INTO public.ledger_hold_resolutions (
        ledger_id, team_id, action, note, resolved_by
    ) VALUES (
        p_ledger_id, v_entry.team_id, 'release', p_note, v_admin_id
    );

    INSERT INTO public.ledger_entries (
        id, fan_id, team_id, amount, type, status, source_type, source_id, note
    ) VALUES (
        v_release_entry_id, v_entry.fan_id, v_entry.team_id, v_entry.amount, v_entry.type, 'confirmed', 'hold_release', p_ledger_id::text,
        'Liberado por admin: ' || p_note
    );

    INSERT INTO public.wallets (fan_id, team_id, balance_cache, updated_at)
    VALUES (v_entry.fan_id, v_entry.team_id, v_entry.amount, NOW())
    ON CONFLICT (fan_id, team_id)
    DO UPDATE SET balance_cache = public.wallets.balance_cache + v_entry.amount, updated_at = NOW();

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'release_held_pearls', 'ledger_entries', p_ledger_id::text,
        jsonb_build_object('fan_id', v_entry.fan_id, 'team_id', v_entry.team_id, 'amount', v_entry.amount, 'note', p_note, 'release_entry_id', v_release_entry_id)
    );

    RETURN jsonb_build_object(
        'status', 'released',
        'ledger_id', p_ledger_id,
        'team_id', v_entry.team_id,
        'release_entry_id', v_release_entry_id,
        'amount', v_entry.amount
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_revoke_held_pearls(p_ledger_id UUID, p_note TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_is_platform_admin BOOLEAN := public.is_platform_admin(v_admin_id);
    v_staff_team_id UUID := public.current_staff_team_id();
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

    IF NOT v_is_platform_admin THEN
        IF v_staff_team_id IS NULL OR v_entry.team_id != v_staff_team_id THEN
            RAISE EXCEPTION 'No tienes autorización para revocar perlitas de otro equipo.' USING ERRCODE = '42501';
        END IF;
    END IF;

    IF v_entry.status != 'held' THEN
        RAISE EXCEPTION 'El registro no se encuentra en estado retenido (held).';
    END IF;

    IF EXISTS (SELECT 1 FROM public.ledger_hold_resolutions WHERE ledger_id = p_ledger_id) THEN
        RAISE EXCEPTION 'El registro retenido ya ha sido resuelto previamente (liberado o revocado).';
    END IF;

    INSERT INTO public.ledger_hold_resolutions (
        ledger_id, team_id, action, note, resolved_by
    ) VALUES (
        p_ledger_id, v_entry.team_id, 'revoke', p_note, v_admin_id
    );

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'revoke_held_pearls', 'ledger_entries', p_ledger_id::text,
        jsonb_build_object('fan_id', v_entry.fan_id, 'team_id', v_entry.team_id, 'amount', v_entry.amount, 'note', p_note)
    );

    RETURN jsonb_build_object(
        'status', 'revoked',
        'ledger_id', p_ledger_id,
        'team_id', v_entry.team_id,
        'amount', v_entry.amount
    );
END;
$function$;

-- ----------------------------------------------------------------------------
-- 11. RPC reconcile_wallets() (Validates by fan_id and team_id)
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.reconcile_wallets();
CREATE OR REPLACE FUNCTION public.reconcile_wallets()
RETURNS TABLE(
    fan_id UUID,
    team_id UUID,
    balance_cache INTEGER,
    computed_balance INTEGER,
    difference INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_actor_id UUID := auth.uid();
BEGIN
    IF v_actor_id IS NOT NULL THEN
        PERFORM public.assert_platform_admin();
    END IF;

    RETURN QUERY
    SELECT 
        w.fan_id,
        w.team_id,
        w.balance_cache,
        COALESCE(SUM(l.amount)::INT, 0) AS computed_balance,
        (w.balance_cache - COALESCE(SUM(l.amount)::INT, 0)) AS difference
    FROM public.wallets w
    LEFT JOIN public.ledger_entries l 
      ON l.fan_id = w.fan_id AND l.team_id = w.team_id AND l.status = 'confirmed'
    GROUP BY w.fan_id, w.team_id, w.balance_cache
    HAVING (w.balance_cache - COALESCE(SUM(l.amount)::INT, 0)) != 0;
END;
$function$;

-- ----------------------------------------------------------------------------
-- 12. claim_video_points (Transitory grant to Team #1)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.claim_video_points(p_video_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_uid UUID;
    v_today DATE := (NOW() AT TIME ZONE 'America/Caracas')::date;
    v_completed_count INT := 0;
    v_is_block_completed BOOLEAN := false;
    v_block_number INT := NULL;
    v_points_to_award INT := 0;
    v_new_balance INT := 0;
    v_ledger_id UUID := gen_random_uuid();
    v_source_id TEXT;
    v_video RECORD;
    -- TRANSITORIO Fase 5: reemplazar por pending_pearl_grants
    v_team_id UUID := 'a0000000-0000-0000-0000-000000000001'::uuid;
BEGIN
    v_uid := public.assert_active_verified_fan();

    IF p_video_id IS NULL THEN
        RAISE EXCEPTION 'p_video_id is required.';
    END IF;

    SELECT id, is_active INTO v_video
    FROM public.sponsor_videos
    WHERE id = p_video_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El video de patrocinador no existe.';
    END IF;

    IF NOT v_video.is_active THEN
        RAISE EXCEPTION 'El video seleccionado no se encuentra activo.';
    END IF;

    SELECT COALESCE(completed_today, 0) INTO v_completed_count
    FROM public.ad_daily_progress
    WHERE user_id = v_uid AND day = v_today;

    IF v_completed_count >= 50 THEN
        RETURN jsonb_build_object(
            'success', false,
            'completed_today', v_completed_count,
            'message', 'Has alcanzado el límite máximo diario de 50 videos.'
        );
    END IF;

    INSERT INTO public.ad_daily_progress (user_id, day, completed_today, blocks_paid, updated_at)
    VALUES (v_uid, v_today, 1, 0, NOW())
    ON CONFLICT (user_id, day) DO UPDATE
    SET completed_today = ad_daily_progress.completed_today + 1,
        updated_at = NOW()
    RETURNING completed_today INTO v_completed_count;

    IF v_completed_count % 10 = 0 THEN
        v_block_number := v_completed_count / 10;
        v_is_block_completed := true;

        IF v_block_number = 1 THEN
            v_points_to_award := 5;
        ELSIF v_block_number = 2 THEN
            v_points_to_award := 10;
        ELSE
            v_points_to_award := 15;
        END IF;

        v_source_id := 'video_block:' || v_uid::text || ':' || v_today::text || ':' || v_block_number::text;

        -- TRANSITORIO Fase 5: reemplazar por pending_pearl_grants
        INSERT INTO public.ledger_entries (
            id, fan_id, team_id, amount, type, status, source_type, source_id, note
        ) VALUES (
            v_ledger_id, v_uid, v_team_id, v_points_to_award, 'ad_reward', 'confirmed', 'sponsor_video_block', v_source_id,
            'Puntos por completar bloque #' || v_block_number::text || ' de 10 videos patrocinados'
        );

        INSERT INTO public.wallets (fan_id, team_id, balance_cache, updated_at)
        VALUES (v_uid, v_team_id, v_points_to_award, NOW())
        ON CONFLICT (fan_id, team_id)
        DO UPDATE SET balance_cache = public.wallets.balance_cache + v_points_to_award, updated_at = NOW()
        RETURNING balance_cache INTO v_new_balance;

        UPDATE public.ad_daily_progress
        SET blocks_paid = v_block_number, updated_at = NOW()
        WHERE user_id = v_uid AND day = v_today;
    ELSE
        SELECT COALESCE(balance_cache, 0) INTO v_new_balance 
        FROM public.wallets 
        WHERE fan_id = v_uid AND team_id = v_team_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'team_id', v_team_id,
        'completed_today', v_completed_count,
        'block_completed', v_is_block_completed,
        'block_number', COALESCE(v_block_number, (v_completed_count / 10) + 1),
        'points_awarded', v_points_to_award,
        'balance', COALESCE(v_new_balance, 0),
        'block_progress', v_completed_count % 10,
        'videos_until_next_block', CASE WHEN v_completed_count >= 50 THEN 0 ELSE 10 - (v_completed_count % 10) END,
        'daily_limit', 50
    );
END;
$function$;

-- ----------------------------------------------------------------------------
-- 13. Scope admin_list_fans, admin_get_fan, and analytics_economy by team
-- ----------------------------------------------------------------------------

-- 13.1 admin_list_fans (Club admin lists followers of their club; platform lists all)
CREATE OR REPLACE FUNCTION public.admin_list_fans(
    p_municipality TEXT DEFAULT NULL::TEXT,
    p_age_min INTEGER DEFAULT NULL::INTEGER,
    p_age_max INTEGER DEFAULT NULL::INTEGER,
    p_favorite_player_id UUID DEFAULT NULL::UUID,
    p_inactive_days INTEGER DEFAULT NULL::INTEGER,
    p_status public.user_status DEFAULT NULL::public.user_status,
    p_search TEXT DEFAULT NULL::TEXT,
    p_limit INTEGER DEFAULT 20,
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
            CASE 
                WHEN v_is_platform_admin THEN (
                    SELECT COALESCE(SUM(balance_cache), 0) FROM public.wallets WHERE fan_id = p.id
                )
                ELSE (
                    SELECT COALESCE(balance_cache, 0) FROM public.wallets WHERE fan_id = p.id AND team_id = v_staff_team_id
                )
            END AS pearl_balance,
            COALESCE(
                (SELECT MAX(started_at) FROM public.trivia_attempts WHERE fan_id = p.id),
                p.created_at
            ) AS last_active
        FROM public.profiles p
        WHERE 
            (v_is_platform_admin OR EXISTS (
                SELECT 1 FROM public.team_follows tf
                WHERE tf.user_id = p.id AND tf.team_id = v_staff_team_id
            ))
            AND (p_municipality IS NULL OR p.municipality = p_municipality)
            AND (p_favorite_player_id IS NULL OR p.favorite_player_id = p_favorite_player_id)
            AND (p_status IS NULL OR p.status = p_status)
            AND (
                p_search IS NULL OR p_search = '' 
                OR p.display_name ILIKE '%' || p_search || '%'
                OR p.id::text ILIKE '%' || p_search || '%'
            )
            AND (
                p_age_min IS NULL 
                OR p.birth_date <= (CURRENT_DATE - (p_age_min * INTERVAL '1 year'))
            )
            AND (
                p_age_max IS NULL 
                OR p.birth_date >= (CURRENT_DATE - ((p_age_max + 1) * INTERVAL '1 year'))
            )
            AND (p_cursor IS NULL OR p.id > p_cursor)
    )
    SELECT jsonb_build_object(
        'fans', COALESCE(jsonb_agg(to_jsonb(sub)), '[]'::jsonb),
        'next_cursor', (SELECT id FROM filtered_fans ORDER BY id ASC LIMIT 1 OFFSET LEAST(GREATEST(p_limit, 1), 100) - 1)
    ) INTO v_res
    FROM (
        SELECT * FROM filtered_fans
        WHERE (
            p_inactive_days IS NULL 
            OR last_active < (NOW() - (p_inactive_days * INTERVAL '1 day'))
        )
        ORDER BY id ASC
        LIMIT LEAST(GREATEST(p_limit, 1), 100)
    ) sub;

    RETURN v_res;
END;
$function$;

-- 13.2 admin_get_fan (Club admin views follower profile & club-specific balance/history)
CREATE OR REPLACE FUNCTION public.admin_get_fan(p_fan_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_is_platform_admin BOOLEAN := public.is_platform_admin(v_caller_id);
    v_staff_team_id UUID := public.current_staff_team_id();
    v_profile RECORD;
    v_balance INT := 0;
    v_trivias JSONB;
    v_redemptions JSONB;
BEGIN
    PERFORM public.assert_admin();

    IF NOT v_is_platform_admin THEN
        IF v_staff_team_id IS NULL THEN
            RAISE EXCEPTION 'Club admin must belong to an active team.' USING ERRCODE = '42501';
        END IF;

        -- Validate that the fan follows this club
        IF NOT EXISTS (
            SELECT 1 FROM public.team_follows
            WHERE user_id = p_fan_id AND team_id = v_staff_team_id
        ) THEN
            RAISE EXCEPTION 'El fanático solicitado no sigue a tu equipo.' USING ERRCODE = '42501';
        END IF;
    END IF;

    SELECT p.*, pl.name AS favorite_player_name
    INTO v_profile
    FROM public.profiles p
    LEFT JOIN public.players pl ON pl.id = p.favorite_player_id
    WHERE p.id = p_fan_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Perfil de fanático no encontrado.';
    END IF;

    IF v_is_platform_admin THEN
        SELECT COALESCE(SUM(balance_cache), 0) INTO v_balance FROM public.wallets WHERE fan_id = p_fan_id;
    ELSE
        SELECT COALESCE(balance_cache, 0) INTO v_balance FROM public.wallets WHERE fan_id = p_fan_id AND team_id = v_staff_team_id;
    END IF;

    SELECT COALESCE(jsonb_agg(to_jsonb(ta)), '[]'::jsonb)
    INTO v_trivias
    FROM (
        SELECT ta.id, t.title AS trivia_title, ta.score, ta.pearls_awarded, ta.submitted_at
        FROM public.trivia_attempts ta
        JOIN public.trivias t ON t.id = ta.trivia_id
        WHERE ta.fan_id = p_fan_id AND ta.submitted_at IS NOT NULL
          AND (v_is_platform_admin OR t.team_id = v_staff_team_id)
        ORDER BY ta.submitted_at DESC
        LIMIT 10
    ) ta;

    SELECT COALESCE(jsonb_agg(to_jsonb(r)), '[]'::jsonb)
    INTO v_redemptions
    FROM (
        SELECT r.id, pr.name AS product_name, r.cost_pearls, r.status, r.created_at
        FROM public.redemptions r
        JOIN public.products pr ON pr.id = r.product_id
        WHERE r.fan_id = p_fan_id
          AND (v_is_platform_admin OR r.team_id = v_staff_team_id)
        ORDER BY r.created_at DESC
        LIMIT 10
    ) r;

    RETURN jsonb_build_object(
        'profile', to_jsonb(v_profile),
        'pearl_balance', COALESCE(v_balance, 0),
        'recent_trivias', v_trivias,
        'recent_redemptions', v_redemptions
    );
END;
$function$;

-- 13.3 analytics_economy (Scoped by team)
CREATE OR REPLACE FUNCTION public.analytics_economy(p_team_id UUID DEFAULT NULL::UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_is_platform_admin BOOLEAN := public.is_platform_admin(v_caller_id);
    v_staff_team_id UUID := public.current_staff_team_id();
    v_target_team_id UUID;
    v_total_issued BIGINT := 0;
    v_total_spent BIGINT := 0;
    v_total_in_circulation BIGINT := 0;
    v_total_held BIGINT := 0;
    v_min_product_cost INT := 0;
    v_max_product_cost INT := 0;
    v_avg_daily_earnings_per_fan NUMERIC := 0;
    v_days_for_cheapest NUMERIC := 0;
    v_days_for_most_expensive NUMERIC := 0;
BEGIN
    PERFORM public.assert_admin();

    IF v_is_platform_admin THEN
        v_target_team_id := p_team_id;
    ELSE
        IF v_staff_team_id IS NULL THEN
            RAISE EXCEPTION 'Club admin must belong to an active team.' USING ERRCODE = '42501';
        END IF;
        IF p_team_id IS NOT NULL AND p_team_id != v_staff_team_id THEN
            RAISE EXCEPTION 'No tienes autorización para consultar analítica de otro equipo.' USING ERRCODE = '42501';
        END IF;
        v_target_team_id := v_staff_team_id;
    END IF;

    SELECT 
        COALESCE(SUM(CASE WHEN amount > 0 AND status = 'confirmed' THEN amount ELSE 0 END), 0),
        COALESCE(ABS(SUM(CASE WHEN amount < 0 AND status = 'confirmed' THEN amount ELSE 0 END)), 0),
        COALESCE(SUM(CASE WHEN status = 'held' THEN amount ELSE 0 END), 0)
    INTO v_total_issued, v_total_spent, v_total_held
    FROM public.ledger_entries
    WHERE (v_target_team_id IS NULL OR team_id = v_target_team_id);

    SELECT COALESCE(SUM(balance_cache), 0)
    INTO v_total_in_circulation
    FROM public.wallets
    WHERE (v_target_team_id IS NULL OR team_id = v_target_team_id);

    SELECT MIN(cost_pearls), MAX(cost_pearls)
    INTO v_min_product_cost, v_max_product_cost
    FROM public.products
    WHERE active = true AND (v_target_team_id IS NULL OR team_id = v_target_team_id);

    SELECT ROUND(AVG(daily_earned)::NUMERIC, 1)
    INTO v_avg_daily_earnings_per_fan
    FROM (
        SELECT fan_id, SUM(amount) / NULLIF(COUNT(DISTINCT (created_at AT TIME ZONE 'America/Caracas')::date), 0)::NUMERIC AS daily_earned
        FROM public.ledger_entries
        WHERE amount > 0 AND status = 'confirmed'
          AND created_at >= (NOW() - INTERVAL '30 days')
          AND (v_target_team_id IS NULL OR team_id = v_target_team_id)
        GROUP BY fan_id
    ) sub;

    IF v_avg_daily_earnings_per_fan > 0 THEN
        v_days_for_cheapest := ROUND((COALESCE(v_min_product_cost, 0) / v_avg_daily_earnings_per_fan)::NUMERIC, 1);
        v_days_for_most_expensive := ROUND((COALESCE(v_max_product_cost, 0) / v_avg_daily_earnings_per_fan)::NUMERIC, 1);
    END IF;

    RETURN jsonb_build_object(
        'team_id', v_target_team_id,
        'total_issued', COALESCE(v_total_issued, 0),
        'total_spent', COALESCE(v_total_spent, 0),
        'total_in_circulation', COALESCE(v_total_in_circulation, 0),
        'total_held', COALESCE(v_total_held, 0),
        'min_product_cost', COALESCE(v_min_product_cost, 0),
        'max_product_cost', COALESCE(v_max_product_cost, 0),
        'avg_daily_earnings_per_fan', COALESCE(v_avg_daily_earnings_per_fan, 0),
        'days_for_cheapest_product', COALESCE(v_days_for_cheapest, 0),
        'days_for_most_expensive_product', COALESCE(v_days_for_most_expensive, 0)
    );
END;
$function$;

-- ----------------------------------------------------------------------------
-- 14. Permisos de Ejecución
-- ----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.get_wallet_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_wallet_summary() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.wallet_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.wallet_summary() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.wallet_ledger(UUID, TEXT, TIMESTAMPTZ, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.wallet_ledger(UUID, TEXT, TIMESTAMPTZ, INTEGER) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.submit_trivia_attempt(UUID, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_trivia_attempt(UUID, JSONB) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.redeem_product(UUID, TEXT, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.redeem_product(UUID, TEXT, JSONB) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.cancel_redemption(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_redemption(UUID, TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.claim_birthday_bonus(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_birthday_bonus(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_adjust_pearls(UUID, INTEGER, TEXT, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_adjust_pearls(UUID, INTEGER, TEXT, UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_release_held_pearls(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_release_held_pearls(UUID, TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_revoke_held_pearls(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_revoke_held_pearls(UUID, TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.reconcile_wallets() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reconcile_wallets() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.claim_video_points(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_video_points(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.analytics_economy(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.analytics_economy(UUID) TO authenticated, service_role;
