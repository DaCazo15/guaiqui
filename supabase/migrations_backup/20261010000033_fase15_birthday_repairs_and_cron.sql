-- Migration: 20261010000033_fase15_birthday_repairs_and_cron.sql
-- Description: Birthday greetings (Fase 15) - Complete timezone alignment (America/Caracas), Feb 29 non-leap fallback, pg_cron scheduling, ledger integration, and privacy enforcement.

-- 1. Ledger type extension
ALTER TYPE ledger_type ADD VALUE IF NOT EXISTS 'birthday_bonus';

-- 2. Birthday settings singleton table
CREATE TABLE IF NOT EXISTS public.birthday_settings (
    id INT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    enabled BOOLEAN NOT NULL DEFAULT true,
    title TEXT NOT NULL DEFAULT '¡Feliz Cumpleaños, Guaiquerí!',
    message TEXT NOT NULL DEFAULT '¡En nombre de todos los que formamos parte de los **Guaiqueríes de Margarita**, te deseamos un feliz cumpleaños, {nombre}!\n\nGracias por tu pasión y por ser parte fundamental de nuestra tribu.',
    image_url TEXT,
    send_hour INT NOT NULL DEFAULT 9 CHECK (send_hour >= 0 AND send_hour <= 23),
    grace_days INT NOT NULL DEFAULT 3 CHECK (grace_days >= 0),
    bonus_pearls INT NOT NULL DEFAULT 0 CHECK (bonus_pearls >= 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO public.birthday_settings (id, enabled, title, message, send_hour, grace_days, bonus_pearls)
VALUES (
    1,
    true,
    '¡Feliz Cumpleaños, Guaiquerí!',
    '¡En nombre de todos los que formamos parte de los **Guaiqueríes de Margarita**, te deseamos un feliz cumpleaños, {nombre}!\n\nGracias por tu pasión y por ser parte fundamental de nuestra tribu.',
    9,
    3,
    0
)
ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    message = EXCLUDED.message,
    updated_at = NOW();

ALTER TABLE public.birthday_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "BirthdaySettings Public Read" ON public.birthday_settings;
CREATE POLICY "BirthdaySettings Public Read" ON public.birthday_settings
    FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS "BirthdaySettings Admin Write" ON public.birthday_settings;
CREATE POLICY "BirthdaySettings Admin Write" ON public.birthday_settings
    FOR ALL TO authenticated USING (public.is_admin_check());

-- 3. Internal function enqueue_birthday_notifications
DROP FUNCTION IF EXISTS public.enqueue_birthday_notifications(TIMESTAMPTZ);
CREATE OR REPLACE FUNCTION public.enqueue_birthday_notifications(p_now TIMESTAMPTZ DEFAULT NOW())
RETURNS JSONB AS $$
DECLARE
    v_caracas_now TIMESTAMPTZ;
    v_cur_date DATE;
    v_cur_month INT;
    v_cur_day INT;
    v_cur_year INT;
    v_is_leap BOOLEAN;
    v_settings public.birthday_settings%ROWTYPE;
    v_count INT := 0;
    r RECORD;
BEGIN
    SELECT * INTO v_settings FROM public.birthday_settings WHERE id = 1;
    IF v_settings.enabled IS NOT TRUE THEN
        RETURN jsonb_build_object('success', true, 'enqueued', 0, 'reason', 'Campaign disabled');
    END IF;

    -- Calculate Caracas time (UTC-4)
    v_caracas_now := COALESCE(p_now, NOW()) AT TIME ZONE 'America/Caracas';
    v_cur_date := v_caracas_now::date;
    v_cur_month := EXTRACT(MONTH FROM v_caracas_now)::int;
    v_cur_day := EXTRACT(DAY FROM v_caracas_now)::int;
    v_cur_year := EXTRACT(YEAR FROM v_caracas_now)::int;

    -- Leap year check for current year
    v_is_leap := (v_cur_year % 4 = 0 AND (v_cur_year % 100 != 0 OR v_cur_year % 400 = 0));

    -- Select eligible fans whose birthday matches today in Caracas
    FOR r IN
        SELECT p.id, p.display_name, p.notification_prefs
        FROM public.profiles p
        JOIN auth.users u ON u.id = p.id
        WHERE p.status = 'active'
          AND p.deleted_at IS NULL
          AND u.email_confirmed_at IS NOT NULL
          AND p.birth_date IS NOT NULL
          AND (
            -- Exact month and day match
            (EXTRACT(MONTH FROM p.birth_date)::int = v_cur_month AND EXTRACT(DAY FROM p.birth_date)::int = v_cur_day)
            OR
            -- Feb 29 birth in non-leap year celebrated on Feb 28
            (NOT v_is_leap AND EXTRACT(MONTH FROM p.birth_date)::int = 2 AND EXTRACT(DAY FROM p.birth_date)::int = 29 AND v_cur_month = 2 AND v_cur_day = 28)
          )
          AND COALESCE((p.notification_prefs->>'birthday')::boolean, true) = true
        LIMIT 500
    LOOP
        PERFORM public.create_notification(
            r.id,
            'birthday',
            '¡Feliz cumpleaños, Guaiquerí!',
            'Hola ' || COALESCE(r.display_name, 'Fanático') || ', los Guaiqueríes de Margarita tienen un mensaje especial para ti hoy.',
            jsonb_build_object('url', '/app/cumpleanos'),
            'birthday:' || r.id::text || ':' || v_cur_year::text
        );
        v_count := v_count + 1;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'enqueued', v_count, 'caracas_date', v_cur_date);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

REVOKE ALL ON FUNCTION public.enqueue_birthday_notifications(TIMESTAMPTZ) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.enqueue_birthday_notifications(TIMESTAMPTZ) TO service_role, postgres;

-- 4. RPC get_birthday_card() (Strict Privacy - Never returns birth_date or age)
CREATE OR REPLACE FUNCTION public.get_birthday_card()
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_caracas_now TIMESTAMPTZ;
    v_cur_date DATE;
    v_cur_year INT;
    v_profile public.profiles%ROWTYPE;
    v_settings public.birthday_settings%ROWTYPE;
    v_bdate DATE;
    v_bmonth INT;
    v_bday INT;
    v_is_leap BOOLEAN;
    v_bdate_this_year DATE;
    v_grace_days INT;
    v_is_eligible BOOLEAN := false;
    v_claimed BOOLEAN := false;
BEGIN
    v_user_id := public.assert_active_verified_fan();

    SELECT * INTO v_profile FROM public.profiles WHERE id = v_user_id;
    SELECT * INTO v_settings FROM public.birthday_settings WHERE id = 1;

    IF v_profile.birth_date IS NULL OR v_settings.enabled IS NOT TRUE THEN
        RETURN jsonb_build_object('eligible', false);
    END IF;

    v_caracas_now := NOW() AT TIME ZONE 'America/Caracas';
    v_cur_date := v_caracas_now::date;
    v_cur_year := EXTRACT(YEAR FROM v_caracas_now)::int;
    v_is_leap := (v_cur_year % 4 = 0 AND (v_cur_year % 100 != 0 OR v_cur_year % 400 = 0));

    v_bdate := v_profile.birth_date;
    v_bmonth := EXTRACT(MONTH FROM v_bdate)::int;
    v_bday := EXTRACT(DAY FROM v_bdate)::int;

    -- Feb 29 adjustment on non-leap years
    IF v_bmonth = 2 AND v_bday = 29 AND NOT v_is_leap THEN
        v_bday := 28;
    END IF;

    v_bdate_this_year := (v_cur_year::text || '-' || lpad(v_bmonth::text, 2, '0') || '-' || lpad(v_bday::text, 2, '0'))::date;
    v_grace_days := COALESCE(v_settings.grace_days, 3);

    -- Check if today is within window [birthday, birthday + grace_days]
    IF v_cur_date >= v_bdate_this_year AND v_cur_date <= (v_bdate_this_year + (v_grace_days || ' days')::interval) THEN
        v_is_eligible := true;
    END IF;

    IF NOT v_is_eligible THEN
        RETURN jsonb_build_object('eligible', false);
    END IF;

    -- Check if bonus already claimed this year
    SELECT EXISTS (
        SELECT 1 FROM public.ledger_entries
        WHERE user_id = v_user_id
          AND reference_id = 'birthday_bonus_' || v_user_id::text || '_' || v_cur_year::text
    ) INTO v_claimed;

    RETURN jsonb_build_object(
        'eligible', true,
        'display_name', v_profile.display_name,
        'title', v_settings.title,
        'message', v_settings.message,
        'image_url', v_settings.image_url,
        'bonus_pearls', v_settings.bonus_pearls,
        'has_claimed_bonus', v_claimed
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.get_birthday_card() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_birthday_card() TO authenticated, service_role;

-- 5. RPC claim_birthday_bonus()
CREATE OR REPLACE FUNCTION public.claim_birthday_bonus()
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_profile public.profiles%ROWTYPE;
    v_settings public.birthday_settings%ROWTYPE;
    v_card JSONB;
    v_cur_year INT;
    v_bonus INT;
    v_ref_id TEXT;
    v_claimed BOOLEAN;
    v_wallet wallets%ROWTYPE;
    v_entry_id UUID;
BEGIN
    v_user_id := public.assert_active_verified_fan();

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
    INSERT INTO public.ledger_entries (user_id, pearls, entry_type, description, reference_id)
    VALUES (
        v_user_id,
        v_bonus,
        'confirmed',
        'Bono de Cumpleaños ' || v_cur_year::text,
        v_ref_id
    )
    RETURNING id INTO v_entry_id;

    -- Update wallet cache
    UPDATE public.wallets
    SET confirmed_balance = confirmed_balance + v_bonus,
        updated_at = NOW()
    WHERE fan_id = v_user_id;

    RETURN jsonb_build_object('success', true, 'claimed_pearls', v_bonus);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.claim_birthday_bonus() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_birthday_bonus() TO authenticated, service_role;

-- 6. Admin RPC send_test_birthday_notification
CREATE OR REPLACE FUNCTION public.send_test_birthday_notification()
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID := auth.uid();
BEGIN
    PERFORM public.assert_admin();

    PERFORM public.create_notification(
        v_admin_id,
        'birthday',
        '¡Feliz cumpleaños, Guaiquerí! (Prueba Admin)',
        'Notificación de prueba del saludo de cumpleaños.',
        jsonb_build_object('url', '/app/cumpleanos'),
        'birthday_test:' || v_admin_id::text || ':' || extract(epoch from now())::text
    );

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.send_test_birthday_notification() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.send_test_birthday_notification() TO authenticated, service_role;

-- 7. Admin RPC update_birthday_settings
CREATE OR REPLACE FUNCTION public.update_birthday_settings(
    p_enabled BOOLEAN,
    p_title TEXT,
    p_message TEXT,
    p_image_url TEXT,
    p_send_hour INT,
    p_grace_days INT,
    p_bonus_pearls INT
)
RETURNS JSONB AS $$
BEGIN
    PERFORM public.assert_admin();

    UPDATE public.birthday_settings
    SET enabled = p_enabled,
        title = TRIM(p_title),
        message = TRIM(p_message),
        image_url = p_image_url,
        send_hour = p_send_hour,
        grace_days = p_grace_days,
        bonus_pearls = p_bonus_pearls,
        updated_at = NOW()
    WHERE id = 1;

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.update_birthday_settings(BOOLEAN, TEXT, TEXT, TEXT, INT, INT, INT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_birthday_settings(BOOLEAN, TEXT, TEXT, TEXT, INT, INT, INT) TO authenticated, service_role;
