-- ============================================================================
-- Migration: 20261028000014_fase5_pending_pearl_grants_and_referrals.sql
-- Description: FASE 5 — Perlitas Pendientes (Anuncios y Referidos)
--              1. Tablas referral_codes, referrals, referral_trivia_rewards
--              2. Tabla pending_pearl_grants con RLS inmutable para clientes
--              3. Reescribe claim_video_points para generar pending_pearl_grants
--              4. RPC claim_pending_grant(grant_id, team_id) atómica y validada
--              5. Hook en handle_new_user para registrar referidos y otorgar bono (90 días)
--              6. Hook en submit_trivia_attempt para bono de trivia (5 pts si sigue al equipo)
--              7. Job job_expire_pending_grants() para expiración y avisos a 7 días
--              8. RPCs para frontend: get_pending_pearl_grants(), get_my_referral_summary()
--              9. Actualiza get_wallet_summary() para computar pending_pearls
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Tabla referral_codes (Códigos únicos de referido por fanático)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.referral_codes (
    user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    code TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_referral_codes_code ON public.referral_codes (code);

ALTER TABLE public.referral_codes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "referral_codes_select" ON public.referral_codes;
CREATE POLICY "referral_codes_select" ON public.referral_codes
    FOR SELECT TO authenticated
    USING (true);

-- Backfill de códigos para perfiles existentes
INSERT INTO public.referral_codes (user_id, code)
SELECT 
    p.id,
    UPPER(SUBSTRING(MD5(p.id::text || 'guaiqui_salt_ref') FROM 1 FOR 8))
FROM public.profiles p
ON CONFLICT (user_id) DO NOTHING;

-- Función generadora de códigos de referido
CREATE OR REPLACE FUNCTION public.get_or_create_referral_code(p_user_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_code TEXT;
BEGIN
    SELECT code INTO v_code FROM public.referral_codes WHERE user_id = p_user_id;
    IF v_code IS NOT NULL THEN
        RETURN v_code;
    END IF;

    v_code := UPPER(SUBSTRING(MD5(p_user_id::text || NOW()::text || random()::text) FROM 1 FOR 8));
    INSERT INTO public.referral_codes (user_id, code)
    VALUES (p_user_id, v_code)
    ON CONFLICT (user_id) DO UPDATE SET code = EXCLUDED.code
    RETURNING code INTO v_code;

    RETURN v_code;
END;
$$;

-- ----------------------------------------------------------------------------
-- 2. Tabla referrals (Relación Referidor -> Referido)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.referrals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    referrer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    referred_id UUID NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'registered' CHECK (status IN ('registered', 'qualified')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_no_self_referral CHECK (referrer_id != referred_id)
);

CREATE INDEX IF NOT EXISTS idx_referrals_referrer_id ON public.referrals (referrer_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referred_id ON public.referrals (referred_id);

ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "referrals_select_own" ON public.referrals;
CREATE POLICY "referrals_select_own" ON public.referrals
    FOR SELECT TO authenticated
    USING (referrer_id = auth.uid() OR referred_id = auth.uid());

-- ----------------------------------------------------------------------------
-- 3. Tabla pending_pearl_grants (Concesiones de perlitas pendientes por asignar)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pending_pearl_grants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fan_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    source TEXT NOT NULL CHECK (source IN ('ads_block', 'referral_signup')),
    amount INT NOT NULL CHECK (amount > 0),
    referral_id UUID NULL REFERENCES public.referrals(id) ON DELETE SET NULL,
    source_ref TEXT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'claimed', 'expired')),
    expires_at TIMESTAMPTZ NULL,
    claimed_team_id UUID NULL REFERENCES public.teams(id) ON DELETE SET NULL,
    claimed_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pending_grants_fan_status ON public.pending_pearl_grants (fan_id, status);
CREATE INDEX IF NOT EXISTS idx_pending_grants_expires ON public.pending_pearl_grants (expires_at) WHERE status = 'pending';
CREATE UNIQUE INDEX IF NOT EXISTS idx_pending_grants_idempotency 
    ON public.pending_pearl_grants (fan_id, source, source_ref) 
    WHERE source_ref IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_pending_grants_referral_signup
    ON public.pending_pearl_grants (referral_id)
    WHERE source = 'referral_signup' AND referral_id IS NOT NULL;

ALTER TABLE public.pending_pearl_grants ENABLE ROW LEVEL SECURITY;

-- Fan solo puede leer sus propias concesiones
DROP POLICY IF EXISTS "fan_select_own_pending_grants" ON public.pending_pearl_grants;
CREATE POLICY "fan_select_own_pending_grants" ON public.pending_pearl_grants
    FOR SELECT TO authenticated
    USING (fan_id = auth.uid());

-- Sin INSERT / UPDATE / DELETE para clientes authenticated (solo funciones del servidor)

-- ----------------------------------------------------------------------------
-- 4. Tabla referral_trivia_rewards (Registro anti-duplicados por trivia de referido)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.referral_trivia_rewards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    referrer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    referred_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    trivia_id UUID NOT NULL REFERENCES public.trivias(id) ON DELETE CASCADE,
    team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
    points_awarded INT NOT NULL DEFAULT 5,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_referral_trivia UNIQUE (referred_id, trivia_id)
);

