-- ============================================================================
-- Migration: 20261028000011_fase3_trivias_tienda_and_integrity.sql
-- Description: Fase 3 — Trivias, Tienda y Canjes por Equipo (Experiencia del Fan)
--              1. Composite FK on ledger_entries (fan_id, team_id) -> wallets (fan_id, team_id)
--              2. Trigger on ledger_hold_resolutions ensuring team_id coherence
--              3. Multi-team birthday settings (drop id=1 constraint, unique on team_id)
--              4. Multi-team birthday greeting generator, card reader & claiming
--              5. Per-team streak calculation (get_streak_info & calculate_and_apply_streak_bonus)
--              6. home_summary scoped to target team
--              7. Public read policies on trivias & dynamic trivias filtered by active teams
--              8. Composite performance indexes (team_id, status)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Ledger / Wallet Integrity: Composite FK & Coherence Trigger
-- ----------------------------------------------------------------------------

-- Ensure all existing ledger_entries have a corresponding wallet before adding FK
INSERT INTO public.wallets (fan_id, team_id, balance_cache, updated_at)
SELECT DISTINCT le.fan_id, le.team_id, 0, NOW()
FROM public.ledger_entries le
WHERE NOT EXISTS (
    SELECT 1 FROM public.wallets w 
    WHERE w.fan_id = le.fan_id AND w.team_id = le.team_id
)
ON CONFLICT (fan_id, team_id) DO NOTHING;

-- Add composite foreign key constraint from ledger_entries to wallets
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_ledger_entries_wallet'
    ) THEN
        ALTER TABLE public.ledger_entries
        ADD CONSTRAINT fk_ledger_entries_wallet
        FOREIGN KEY (fan_id, team_id)
        REFERENCES public.wallets (fan_id, team_id)
        ON DELETE RESTRICT;
    END IF;
END$$;

-- Trigger on ledger_hold_resolutions to guarantee team_id matches ledger_entries
CREATE OR REPLACE FUNCTION public.validate_hold_resolution_team()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_ledger_team_id UUID;
BEGIN
    SELECT team_id INTO v_ledger_team_id
    FROM public.ledger_entries
    WHERE id = NEW.ledger_id;

    IF v_ledger_team_id IS DISTINCT FROM NEW.team_id THEN
        RAISE EXCEPTION 'ledger_hold_resolutions team_id must match the ledger entry team_id' USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_validate_hold_resolution_team ON public.ledger_hold_resolutions;
CREATE TRIGGER trg_validate_hold_resolution_team
BEFORE INSERT OR UPDATE ON public.ledger_hold_resolutions
FOR EACH ROW EXECUTE FUNCTION public.validate_hold_resolution_team();

-- ----------------------------------------------------------------------------
-- 2. Multi-team Birthday Settings
-- ----------------------------------------------------------------------------

-- Drop single-row check constraint (id = 1)
ALTER TABLE public.birthday_settings DROP CONSTRAINT IF EXISTS birthday_settings_id_check;

-- Create unique index on team_id for birthday_settings
CREATE UNIQUE INDEX IF NOT EXISTS idx_birthday_settings_team_id ON public.birthday_settings(team_id);

-- Ensure default team #1 has birthday settings configured
INSERT INTO public.birthday_settings (id, team_id, enabled, title, message, send_hour, grace_days, bonus_pearls, updated_at)
VALUES (
    1,
    'a0000000-0000-0000-0000-000000000001',
    true,
    '¡Feliz cumpleaños, Guaiquerí!',
    'De parte de toda la familia de Guaiqueríes de Margarita te deseamos un feliz día lleno de baloncesto y pasión.',
    9,
    3,
    100,
    NOW()
)
ON CONFLICT (id) DO UPDATE SET 
    team_id = 'a0000000-0000-0000-0000-000000000001'
WHERE public.birthday_settings.team_id IS NULL;

-- ----------------------------------------------------------------------------
-- 3. Multi-team Birthday Flow (Generator, Card Reader, Test Sender & Claiming)
-- ----------------------------------------------------------------------------

