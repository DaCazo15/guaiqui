-- Migration: 20261010000030_email_quota_and_resend_tracker.sql
-- Description: Creates email_usage_tracker table and register_email_send_attempt RPC for automatic Resend API Key rotation and 6,000 monthly email limit enforcement.

-- 1. Create email_usage_tracker table
CREATE TABLE IF NOT EXISTS public.email_usage_tracker (
    period_yyyy_mm TEXT PRIMARY KEY,
    total_sent INT NOT NULL DEFAULT 0,
    active_key_index INT NOT NULL DEFAULT 1,
    limit_reached_alert_sent BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.email_usage_tracker ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.email_usage_tracker FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.email_usage_tracker TO service_role, postgres;


-- 2. RPC: register_email_send_attempt (Monthly quota tracker & key failover)
CREATE OR REPLACE FUNCTION public.register_email_send_attempt()
RETURNS JSONB AS $$
DECLARE
    v_period TEXT := to_char(NOW() AT TIME ZONE 'America/Caracas', 'YYYY-MM');
    v_tracker public.email_usage_tracker%ROWTYPE;
    v_key_index INT := 1;
    v_admin_fan_id UUID;
BEGIN
    -- Select or initialize monthly tracker row FOR UPDATE
    SELECT * INTO v_tracker 
    FROM public.email_usage_tracker 
    WHERE period_yyyy_mm = v_period 
    FOR UPDATE;

    IF NOT FOUND THEN
        INSERT INTO public.email_usage_tracker (period_yyyy_mm, total_sent, active_key_index)
        VALUES (v_period, 0, 1)
        RETURNING * INTO v_tracker;
    END IF;

    -- Check if total monthly limit (6,000 emails across both keys) is reached
    IF v_tracker.total_sent >= 6000 THEN
        -- Send alert to admin incidents queue (risk_flags) if not already logged
        IF NOT v_tracker.limit_reached_alert_sent THEN
            SELECT p.id INTO v_admin_fan_id 
            FROM public.profiles p
            JOIN public.staff_members s ON s.user_id = p.id AND s.role = 'admin'
            LIMIT 1;

            IF v_admin_fan_id IS NULL THEN
                SELECT id INTO v_admin_fan_id FROM public.profiles ORDER BY created_at ASC LIMIT 1;
            END IF;

            IF v_admin_fan_id IS NOT NULL THEN
                INSERT INTO public.risk_flags (fan_id, reason, severity, resolved)
                VALUES (
                    v_admin_fan_id,
                    'EMAIL_QUOTA_EXHAUSTED: Ambas API keys de Resend alcanzaron el límite de 3.000 correos mensuales (6.000 total) en el periodo ' || v_period,
                    'high',
                    false
                );
            END IF;

            UPDATE public.email_usage_tracker
            SET limit_reached_alert_sent = true, updated_at = NOW()
            WHERE period_yyyy_mm = v_period;
        END IF;

        RAISE EXCEPTION 'Servicio en mantenimiento. Por favor espera unos minutos antes de volver a intentarlo.' USING ERRCODE = 'P0001';
    END IF;

    -- Key rotation: 0..2999 -> Key 1 | 3000..5999 -> Key 2
    IF v_tracker.total_sent < 3000 THEN
        v_key_index := 1;
    ELSE
        v_key_index := 2;
    END IF;

    -- Increment counter and update tracker
    UPDATE public.email_usage_tracker
    SET total_sent = total_sent + 1,
        active_key_index = v_key_index,
        updated_at = NOW()
    WHERE period_yyyy_mm = v_period;

    RETURN jsonb_build_object(
        'key_index', v_key_index,
        'total_sent', v_tracker.total_sent + 1,
        'period', v_period
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.register_email_send_attempt() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.register_email_send_attempt() TO authenticated, service_role;