CREATE INDEX IF NOT EXISTS idx_referral_trivia_rewards_referrer ON public.referral_trivia_rewards (referrer_id);

ALTER TABLE public.referral_trivia_rewards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "referral_trivia_rewards_select" ON public.referral_trivia_rewards;
CREATE POLICY "referral_trivia_rewards_select" ON public.referral_trivia_rewards
    FOR SELECT TO authenticated
    USING (referrer_id = auth.uid());

-- ----------------------------------------------------------------------------
-- 5. RPC claim_pending_grant (Asignar concesión pendiente a un equipo seguido y activo)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.claim_pending_grant(
    p_grant_id UUID,
    p_team_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_fan_id UUID;
    v_grant RECORD;
    v_team RECORD;
    v_ledger_type ledger_type;
BEGIN
    v_fan_id := public.assert_active_verified_fan();

    IF p_grant_id IS NULL OR p_team_id IS NULL THEN
        RAISE EXCEPTION 'p_grant_id y p_team_id son requeridos.' USING ERRCODE = 'P0002';
    END IF;

    -- Rate limiting
    PERFORM public.check_rate_limit(v_fan_id, 'claim_pending_grant', 15, 60);

    -- Bloquear y obtener la concesión
    SELECT * INTO v_grant
    FROM public.pending_pearl_grants
    WHERE id = p_grant_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Concesión pendiente no encontrada.' USING ERRCODE = 'P0002';
    END IF;

    IF v_grant.fan_id != v_fan_id THEN
        RAISE EXCEPTION 'No autorizado para reclamar esta concesión.' USING ERRCODE = '42501';
    END IF;

    IF v_grant.status = 'claimed' THEN
        RAISE EXCEPTION 'Esta concesión ya fue reclamada previamente.' USING ERRCODE = 'P0001';
    END IF;

    IF v_grant.status = 'expired' OR (v_grant.expires_at IS NOT NULL AND v_grant.expires_at < NOW()) THEN
        UPDATE public.pending_pearl_grants
        SET status = 'expired'
        WHERE id = p_grant_id;
        RAISE EXCEPTION 'Esta concesión de perlitas ha expirado.' USING ERRCODE = 'P0001';
    END IF;

    -- Validar que el equipo exista, esté activo y sea seguido por el usuario
    SELECT t.id, t.name, t.status INTO v_team
    FROM public.teams t
    JOIN public.team_follows tf ON tf.team_id = t.id AND tf.user_id = v_fan_id
    WHERE t.id = p_team_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Debes seguir al equipo para asignarle las perlitas.' USING ERRCODE = 'P0001';
    END IF;

    IF v_team.status != 'active' THEN
        RAISE EXCEPTION 'El equipo seleccionado se encuentra inactivo.' USING ERRCODE = 'P0001';
    END IF;

    -- Asegurar billetera del equipo
    INSERT INTO public.wallets (fan_id, team_id, balance_cache, updated_at)
    VALUES (v_fan_id, p_team_id, 0, NOW())
    ON CONFLICT (fan_id, team_id) DO NOTHING;

    -- Tipo de movimiento contable
    IF v_grant.source = 'ads_block' THEN
        v_ledger_type := 'ad_reward'::ledger_type;
    ELSE
        v_ledger_type := 'bonus'::ledger_type;
    END IF;

    -- 1. Insertar asiento inmutable en el libro contable
    INSERT INTO public.ledger_entries (
        fan_id, team_id, amount, type, status, source_type, source_id, note
    ) VALUES (
        v_fan_id, p_team_id, v_grant.amount, v_ledger_type, 'confirmed', 'pending_grant', v_grant.id::text,
        'Asignación de ' || v_grant.amount::text || ' perlitas pendientes (' || v_grant.source || ')'
    );

    -- 2. Incrementar saldo en caché de la billetera del equipo
    UPDATE public.wallets
    SET balance_cache = balance_cache + v_grant.amount,
        updated_at = NOW()
    WHERE fan_id = v_fan_id AND team_id = p_team_id;

    -- 3. Marcar concesión como reclamada
    UPDATE public.pending_pearl_grants
    SET status = 'claimed',
        claimed_team_id = p_team_id,
        claimed_at = NOW()
    WHERE id = p_grant_id;

    RETURN jsonb_build_object(
        'success', true,
        'grant_id', p_grant_id,
        'team_id', p_team_id,
        'amount', v_grant.amount,
        'source', v_grant.source
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 6. Reescribir claim_video_points (genera pending_pearl_grants al completar bloque)
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
    v_source_ref TEXT;
    v_video RECORD;
    v_grant_id UUID;
    v_has_followed_teams BOOLEAN := false;
    v_notif_url TEXT;
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

    -- Cada bloque de 10 videos genera 1 concesión pendiente
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

        v_source_ref := 'video_block:' || v_uid::text || ':' || v_today::text || ':' || v_block_number::text;

        -- Crear concesión pendiente (expires_at NULL: nunca vence)
        INSERT INTO public.pending_pearl_grants (
            fan_id, source, amount, source_ref, status, expires_at
        ) VALUES (
            v_uid, 'ads_block', v_points_to_award, v_source_ref, 'pending', NULL
        )
        ON CONFLICT (fan_id, source, source_ref) DO NOTHING
        RETURNING id INTO v_grant_id;

        IF v_grant_id IS NOT NULL THEN
            -- Actualizar contador de bloques pagados
            UPDATE public.ad_daily_progress
            SET blocks_paid = blocks_paid + 1
            WHERE user_id = v_uid AND day = v_today;

            -- Comprobar si sigue equipos activos
            SELECT EXISTS (
                SELECT 1 FROM public.team_follows tf
                JOIN public.teams t ON t.id = tf.team_id AND t.status = 'active'
                WHERE tf.user_id = v_uid
            ) INTO v_has_followed_teams;

            IF v_has_followed_teams THEN
                v_notif_url := '/app/perlitas-pendientes';
            ELSE
                v_notif_url := '/app/equipos';
            END IF;

            -- Notificación in-app
            PERFORM public.create_notification(
                v_uid,
                'pending_grant',
                'Tienes ' || v_points_to_award::text || ' perlitas por asignar',
                'Tienes ' || v_points_to_award::text || ' perlitas por asignar al equipo de tu preferencia.',
                jsonb_build_object(
                    'url', v_notif_url,
                    'grant_id', v_grant_id,
                    'amount', v_points_to_award,
                    'source', 'ads_block'
                ),
                'grant_ad_' || v_grant_id::text
            );
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'completed_today', v_completed_count,
        'is_block_completed', v_is_block_completed,
        'block_number', v_block_number,
        'points_awarded', v_points_to_award,
        'pending_grant_id', v_grant_id,
        'pending_pearls', v_points_to_award
    );
END;
$function$;

-- ----------------------------------------------------------------------------
-- 7. Hook para bonificación de referidos en trivias completadas exitosamente
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.process_referral_trivia_bonus(
    p_referred_id UUID,
    p_trivia_id UUID,
    p_team_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_referrer_id UUID;
    v_referrer_follows BOOLEAN := FALSE;
    v_reward_id UUID;
    v_team_name TEXT;
BEGIN
    -- 1. Buscar si el usuario fue referido
    SELECT referrer_id INTO v_referrer_id
    FROM public.referrals
    WHERE referred_id = p_referred_id;

    IF v_referrer_id IS NULL THEN
        RETURN;
    END IF;

    -- 2. Validar que el referidor SIGA al equipo y que el equipo esté ACTIVO
    SELECT t.name INTO v_team_name
    FROM public.teams t
    JOIN public.team_follows tf ON tf.team_id = t.id AND tf.user_id = v_referrer_id
    WHERE t.id = p_team_id AND t.status = 'active';

    IF v_team_name IS NULL THEN
        -- El referidor no sigue este equipo o el equipo está inactivo: no se acredita nada
        RETURN;
    END IF;

    -- 3. Registrar recompensa una sola vez por (referido, trivia)
    INSERT INTO public.referral_trivia_rewards (
        referrer_id, referred_id, trivia_id, team_id, points_awarded
    ) VALUES (
        v_referrer_id, p_referred_id, p_trivia_id, p_team_id, 5
    )
    ON CONFLICT (referred_id, trivia_id) DO NOTHING
    RETURNING id INTO v_reward_id;

    IF v_reward_id IS NULL THEN
        -- Ya se había otorgado el bono para esta combinación referido-trivia
        RETURN;
    END IF;

    -- 4. Asegurar billetera del referidor en ese equipo
    INSERT INTO public.wallets (fan_id, team_id, balance_cache, updated_at)
    VALUES (v_referrer_id, p_team_id, 0, NOW())
    ON CONFLICT (fan_id, team_id) DO NOTHING;

    -- 5. Asiento contable en ledger_entries
    INSERT INTO public.ledger_entries (
        fan_id, team_id, amount, type, status, source_type, source_id, note
    ) VALUES (
        v_referrer_id, p_team_id, 5, 'bonus'::ledger_type, 'confirmed', 'referral_trivia',
        p_referred_id::text || ':' || p_trivia_id::text,
        'Bono de 5 perlitas por trivia de tu referido en ' || v_team_name
    );

    -- 6. Acreditar a la billetera del referidor
    UPDATE public.wallets
    SET balance_cache = balance_cache + 5,
        updated_at = NOW()
    WHERE fan_id = v_referrer_id AND team_id = p_team_id;

    -- 7. Calificar el estatus del referido si estaba 'registered'
    UPDATE public.referrals
    SET status = 'qualified'
    WHERE referred_id = p_referred_id AND status = 'registered';

    -- 8. Notificar al referidor
    PERFORM public.create_notification(
        v_referrer_id,
        'referral_trivia',
        '¡Tu referido jugó una trivia!',
        'Has ganado 5 perlitas en ' || v_team_name || ' porque tu referido completó una trivia con éxito.',
        jsonb_build_object(
            'url', '/app/billetera',
            'team_id', p_team_id,
            'amount', 5
        ),
        'ref_trivia_' || v_reward_id::text
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 8. Actualizar submit_trivia_attempt para invocar process_referral_trivia_bonus
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_trivia_attempt(p_attempt_id UUID, p_answers JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_fan_id UUID;
    v_attempt RECORD;
    v_trivia RECORD;
    v_team_id UUID;
    v_score INT := 0;
    v_correct_count INT := 0;
    v_total_questions INT := 0;
    v_q RECORD;
    v_is_correct BOOLEAN;
    v_answer_option_id UUID;
    v_reward_pearls INT := 0;
    v_final_pearls INT := 0;
    v_is_won BOOLEAN := false;
    v_is_suspicious BOOLEAN := false;
    v_risk_reason TEXT := NULL;
    v_entry_status ledger_status := 'confirmed';
    v_today_earned INT := 0;
    v_daily_cap INT := 1000;
BEGIN
    v_fan_id := public.assert_active_verified_fan();

    IF p_attempt_id IS NULL THEN
        RAISE EXCEPTION 'p_attempt_id is required.';
    END IF;

    -- 1. Fetch Attempt
    SELECT * INTO v_attempt
    FROM public.trivia_attempts
    WHERE id = p_attempt_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Trivia attempt not found.' USING ERRCODE = 'P0002';
    END IF;

    IF v_attempt.user_id != v_fan_id THEN
        RAISE EXCEPTION 'You cannot submit an attempt that does not belong to you.' USING ERRCODE = '42501';
    END IF;

    IF v_attempt.submitted_at IS NOT NULL THEN
        RAISE EXCEPTION 'This attempt has already been submitted.' USING ERRCODE = 'P0001';
    END IF;

    -- 2. Fetch Trivia & Team
    SELECT * INTO v_trivia
    FROM public.trivias
    WHERE id = v_attempt.trivia_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Trivia not found.' USING ERRCODE = 'P0002';
    END IF;

    v_team_id := v_trivia.team_id;
    IF v_team_id IS NULL THEN
        v_team_id := 'a0000000-0000-0000-0000-000000000001'::uuid;
    END IF;

    -- Ensure Fan Follows Active Team
    IF NOT EXISTS (
        SELECT 1 FROM public.team_follows tf
        JOIN public.teams t ON t.id = tf.team_id AND t.status = 'active'
        WHERE tf.user_id = v_fan_id AND tf.team_id = v_team_id
    ) THEN
        RAISE EXCEPTION 'Debes seguir al equipo para participar y ganar perlitas en sus trivias.' USING ERRCODE = '42501';
    END IF;

    -- Rate Limiting
    PERFORM public.check_rate_limit(v_fan_id, 'submit_trivia_attempt', 5, 60);

    -- 3. Calculate Score
    FOR v_q IN (
        SELECT tq.id, tq.points
        FROM public.trivia_questions tq
        WHERE tq.trivia_id = v_trivia.id
        ORDER BY tq.order_index ASC
    ) LOOP
        v_total_questions := v_total_questions + 1;
        v_answer_option_id := NULL;

        BEGIN
            v_answer_option_id := (p_answers->>v_q.id::text)::uuid;
        EXCEPTION WHEN OTHERS THEN
            v_answer_option_id := NULL;
        END;

        IF v_answer_option_id IS NOT NULL THEN
            SELECT is_correct INTO v_is_correct
            FROM public.trivia_options
            WHERE id = v_answer_option_id AND question_id = v_q.id;

            IF v_is_correct IS TRUE THEN
                v_score := v_score + v_q.points;
                v_correct_count := v_correct_count + 1;
            END IF;
        END IF;
    END LOOP;

    -- 4. Calculate Pearls
    IF v_trivia.reward_rules IS NOT NULL AND jsonb_typeof(v_trivia.reward_rules) = 'object' THEN
        v_reward_pearls := COALESCE((v_trivia.reward_rules->>'per_correct_pearls')::int, 10) * v_correct_count;
        IF v_correct_count = v_total_questions AND v_total_questions > 0 THEN
            v_reward_pearls := v_reward_pearls + COALESCE((v_trivia.reward_rules->>'perfect_score_bonus')::int, 0);
        END IF;
    ELSE
        v_reward_pearls := v_score;
    END IF;

    v_is_won := (v_correct_count > 0);

    -- 5. Anti-Fraud & Inhuman Time Check
    IF EXTRACT(EPOCH FROM (NOW() - v_attempt.started_at)) < 3 AND v_total_questions >= 3 THEN
        v_is_suspicious := true;
    END IF;

    -- 6. Cap Verification & Wallet Ledger Credit
    IF v_reward_pearls > 0 THEN
        SELECT COALESCE(SUM(amount), 0) INTO v_today_earned
        FROM public.ledger_entries
        WHERE fan_id = v_fan_id AND team_id = v_team_id AND amount > 0 AND created_at >= date_trunc('day', NOW());

        IF v_today_earned + v_reward_pearls > v_daily_cap THEN
            v_final_pearls := GREATEST(0, v_daily_cap - v_today_earned);
        ELSE
            v_final_pearls := v_reward_pearls;
        END IF;

        IF v_final_pearls > 0 THEN
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

                -- HOOK FASE 5: Bonificación a referidor si el usuario fue referido
                PERFORM public.process_referral_trivia_bonus(v_fan_id, v_trivia.id, v_team_id);
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

-- ----------------------------------------------------------------------------
-- 9. Actualizar handle_new_user (gestiona código de referido y pending_pearl_grants)
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
    v_ref_code TEXT;
    v_referrer_id UUID;
    v_referral_id UUID;
    v_grant_id UUID;
    v_terms_at TIMESTAMPTZ;
    v_terms_ver TEXT;
    v_priv_at TIMESTAMPTZ;
    v_priv_ver TEXT;
    v_pearls_at TIMESTAMPTZ;
    v_pearls_ver TEXT;
    v_has_followed_teams BOOLEAN := false;
    v_notif_url TEXT;
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
    v_ref_code := NULLIF(trim(COALESCE(v_raw_meta->>'referral_code', v_raw_meta->>'ref', '')), '');

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

    -- Generar código de referido propio para el nuevo usuario
    PERFORM public.get_or_create_referral_code(NEW.id);

    -- Procesar si el usuario fue referido mediante código
    IF v_ref_code IS NOT NULL THEN
        SELECT user_id INTO v_referrer_id
        FROM public.referral_codes
        WHERE code = UPPER(v_ref_code);

        -- Validar que no sea auto-referido
        IF v_referrer_id IS NOT NULL AND v_referrer_id != NEW.id THEN
            INSERT INTO public.referrals (referrer_id, referred_id, status)
            VALUES (v_referrer_id, NEW.id, 'registered')
            ON CONFLICT (referred_id) DO NOTHING
            RETURNING id INTO v_referral_id;

            IF v_referral_id IS NOT NULL THEN
                -- Otorgar concesión pendiente de 5 perlitas al referidor (expira en 90 días)
                INSERT INTO public.pending_pearl_grants (
                    fan_id, source, amount, referral_id, status, expires_at
                ) VALUES (
                    v_referrer_id, 'referral_signup', 5, v_referral_id, 'pending', NOW() + INTERVAL '90 days'
                )
                ON CONFLICT (referral_id) DO NOTHING
                RETURNING id INTO v_grant_id;

                IF v_grant_id IS NOT NULL THEN
                    SELECT EXISTS (
                        SELECT 1 FROM public.team_follows tf
                        JOIN public.teams t ON t.id = tf.team_id AND t.status = 'active'
                        WHERE tf.user_id = v_referrer_id
                    ) INTO v_has_followed_teams;

                    IF v_has_followed_teams THEN
                        v_notif_url := '/app/perlitas-pendientes';
                    ELSE
                        v_notif_url := '/app/equipos';
                    END IF;

                    PERFORM public.create_notification(
                        v_referrer_id,
                        'pending_grant',
                        'Tienes 5 perlitas por asignar',
                        'Tienes 5 perlitas por asignar porque un amigo se registró con tu enlace (vence en 90 días).',
                        jsonb_build_object(
                            'url', v_notif_url,
                            'grant_id', v_grant_id,
                            'amount', 5,
                            'source', 'referral_signup'
                        ),
                        'grant_ref_' || v_grant_id::text
                    );
                END IF;
            END IF;
        END IF;
    END IF;

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
-- 10. Job de expiración y recordatorios de concesiones pendientes (pg_cron diario)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.job_expire_pending_grants()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_expired_count INT := 0;
    v_rec RECORD;
BEGIN
    -- 1. Expirar concesiones vencidas
    WITH expired_rows AS (
        UPDATE public.pending_pearl_grants
        SET status = 'expired'
        WHERE status = 'pending'
          AND expires_at IS NOT NULL
          AND expires_at < NOW()
        RETURNING id
    )
    SELECT COUNT(*) INTO v_expired_count FROM expired_rows;

    -- 2. Emitir recordatorio 7 días antes del vencimiento
    FOR v_rec IN (
        SELECT id, fan_id, amount, expires_at
        FROM public.pending_pearl_grants
        WHERE status = 'pending'
          AND expires_at IS NOT NULL
          AND expires_at BETWEEN NOW() AND NOW() + INTERVAL '7 days'
    ) LOOP
        PERFORM public.create_notification(
            v_rec.fan_id,
            'grant_expiring_soon',
            'Tus perlitas pendientes están por vencer',
            'Tienes ' || v_rec.amount::text || ' perlitas por asignar que vencerán pronto. Elige tu equipo antes de que expiren.',
            jsonb_build_object(
                'url', '/app/perlitas-pendientes',
                'grant_id', v_rec.id,
                'amount', v_rec.amount,
                'expires_at', v_rec.expires_at
            ),
            'warn_expire_' || v_rec.id::text
        );
    END LOOP;

    RETURN v_expired_count;
END;
$$;

-- Programar cron diario si la extensión pg_cron está disponible
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        PERFORM cron.schedule(
            'job_expire_pending_grants_daily',
            '0 3 * * *',
            'SELECT public.job_expire_pending_grants()'
        );
    END IF;
EXCEPTION WHEN OTHERS THEN
    NULL;
END;
$$;

-- Actualizar create_notification para incluir pending_grant, grant_expiring_soon y referral_trivia como transaccionales
CREATE OR REPLACE FUNCTION public.create_notification(
    p_user_id uuid,
    p_type text,
    p_title text,
    p_body text,
    p_data jsonb DEFAULT '{}'::jsonb,
    p_dedup_key text DEFAULT NULL::text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_dedup_key TEXT;
    v_prefs JSONB;
    v_is_transactional BOOLEAN;
    v_pref_enabled BOOLEAN := true;
    v_daily_non_trans_count INT := 0;
    v_cur_hour INT;
    v_next_attempt_at TIMESTAMPTZ := NOW();
    v_target_date DATE;
    v_notif_id UUID;
    v_has_active_push BOOLEAN := false;
BEGIN
    IF p_user_id IS NULL OR p_type IS NULL OR p_title IS NULL OR p_body IS NULL THEN
        RETURN NULL;
    END IF;

    v_dedup_key := COALESCE(p_dedup_key, gen_random_uuid()::text);

    -- Clasificación transaccional vs no transaccional
    v_is_transactional := (p_type IN (
        'redemption_approved',
        'redemption_delivered',
        'redemption_rejected',
        'redemption_cancelled',
        'redemption_issue',
        'redemption_expiring',
        'pearls_released',
        'pending_grant',
        'grant_expiring_soon',
        'referral_trivia'
    ));

    -- Obtener preferencias del usuario
    SELECT notification_prefs INTO v_prefs FROM public.profiles WHERE id = p_user_id;
    IF v_prefs IS NULL THEN
        v_prefs := '{"redemptions": true, "trivias_matches": true, "news": true, "push": true, "email": true}'::jsonb;
    END IF;

    IF NOT v_is_transactional THEN
        -- Verificar preferencia según categoría
        IF p_type IN ('new_trivia', 'match_day') THEN
            IF COALESCE((v_prefs->>'trivias_matches')::boolean, true) IS FALSE THEN
                RETURN NULL;
            END IF;
        ELSIF p_type IN ('team_news') THEN
            IF COALESCE((v_prefs->>'news')::boolean, true) IS FALSE THEN
                RETURN NULL;
            END IF;
        END IF;

        -- Tope de 1 notificación no transaccional al día (huso America/Caracas)
        SELECT COUNT(*) INTO v_daily_non_trans_count
        FROM public.notifications
        WHERE user_id = p_user_id
          AND type NOT IN (
              'redemption_approved', 'redemption_delivered', 'redemption_rejected',
              'redemption_cancelled', 'redemption_issue', 'redemption_expiring',
              'pearls_released', 'pending_grant', 'grant_expiring_soon', 'referral_trivia'
          )
          AND (created_at AT TIME ZONE 'America/Caracas')::date = (NOW() AT TIME ZONE 'America/Caracas')::date;

        IF v_daily_non_trans_count >= 1 THEN
            RETURN NULL;
        END IF;

        -- Horario de silencio 22:00 a 08:00 (America/Caracas)
        v_cur_hour := EXTRACT(HOUR FROM (NOW() AT TIME ZONE 'America/Caracas'));
        IF v_cur_hour >= 22 OR v_cur_hour < 8 THEN
            IF v_cur_hour >= 22 THEN
                v_target_date := (NOW() AT TIME ZONE 'America/Caracas')::date + INTERVAL '1 day';
            ELSE
                v_target_date := (NOW() AT TIME ZONE 'America/Caracas')::date;
            END IF;
            v_next_attempt_at := (v_target_date || ' 08:00:00')::timestamp AT TIME ZONE 'America/Caracas';
        END IF;
    END IF;

    -- Inserción idempotente en notifications
    INSERT INTO public.notifications (user_id, type, title, body, data, dedup_key)
    VALUES (p_user_id, p_type, p_title, p_body, COALESCE(p_data, '{}'::jsonb), v_dedup_key)
    ON CONFLICT (user_id, dedup_key) DO NOTHING
    RETURNING id INTO v_notif_id;

    IF v_notif_id IS NULL THEN
        RETURN NULL;
    END IF;

    -- Encolar en notification_outbox si las preferencias del canal lo permiten
    IF COALESCE((v_prefs->>'push')::boolean, true) IS NOT FALSE THEN
        SELECT EXISTS (
            SELECT 1 FROM public.push_subscriptions
            WHERE user_id = p_user_id AND disabled_at IS NULL
        ) INTO v_has_active_push;

        IF v_has_active_push THEN
            INSERT INTO public.notification_outbox (notification_id, channel, status, next_attempt_at)
            VALUES (v_notif_id, 'push', 'pending', v_next_attempt_at);
        END IF;
    END IF;

    IF COALESCE((v_prefs->>'email')::boolean, true) IS NOT FALSE THEN
        INSERT INTO public.notification_outbox (notification_id, channel, status, next_attempt_at)
        VALUES (v_notif_id, 'email', 'pending', v_next_attempt_at);
    END IF;

    RETURN v_notif_id;
END;
$function$;

-- ----------------------------------------------------------------------------
-- 11. RPCs de consulta para apps/web
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_pending_pearl_grants()
RETURNS JSONB
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_fan_id UUID := auth.uid();
    v_grants JSONB;
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', g.id,
            'source', g.source,
            'amount', g.amount,
            'status', g.status,
            'expires_at', g.expires_at,
            'created_at', g.created_at,
            'days_remaining', CASE 
                WHEN g.expires_at IS NULL THEN NULL 
                ELSE GREATEST(0, CEIL(EXTRACT(EPOCH FROM (g.expires_at - NOW())) / 86400.0))::INT 
            END
        ) ORDER BY g.created_at DESC
    ), '[]'::jsonb)
    INTO v_grants
    FROM public.pending_pearl_grants g
    WHERE g.fan_id = v_fan_id
      AND g.status = 'pending'
      AND (g.expires_at IS NULL OR g.expires_at > NOW());

    RETURN v_grants;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_my_referral_summary()
RETURNS JSONB
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_fan_id UUID := auth.uid();
    v_code TEXT;
    v_total_referred INT := 0;
    v_qualified_count INT := 0;
    v_points_earned INT := 0;
    v_referrals_list JSONB;
BEGIN
    IF v_fan_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    SELECT code INTO v_code FROM public.referral_codes WHERE user_id = v_fan_id;
    IF v_code IS NULL THEN
        v_code := public.get_or_create_referral_code(v_fan_id);
    END IF;

    SELECT COUNT(*) INTO v_total_referred
    FROM public.referrals
    WHERE referrer_id = v_fan_id;

    SELECT COUNT(*) INTO v_qualified_count
    FROM public.referrals
    WHERE referrer_id = v_fan_id AND status = 'qualified';

    -- Puntos ganados por referidos (signup grants reclamados + trivias)
    SELECT COALESCE(SUM(amount), 0) INTO v_points_earned
    FROM public.pending_pearl_grants
    WHERE fan_id = v_fan_id AND source = 'referral_signup' AND status = 'claimed';

    SELECT v_points_earned + COALESCE(SUM(points_awarded), 0) INTO v_points_earned
    FROM public.referral_trivia_rewards
    WHERE referrer_id = v_fan_id;

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', r.id,
            'referred_name', COALESCE(p.display_name, 'Fanático'),
            'avatar_url', p.avatar_url,
            'status', r.status,
            'created_at', r.created_at
        ) ORDER BY r.created_at DESC
    ), '[]'::jsonb)
    INTO v_referrals_list
    FROM public.referrals r
    JOIN public.profiles p ON p.id = r.referred_id
    WHERE r.referrer_id = v_fan_id;

    RETURN jsonb_build_object(
        'code', v_code,
        'total_referred', v_total_referred,
        'qualified_count', v_qualified_count,
        'points_earned', v_points_earned,
        'referrals', v_referrals_list
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 12. Actualizar get_wallet_summary() para computar pending_pearls
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
    v_pending_pearls INT := 0;
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

    -- Perlitas por asignar (pending_pearl_grants activas)
    SELECT COALESCE(SUM(amount), 0)
    INTO v_pending_pearls
    FROM public.pending_pearl_grants
    WHERE fan_id = v_fan_id
      AND status = 'pending'
      AND (expires_at IS NULL OR expires_at > NOW());

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

    -- Desglose por equipo
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
        WHERE tf.user_id IS NOT NULL OR (w.balance_cache IS NOT NULL AND w.balance_cache > 0)
    ) sub;

    RETURN jsonb_build_object(
        'balance', v_total_balance,
        'total_balance', v_total_balance,
        'pending_pearls', v_pending_pearls,
        'total_held_balance', v_total_held,
        'held_pearls', v_total_held,
        'earned_month', v_earned_month,
        'spent_month', v_spent_month,
        'teams', v_teams_data
    );
END;
$function$;

-- ----------------------------------------------------------------------------
-- 13. Seguridad: REVOKE y GRANT con firmas exactas
-- ----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.get_or_create_referral_code(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_or_create_referral_code(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.claim_pending_grant(UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_pending_grant(UUID, UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.process_referral_trivia_bonus(UUID, UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.process_referral_trivia_bonus(UUID, UUID, UUID) TO service_role;

REVOKE ALL ON FUNCTION public.job_expire_pending_grants() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.job_expire_pending_grants() TO service_role;

REVOKE ALL ON FUNCTION public.get_pending_pearl_grants() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_pending_pearl_grants() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.get_my_referral_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_referral_summary() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.claim_video_points(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_video_points(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.submit_trivia_attempt(UUID, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_trivia_attempt(UUID, JSONB) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.get_wallet_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_wallet_summary() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.create_notification(UUID, TEXT, TEXT, TEXT, JSONB, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_notification(UUID, TEXT, TEXT, TEXT, JSONB, TEXT) TO service_role;
