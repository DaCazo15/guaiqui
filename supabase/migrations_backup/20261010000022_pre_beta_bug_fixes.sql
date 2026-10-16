-- Migration: 20261010000022_pre_beta_bug_fixes.sql
-- Description: Fix column references in cron_notify_match_day, run_daily_wallet_reconciliation, and claim_birthday_bonus.

-- 1. Fix cron_notify_match_day column names (opponent, game_date)
CREATE OR REPLACE FUNCTION public.cron_notify_match_day()
RETURNS VOID AS $$
DECLARE
    m RECORD;
    f RECORD;
BEGIN
    FOR m IN
        SELECT id, opponent, game_date
        FROM public.games
        WHERE status = 'scheduled'
          AND game_date >= (NOW() + INTERVAL '2 hours 30 minutes')
          AND game_date <= (NOW() + INTERVAL '3 hours 30 minutes')
    LOOP
        FOR f IN SELECT id FROM public.profiles WHERE status = 'active' LOOP
            PERFORM public.create_notification(
                f.id,
                'match_day',
                '¡Hoy Juegan los Guaiqueríes!',
                'El partido contra ' || m.opponent || ' comienza en 3 horas.',
                jsonb_build_object('game_id', m.id, 'url', '/app'),
                'match_day_' || m.id || '_' || f.id
            );
        END LOOP;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.cron_notify_match_day() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cron_notify_match_day() TO service_role, postgres;


-- 2. Fix run_daily_wallet_reconciliation record column names (fan_id, balance_cache, computed_balance, difference)
CREATE OR REPLACE FUNCTION public.run_daily_wallet_reconciliation()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_mismatches INT := 0;
  v_rec RECORD;
BEGIN
  FOR v_rec IN SELECT * FROM public.reconcile_wallets() LOOP
    v_mismatches := v_mismatches + 1;
    INSERT INTO public.system_alerts (alert_type, severity, message, metadata)
    VALUES (
      'wallet_mismatch',
      'critical',
      'Descalce detectado en billetera de usuario: ' || v_rec.fan_id::text,
      jsonb_build_object(
        'user_id', v_rec.fan_id,
        'cached_balance', v_rec.balance_cache,
        'ledger_calculated', v_rec.computed_balance,
        'diff', v_rec.difference
      )
    );
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.run_daily_wallet_reconciliation() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.run_daily_wallet_reconciliation() TO service_role;


-- 3. Fix claim_birthday_bonus table reference (risk_flags instead of non-existent risk_assessments)
CREATE OR REPLACE FUNCTION public.claim_birthday_bonus()
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_card JSONB;
    v_bonus_amount INT;
    v_created_at TIMESTAMPTZ;
    v_year INT;
    v_status ledger_status := 'confirmed';
    v_entry_id UUID;
BEGIN
    PERFORM public.assert_active_verified_fan();

    v_card := public.get_birthday_card();

    IF NOT (v_card->>'eligible')::boolean THEN
        RAISE EXCEPTION 'No eres elegible para reclamar el bono de cumpleaños en este momento.';
    END IF;

    v_bonus_amount := (v_card->>'bonus_pearls')::int;
    IF v_bonus_amount <= 0 THEN
        RAISE EXCEPTION 'No hay bono de perlitas configurado para el cumpleaños.';
    END IF;

    IF (v_card->>'has_claimed_bonus')::boolean THEN
        RAISE EXCEPTION 'Ya has reclamado tu bono de cumpleaños de este año.';
    END IF;

    SELECT created_at INTO v_created_at FROM public.profiles WHERE id = v_user_id;
    IF v_created_at > (NOW() - INTERVAL '30 days') THEN
        RAISE EXCEPTION 'Tu cuenta debe tener al menos 30 días de antigüedad para reclamar el bono de cumpleaños.';
    END IF;

    v_year := EXTRACT(YEAR FROM (NOW() AT TIME ZONE 'America/Caracas'))::int;

    -- Verificar retención por nivel de riesgo en risk_flags
    IF EXISTS (
        SELECT 1 FROM public.risk_flags
        WHERE fan_id = v_user_id AND resolved = false AND severity IN ('medium', 'high')
    ) THEN
        v_status := 'held';
    END IF;

    INSERT INTO public.ledger_entries (
        fan_id, amount, type, status, source_type, source_id, note, created_by
    ) VALUES (
        v_user_id, v_bonus_amount, 'birthday_bonus', v_status,
        'birthday_bonus', 'birthday_bonus_' || v_user_id::text || '_' || v_year::text,
        'Bono de regalo por cumpleaños', v_user_id
    ) RETURNING id INTO v_entry_id;

    IF v_status = 'confirmed' THEN
        UPDATE public.wallets
        SET balance_cache = balance_cache + v_bonus_amount,
            updated_at = NOW()
        WHERE fan_id = v_user_id;
    END IF;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_user_id, 'claim_birthday_bonus', 'ledger_entries', v_entry_id::text,
        jsonb_build_object('amount', v_bonus_amount, 'status', v_status, 'year', v_year)
    );

    RETURN jsonb_build_object(
        'success', true,
        'claimed_pearls', v_bonus_amount,
        'status', v_status
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.claim_birthday_bonus() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_birthday_bonus() TO authenticated, service_role;