-- 3.1 enqueue_birthday_notifications (Enqueues 1 notification per followed active team with enabled birthday campaign)
CREATE OR REPLACE FUNCTION public.enqueue_birthday_notifications(p_now TIMESTAMPTZ DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_caracas_now TIMESTAMPTZ;
    v_cur_date DATE;
    v_cur_month INT;
    v_cur_day INT;
    v_cur_year INT;
    v_is_leap BOOLEAN;
    v_count INT := 0;
    r RECORD;
BEGIN
    v_caracas_now := COALESCE(p_now, NOW()) AT TIME ZONE 'America/Caracas';
    v_cur_date := v_caracas_now::date;
    v_cur_month := EXTRACT(MONTH FROM v_caracas_now)::int;
    v_cur_day := EXTRACT(DAY FROM v_caracas_now)::int;
    v_cur_year := EXTRACT(YEAR FROM v_caracas_now)::int;

    v_is_leap := (v_cur_year % 4 = 0 AND (v_cur_year % 100 != 0 OR v_cur_year % 400 = 0));

    FOR r IN
        SELECT 
            p.id AS fan_id,
            p.display_name,
            t.id AS team_id,
            t.name AS team_name,
            t.slug AS team_slug,
            bs.title AS greeting_title,
            bs.message AS greeting_message
        FROM public.profiles p
        JOIN auth.users u ON u.id = p.id
        JOIN public.team_follows tf ON tf.user_id = p.id
        JOIN public.teams t ON t.id = tf.team_id AND t.status = 'active'
        JOIN public.birthday_settings bs ON bs.team_id = t.id AND bs.enabled = true
        WHERE p.status = 'active'
          AND p.deleted_at IS NULL
          AND u.email_confirmed_at IS NOT NULL
          AND p.birth_date IS NOT NULL
          AND (
            (EXTRACT(MONTH FROM p.birth_date)::int = v_cur_month AND EXTRACT(DAY FROM p.birth_date)::int = v_cur_day)
            OR
            (NOT v_is_leap AND EXTRACT(MONTH FROM p.birth_date)::int = 2 AND EXTRACT(DAY FROM p.birth_date)::int = 29 AND v_cur_month = 2 AND v_cur_day = 28)
          )
          AND COALESCE((p.notification_prefs->>'birthday')::boolean, true) = true
        LIMIT 1000
    LOOP
        PERFORM public.create_notification(
            r.fan_id,
            'birthday',
            r.team_name || ': ¡Feliz cumpleaños!',
            'Hola ' || COALESCE(r.display_name, 'Fanático') || ', ' || r.team_name || ' tiene un mensaje especial para ti hoy.',
            jsonb_build_object(
                'url', '/app/cumpleanos',
                'team_id', r.team_id,
                'team_slug', r.team_slug
            ),
            'birthday:' || r.fan_id::text || ':' || r.team_id::text || ':' || v_cur_year::text
        );
        v_count := v_count + 1;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'enqueued', v_count, 'caracas_date', v_cur_date);
END;
$function$;

REVOKE ALL ON FUNCTION public.enqueue_birthday_notifications(TIMESTAMPTZ) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.enqueue_birthday_notifications(TIMESTAMPTZ) TO authenticated, service_role;

-- 3.2 get_birthday_card (Multi-team greeting cards for followed active teams)
CREATE OR REPLACE FUNCTION public.get_birthday_card(p_team_id UUID DEFAULT NULL::UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_user_id UUID;
    v_profile public.profiles%ROWTYPE;
    v_caracas_now TIMESTAMPTZ;
    v_cur_date DATE;
    v_cur_year INT;
    v_is_leap BOOLEAN;
    v_bdate DATE;
    v_bmonth INT;
    v_bday INT;
    v_bdate_this_year DATE;
    v_cards JSONB := '[]'::jsonb;
    v_primary_card JSONB := NULL;
    r RECORD;
    v_is_eligible BOOLEAN;
    v_claimed BOOLEAN;
BEGIN
    v_user_id := public.assert_active_verified_fan();

    SELECT * INTO v_profile FROM public.profiles WHERE id = v_user_id;
    IF v_profile.birth_date IS NULL THEN
        RETURN jsonb_build_object('eligible', false, 'cards', '[]'::jsonb);
    END IF;

    v_caracas_now := NOW() AT TIME ZONE 'America/Caracas';
    v_cur_date := v_caracas_now::date;
    v_cur_year := EXTRACT(YEAR FROM v_caracas_now)::int;
    v_is_leap := (v_cur_year % 4 = 0 AND (v_cur_year % 100 != 0 OR v_cur_year % 400 = 0));

    v_bdate := v_profile.birth_date;
    v_bmonth := EXTRACT(MONTH FROM v_bdate)::int;
    v_bday := EXTRACT(DAY FROM v_bdate)::int;

    IF v_bmonth = 2 AND v_bday = 29 AND NOT v_is_leap THEN
        v_bday := 28;
    END IF;

    v_bdate_this_year := (v_cur_year::text || '-' || lpad(v_bmonth::text, 2, '0') || '-' || lpad(v_bday::text, 2, '0'))::date;

    FOR r IN
        SELECT 
            t.id AS team_id,
            t.name AS team_name,
            t.slug AS team_slug,
            t.logo_url AS team_logo,
            t.primary_color,
            bs.title,
            bs.message,
            bs.image_url,
            COALESCE(bs.bonus_pearls, 0) AS bonus_pearls,
            COALESCE(bs.grace_days, 3) AS grace_days
        FROM public.team_follows tf
        JOIN public.teams t ON t.id = tf.team_id AND t.status = 'active'
        JOIN public.birthday_settings bs ON bs.team_id = t.id AND bs.enabled = true
        WHERE tf.user_id = v_user_id
          AND (p_team_id IS NULL OR t.id = p_team_id)
        ORDER BY tf.created_at ASC
    LOOP
        v_is_eligible := (v_cur_date >= v_bdate_this_year AND v_cur_date <= (v_bdate_this_year + (r.grace_days || ' days')::interval));

        IF v_is_eligible THEN
            SELECT EXISTS (
                SELECT 1 FROM public.ledger_entries
                WHERE fan_id = v_user_id
                  AND team_id = r.team_id
                  AND source_type = 'birthday_bonus'
                  AND source_id = 'birthday_bonus_' || v_user_id::text || '_' || r.team_id::text || '_' || v_cur_year::text
            ) INTO v_claimed;

            v_cards := v_cards || jsonb_build_array(jsonb_build_object(
                'team_id', r.team_id,
                'team_name', r.team_name,
                'team_slug', r.team_slug,
                'team_logo', r.team_logo,
                'primary_color', r.primary_color,
                'title', r.title,
                'message', r.message,
                'image_url', r.image_url,
                'bonus_pearls', r.bonus_pearls,
                'claimed', v_claimed,
                'display_name', v_profile.display_name
            ));

            IF v_primary_card IS NULL THEN
                v_primary_card := jsonb_build_object(
                    'eligible', true,
                    'team_id', r.team_id,
                    'team_name', r.team_name,
                    'display_name', v_profile.display_name,
                    'title', r.title,
                    'message', r.message,
                    'image_url', r.image_url,
                    'bonus_pearls', r.bonus_pearls,
                    'claimed', v_claimed
                );
            END IF;
        END IF;
    END LOOP;

    IF jsonb_array_length(v_cards) = 0 THEN
        RETURN jsonb_build_object('eligible', false, 'cards', '[]'::jsonb);
    END IF;

    RETURN v_primary_card || jsonb_build_object('cards', v_cards);
END;
$function$;

REVOKE ALL ON FUNCTION public.get_birthday_card(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_birthday_card(UUID) TO authenticated, service_role;

-- 3.3 send_test_birthday_notification (Scoped by team)
CREATE OR REPLACE FUNCTION public.send_test_birthday_notification(p_team_id UUID DEFAULT NULL::UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_is_platform_admin BOOLEAN := public.is_platform_admin(v_admin_id);
    v_staff_team_id UUID := public.current_staff_team_id();
    v_target_team_id UUID;
    v_team RECORD;
BEGIN
    PERFORM public.assert_admin();

    IF v_is_platform_admin THEN
        v_target_team_id := COALESCE(p_team_id, 'a0000000-0000-0000-0000-000000000001'::uuid);
    ELSE
        IF v_staff_team_id IS NULL THEN
            RAISE EXCEPTION 'Club admin must belong to an active team.' USING ERRCODE = '42501';
        END IF;
        IF p_team_id IS NOT NULL AND p_team_id != v_staff_team_id THEN
            RAISE EXCEPTION 'No tienes autorización para enviar notificaciones de prueba de otro equipo.' USING ERRCODE = '42501';
        END IF;
        v_target_team_id := v_staff_team_id;
    END IF;

    SELECT id, name, slug INTO v_team FROM public.teams WHERE id = v_target_team_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Equipo no encontrado.';
    END IF;

    PERFORM public.create_notification(
        v_admin_id,
        'birthday',
        v_team.name || ': ¡Feliz cumpleaños! (Prueba Admin)',
        'Notificación de prueba del saludo de cumpleaños de ' || v_team.name || '.',
        jsonb_build_object('url', '/app/cumpleanos', 'team_id', v_team.id, 'team_slug', v_team.slug),
        'birthday_test:' || v_admin_id::text || ':' || v_team.id::text || ':' || extract(epoch from now())::text
    );

    RETURN jsonb_build_object('success', true, 'team_id', v_team.id);
END;
$function$;

REVOKE ALL ON FUNCTION public.send_test_birthday_notification(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.send_test_birthday_notification(UUID) TO authenticated, service_role;

-- 3.4 claim_birthday_bonus (Ensures team-specific checking via get_birthday_card(p_team_id))
CREATE OR REPLACE FUNCTION public.claim_birthday_bonus(p_team_id UUID DEFAULT NULL::UUID)
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
    v_target_card JSONB;
    v_elem JSONB;
    v_target_team_id UUID := p_team_id;
BEGIN
    v_user_id := public.assert_active_verified_fan();

    IF v_target_team_id IS NULL THEN
        SELECT tf.team_id INTO v_target_team_id
        FROM public.team_follows tf
        JOIN public.teams t ON t.id = tf.team_id AND t.status = 'active'
        WHERE tf.user_id = v_user_id
        ORDER BY tf.created_at ASC
        LIMIT 1;

        IF v_target_team_id IS NULL THEN
            v_target_team_id := 'a0000000-0000-0000-0000-000000000001'::uuid;
        END IF;
    END IF;

    PERFORM public.check_rate_limit(v_user_id, 'claim_birthday_bonus', 3, 60);

    SELECT status INTO v_team_status FROM public.teams WHERE id = v_target_team_id;
    IF NOT FOUND OR v_team_status != 'active' THEN
        RAISE EXCEPTION 'El equipo especificado no se encuentra activo.' USING ERRCODE = '42501';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.team_follows
        WHERE user_id = v_user_id AND team_id = v_target_team_id
    ) THEN
        RAISE EXCEPTION 'Debes seguir al equipo para reclamar su bono de cumpleaños.' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_profile FROM public.profiles WHERE id = v_user_id;

    IF v_profile.created_at > NOW() - INTERVAL '30 days' THEN
        RAISE EXCEPTION 'El bono de cumpleaños requiere una cuenta con al menos 30 días de antigüedad.';
    END IF;

    v_card := public.get_birthday_card(v_target_team_id);
    IF (v_card->>'eligible')::boolean IS NOT TRUE THEN
        RAISE EXCEPTION 'No eres elegible para reclamar un bono de cumpleaños hoy.';
    END IF;

    -- Extract bonus for target team
    v_bonus := 0;
    IF v_card->'cards' IS NOT NULL AND jsonb_array_length(v_card->'cards') > 0 THEN
        FOR v_elem IN SELECT * FROM jsonb_array_elements(v_card->'cards') LOOP
            IF (v_elem->>'team_id')::uuid = v_target_team_id THEN
                v_target_card := v_elem;
                v_bonus := COALESCE((v_elem->>'bonus_pearls')::int, 0);
                EXIT;
            END IF;
        END LOOP;
    ELSE
        v_bonus := COALESCE((v_card->>'bonus_pearls')::int, 0);
    END IF;

    IF v_bonus <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'La campaña no contempla bono de perlitas.');
    END IF;

    v_cur_year := EXTRACT(YEAR FROM (NOW() AT TIME ZONE 'America/Caracas'))::int;
    v_ref_id := 'birthday_bonus_' || v_user_id::text || '_' || v_target_team_id::text || '_' || v_cur_year::text;

    IF EXISTS (
        SELECT 1 FROM public.ledger_entries
        WHERE fan_id = v_user_id AND team_id = v_target_team_id AND source_type = 'birthday_bonus' AND source_id = v_ref_id
    ) THEN
        RETURN jsonb_build_object(
            'success', true,
            'team_id', v_target_team_id,
            'message', 'El bono de cumpleaños ya fue reclamado para este equipo este año.',
            'already_claimed', true
        );
    END IF;

    -- Ensure wallet exists for (v_user_id, v_target_team_id)
    INSERT INTO public.wallets (fan_id, team_id, balance_cache, updated_at)
    VALUES (v_user_id, v_target_team_id, 0, NOW())
    ON CONFLICT (fan_id, team_id) DO NOTHING;

    -- Immutable ledger entry with foreign key to wallets
    INSERT INTO public.ledger_entries (
        fan_id, team_id, amount, type, status, source_type, source_id, note
    ) VALUES (
        v_user_id, v_target_team_id, v_bonus, 'birthday_bonus', 'confirmed', 'birthday_bonus', v_ref_id,
        'Bono de cumpleaños año ' || v_cur_year::text
    ) RETURNING id INTO v_entry_id;

    -- Update team wallet balance cache
    UPDATE public.wallets
    SET balance_cache = balance_cache + v_bonus,
        updated_at = NOW()
    WHERE fan_id = v_user_id AND team_id = v_target_team_id;

    RETURN jsonb_build_object(
        'success', true,
        'team_id', v_target_team_id,
        'bonus_pearls', v_bonus,
        'ledger_id', v_entry_id
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.claim_birthday_bonus(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_birthday_bonus(UUID) TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 4. Racha por Equipo (streak_days)
-- ----------------------------------------------------------------------------

-- 4.1 get_streak_info (Calculates consecutive trivia days for specific team or primary team)
CREATE OR REPLACE FUNCTION public.get_streak_info(
    p_fan_id UUID,
    p_team_id UUID DEFAULT NULL::UUID
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_today DATE := (NOW() AT TIME ZONE 'America/Caracas')::date;
    v_target_team_id UUID := p_team_id;
    v_already_awarded BOOLEAN := false;
    v_streak_days INT := 0;
    v_day_check DATE;
BEGIN
    IF v_target_team_id IS NULL THEN
        SELECT tf.team_id INTO v_target_team_id
        FROM public.team_follows tf
        JOIN public.teams t ON t.id = tf.team_id AND t.status = 'active'
        WHERE tf.user_id = p_fan_id
        ORDER BY tf.created_at ASC
        LIMIT 1;

        IF v_target_team_id IS NULL THEN
            v_target_team_id := 'a0000000-0000-0000-0000-000000000001'::uuid;
        END IF;
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.ledger_entries
        WHERE fan_id = p_fan_id
          AND team_id = v_target_team_id
          AND type = 'streak_bonus'
          AND (created_at AT TIME ZONE 'America/Caracas')::date = v_today
    ) INTO v_already_awarded;

    v_day_check := v_today;
    LOOP
        IF EXISTS (
            SELECT 1 FROM public.trivia_attempts
            WHERE fan_id = p_fan_id
              AND team_id = v_target_team_id
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
        'team_id', v_target_team_id,
        'streak_days', v_streak_days,
        'already_awarded_today', v_already_awarded
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.get_streak_info(UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_streak_info(UUID, UUID) TO authenticated, service_role;

-- 4.2 calculate_and_apply_streak_bonus (Awards milestone streak bonus for team)
CREATE OR REPLACE FUNCTION public.calculate_and_apply_streak_bonus(
    p_fan_id UUID,
    p_team_id UUID DEFAULT NULL::UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_today DATE := (NOW() AT TIME ZONE 'America/Caracas')::date;
    v_target_team_id UUID := p_team_id;
    v_already_awarded BOOLEAN;
    v_streak_days INT := 0;
    v_day_check DATE;
    v_bonus_amount INT := 0;
    v_source_ref TEXT;
BEGIN
    IF v_target_team_id IS NULL THEN
        SELECT tf.team_id INTO v_target_team_id
        FROM public.team_follows tf
        JOIN public.teams t ON t.id = tf.team_id AND t.status = 'active'
        WHERE tf.user_id = p_fan_id
        ORDER BY tf.created_at ASC
        LIMIT 1;

        IF v_target_team_id IS NULL THEN
            v_target_team_id := 'a0000000-0000-0000-0000-000000000001'::uuid;
        END IF;
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.ledger_entries
        WHERE fan_id = p_fan_id
          AND team_id = v_target_team_id
          AND type = 'streak_bonus'
          AND (created_at AT TIME ZONE 'America/Caracas')::date = v_today
    ) INTO v_already_awarded;

    v_day_check := v_today;
    LOOP
        IF EXISTS (
            SELECT 1 FROM public.trivia_attempts
            WHERE fan_id = p_fan_id
              AND team_id = v_target_team_id
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
        RETURN jsonb_build_object(
            'team_id', v_target_team_id,
            'streak_days', v_streak_days,
            'bonus_awarded', 0,
            'already_awarded_today', true
        );
    END IF;

    -- Award milestone bonus
    IF v_streak_days >= 7 THEN
        v_bonus_amount := 300;
    ELSIF v_streak_days >= 3 THEN
        v_bonus_amount := 100;
    ELSIF v_streak_days >= 1 THEN
        v_bonus_amount := 20;
    END IF;

    IF v_bonus_amount > 0 THEN
        v_source_ref := 'streak_' || v_target_team_id::text || '_' || v_today::text || '_' || v_streak_days::text;

        INSERT INTO public.wallets (fan_id, team_id, balance_cache, updated_at)
        VALUES (p_fan_id, v_target_team_id, 0, NOW())
        ON CONFLICT (fan_id, team_id) DO NOTHING;

        INSERT INTO public.ledger_entries (
            fan_id, team_id, amount, type, status, source_type, source_id, note
        ) VALUES (
            p_fan_id, v_target_team_id, v_bonus_amount, 'streak_bonus', 'confirmed', 'streak', v_source_ref,
            'Bono de racha diaria (' || v_streak_days || ' días consecutivos)'
        ) ON CONFLICT DO NOTHING;

        UPDATE public.wallets
        SET balance_cache = balance_cache + v_bonus_amount,
            updated_at = NOW()
        WHERE fan_id = p_fan_id AND team_id = v_target_team_id;
    END IF;

    RETURN jsonb_build_object(
        'team_id', v_target_team_id,
        'streak_days', v_streak_days,
        'bonus_awarded', v_bonus_amount,
        'already_awarded_today', false
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.calculate_and_apply_streak_bonus(UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.calculate_and_apply_streak_bonus(UUID, UUID) TO authenticated, service_role;

-- 4.3 submit_trivia_attempt: Pass team_id to calculate_and_apply_streak_bonus
CREATE OR REPLACE FUNCTION public.submit_trivia_attempt(p_attempt_id UUID, p_answers JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_fan_id UUID;
    v_attempt public.trivia_attempts%ROWTYPE;
    v_trivia public.trivias%ROWTYPE;
    v_team_id UUID;
    v_team_status public.team_status;
    v_score INT := 0;
    v_total_questions INT := 0;
    v_correct_count INT := 0;
    v_q RECORD;
    v_selected_option_id UUID;
    v_correct_option_id UUID;
    v_is_won BOOLEAN := false;
    v_pearls_reward INT := 0;
    v_final_pearls INT := 0;
    v_entry_status public.ledger_status;
    v_risk_reason TEXT;
    v_is_suspicious BOOLEAN := false;
BEGIN
    v_fan_id := public.assert_active_verified_fan();

    SELECT * INTO v_attempt 
    FROM public.trivia_attempts 
    WHERE id = p_attempt_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Intento de trivia no encontrado.';
    END IF;

    IF v_attempt.fan_id != v_fan_id THEN
        RAISE EXCEPTION 'No tienes autorización para completar este intento.' USING ERRCODE = '42501';
    END IF;

    IF v_attempt.submitted_at IS NOT NULL THEN
        RAISE EXCEPTION 'TRIVIA_ALREADY_PLAYED';
    END IF;

    PERFORM public.check_rate_limit(v_fan_id, 'submit_trivia_attempt', 5, 60);

    SELECT * INTO v_trivia 
    FROM public.trivias 
    WHERE id = v_attempt.trivia_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Trivia no encontrada.';
    END IF;

    v_team_id := v_trivia.team_id;

    SELECT status INTO v_team_status FROM public.teams WHERE id = v_team_id;
    IF NOT FOUND OR v_team_status != 'active' THEN
        RAISE EXCEPTION 'No es posible jugar trivias de un equipo inactivo.' USING ERRCODE = '42501';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.team_follows
        WHERE user_id = v_fan_id AND team_id = v_team_id
    ) THEN
        RAISE EXCEPTION 'Debes seguir al equipo para registrar puntuaciones y ganar perlitas.' USING ERRCODE = '42501';
    END IF;

    FOR v_q IN 
        SELECT tq.id, tq.points 
        FROM public.trivia_questions tq 
        WHERE tq.trivia_id = v_trivia.id 
        ORDER BY tq.order_index ASC 
    LOOP
        v_total_questions := v_total_questions + 1;
        v_selected_option_id := (p_answers->>(v_q.id::text))::uuid;

        SELECT id INTO v_correct_option_id
        FROM public.trivia_options
        WHERE question_id = v_q.id AND is_correct = true;

        IF v_selected_option_id IS NOT NULL AND v_selected_option_id = v_correct_option_id THEN
            v_correct_count := v_correct_count + 1;
            v_score := v_score + v_q.points;
        END IF;
    END LOOP;

    v_is_won := (v_correct_count = v_total_questions AND v_total_questions > 0);

    IF v_is_won THEN
        v_pearls_reward := COALESCE(v_score, 0);

        IF EXISTS (
            SELECT 1 FROM public.trivia_attempts
            WHERE fan_id = v_fan_id 
              AND trivia_id = v_trivia.id 
              AND id != v_attempt.id 
              AND pearls_awarded > 0
        ) THEN
            v_final_pearls := 0;
        ELSE
            v_final_pearls := v_pearls_reward;
        END IF;

        IF v_final_pearls > 0 THEN
            v_is_suspicious := (EXTRACT(EPOCH FROM (NOW() - v_attempt.started_at)) < 3.0);

            IF v_is_suspicious THEN
                v_entry_status := 'held';
                v_risk_reason := 'Respuesta inhumanamente rápida en trivia (< 3s para trivia completa)';

                INSERT INTO public.risk_flags (
                    fan_id, team_id, reason, severity, metadata, created_at
                ) VALUES (
                    v_fan_id, v_team_id, v_risk_reason, 'medium',
                    jsonb_build_object('attempt_id', v_attempt.id, 'time_seconds', EXTRACT(EPOCH FROM (NOW() - v_attempt.started_at))),
                    NOW()
                );
            ELSE
                v_entry_status := 'confirmed';
            END IF;

            INSERT INTO public.wallets (fan_id, team_id, balance_cache, updated_at)
            VALUES (v_fan_id, v_team_id, 0, NOW())
            ON CONFLICT (fan_id, team_id) DO NOTHING;

            INSERT INTO public.ledger_entries (
                fan_id, team_id, amount, type, status, source_type, source_id, note
            ) VALUES (
                v_fan_id, v_team_id, v_final_pearls, 'trivia_reward', v_entry_status, 'trivia_attempt', v_attempt.id::text,
                'Premio por trivia: ' || v_trivia.title
            );

            IF v_entry_status = 'confirmed' THEN
                UPDATE public.wallets
                SET balance_cache = balance_cache + v_final_pearls,
                    updated_at = NOW()
                WHERE fan_id = v_fan_id AND team_id = v_team_id;

                PERFORM public.calculate_and_apply_streak_bonus(v_fan_id, v_team_id);
            END IF;
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

REVOKE ALL ON FUNCTION public.submit_trivia_attempt(UUID, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_trivia_attempt(UUID, JSONB) TO authenticated, service_role;

-- 4.4 home_summary (Scoped to optional target team or primary followed team)
CREATE OR REPLACE FUNCTION public.home_summary(p_team_id UUID DEFAULT NULL::UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid UUID := auth.uid();
    v_target_team_id UUID := p_team_id;
    v_balance INT := 0;
    v_active_trivia JSONB;
    v_streak JSONB;
    v_next_game JSONB;
    v_my_rank INT := NULL;
    v_team_row RECORD;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    IF v_target_team_id IS NULL THEN
        SELECT tf.team_id INTO v_target_team_id
        FROM public.team_follows tf
        JOIN public.teams t ON t.id = tf.team_id AND t.status = 'active'
        WHERE tf.user_id = v_uid
        ORDER BY tf.created_at ASC
        LIMIT 1;

        IF v_target_team_id IS NULL THEN
            v_target_team_id := 'a0000000-0000-0000-0000-000000000001'::uuid;
        END IF;
    END IF;

    SELECT id, name, slug, logo_url, primary_color, secondary_color, status
    INTO v_team_row
    FROM public.teams
    WHERE id = v_target_team_id;

    -- Balance for target team
    SELECT COALESCE(balance_cache, 0) INTO v_balance
    FROM public.wallets
    WHERE fan_id = v_uid AND team_id = v_target_team_id;

    -- Active Trivia for target team
    SELECT jsonb_build_object(
        'id', t.id,
        'team_id', t.team_id,
        'title', t.title,
        'description', t.description,
        'time_limit_seconds', t.time_limit_seconds,
        'starts_at', t.starts_at,
        'ends_at', t.ends_at,
        'max_attempts', t.max_attempts,
        'played', EXISTS (
            SELECT 1 FROM public.trivia_attempts ta 
            WHERE ta.fan_id = v_uid AND ta.trivia_id = t.id AND ta.submitted_at IS NOT NULL AND ta.pearls_awarded > 0
        )
    ) INTO v_active_trivia
    FROM public.trivias t
    WHERE t.status = 'published'
      AND t.team_id = v_target_team_id
      AND NOW() BETWEEN t.starts_at AND t.ends_at
    ORDER BY t.starts_at DESC
    LIMIT 1;

    -- Read-only Streak Calculation for target team
    v_streak := public.get_streak_info(v_uid, v_target_team_id);

    -- Next Game for target team
    SELECT jsonb_build_object(
        'id', g.id,
        'team_id', g.team_id,
        'opponent', g.opponent,
        'opponent_logo_url', g.opponent_logo_url,
        'location', g.location,
        'game_date', g.game_date,
        'is_home', g.is_home,
        'status', g.status
    ) INTO v_next_game
    FROM public.games g
    WHERE g.team_id = v_target_team_id
      AND g.status IN ('scheduled', 'live')
    ORDER BY g.game_date ASC
    LIMIT 1;

    -- Rank within target team
    SELECT rank_number INTO v_my_rank
    FROM (
        SELECT 
            p.id AS fan_id,
            ROW_NUMBER() OVER (ORDER BY COALESCE(SUM(l.amount), 0) DESC) AS rank_number
        FROM public.profiles p
        JOIN public.ledger_entries l ON l.fan_id = p.id AND l.team_id = v_target_team_id
        WHERE p.status = 'active' AND p.deleted_at IS NULL AND l.status = 'confirmed' AND l.created_at >= date_trunc('month', NOW())
        GROUP BY p.id
    ) ranks
    WHERE ranks.fan_id = v_uid;

    RETURN jsonb_build_object(
        'team', to_jsonb(v_team_row),
        'team_id', v_target_team_id,
        'balance', v_balance,
        'active_trivia', v_active_trivia,
        'streak', v_streak,
        'next_game', v_next_game,
        'my_rank', v_my_rank
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.home_summary(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.home_summary(UUID) TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 5. RLS Public Read: Expose published trivias ONLY for active teams
-- ----------------------------------------------------------------------------

DROP POLICY IF EXISTS "Public reads published trivias" ON public.trivias;
CREATE POLICY "Public reads published trivias" ON public.trivias
    FOR SELECT TO anon, authenticated
    USING (
        (
            status IN ('published'::trivia_status, 'archived'::trivia_status)
            AND EXISTS (SELECT 1 FROM public.teams t WHERE t.id = team_id AND t.status = 'active')
        )
        OR public.is_team_staff((SELECT auth.uid()), team_id)
    );

-- Dynamic trivia tables public read policies (filtered by active teams)
DO $$
DECLARE
    v_tbl TEXT;
    v_dyn_tables TEXT[] := ARRAY[
        'trivia_polls', 'guess_player_challenges', 'over_under_predictions',
        'mystery_play_challenges', 'score_predictions', 'flash_trivia_challenges',
        'progressive_clue_challenges'
    ];
    v_pol RECORD;
BEGIN
    FOREACH v_tbl IN ARRAY v_dyn_tables LOOP
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = v_tbl) THEN
            -- Drop existing public read policy if any
            FOR v_pol IN (
                SELECT policyname FROM pg_policies 
                WHERE schemaname = 'public' AND tablename = v_tbl AND (policyname ILIKE '%public%' OR policyname ILIKE '%read%')
            ) LOOP
                EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', v_pol.policyname, v_tbl);
            END LOOP;

            -- Re-create public read policy requiring team active
            EXECUTE format(
                'CREATE POLICY %I ON public.%I FOR SELECT TO anon, authenticated USING (
                    (status IN (''published'', ''closed'', ''resolved'', ''archived'') AND EXISTS (SELECT 1 FROM public.teams t WHERE t.id = team_id AND t.status = ''active''))
                    OR public.is_team_staff((SELECT auth.uid()), team_id)
                )',
                v_tbl || '_public_read_active_team',
                v_tbl
            );
        END IF;
    END LOOP;
END$$;

-- ----------------------------------------------------------------------------
-- 6. Performance Composite Indexes (team_id, status)
-- ----------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_trivias_team_status ON public.trivias(team_id, status);
CREATE INDEX IF NOT EXISTS idx_products_team_active ON public.products(team_id, active);
CREATE INDEX IF NOT EXISTS idx_trivia_polls_team_status ON public.trivia_polls(team_id, status);
CREATE INDEX IF NOT EXISTS idx_guess_player_team_status ON public.guess_player_challenges(team_id, status);
CREATE INDEX IF NOT EXISTS idx_over_under_team_status ON public.over_under_predictions(team_id, status);
CREATE INDEX IF NOT EXISTS idx_mystery_play_team_status ON public.mystery_play_challenges(team_id, status);
CREATE INDEX IF NOT EXISTS idx_score_pred_team_status ON public.score_predictions(team_id, status);
CREATE INDEX IF NOT EXISTS idx_flash_trivia_team_status ON public.flash_trivia_challenges(team_id, status);
CREATE INDEX IF NOT EXISTS idx_progressive_clues_team_status ON public.progressive_clue_challenges(team_id, status);

-- ----------------------------------------------------------------------------
-- 7. Security Hardening: Restrict Column-Level UPDATE on profiles for authenticated
-- ----------------------------------------------------------------------------
REVOKE UPDATE ON TABLE public.profiles FROM authenticated;
GRANT UPDATE (display_name, avatar_url, cover_url, municipality, gender, favorite_player_id, shirt_size, referral_source, notification_prefs) ON TABLE public.profiles TO authenticated;

-- Ensure create_notification is strictly service_role only
REVOKE ALL ON FUNCTION public.create_notification(UUID, TEXT, TEXT, TEXT, JSONB, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_notification(UUID, TEXT, TEXT, TEXT, JSONB, TEXT) TO service_role;

