-- ============================================================================
-- Migration: 20261028000012_fase4_platform_admin_panel.sql
-- Description: FASE 4 — Panel de Plataforma (Platform Admin Panel)
--              1. Alter public.teams (add sport column)
--              2. Alter public.audit_log (add team_id column & index)
--              3. Create public.team_billing_events (immutable billing ledger)
--              4. Create public.platform_settings (grace days, reminders)
--              5. Create public.email_outbox (asynchronous email queue)
--              6. Storage bucket team-logos with RLS
--              7. RPC admin_record_team_payment (extends paid_until, audit log)
--              8. RPC admin_toggle_team_status (manual activate/deactivate with reason)
--              9. RPC admin_update_team (update name, colors, sport, logo)
--              10. RPC admin_list_teams (rich listing with billing & follower counts)
--              11. RPC admin_get_platform_analytics (cross-team analytics)
--              12. Scheduled job job_deactivate_expired_teams (grace period auto-deactivation)
--              13. Scheduled job job_send_team_billing_reminders (7d and 1d warnings)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Schema Alterations: teams & audit_log
-- ----------------------------------------------------------------------------

-- Add sport column to teams
ALTER TABLE public.teams 
ADD COLUMN IF NOT EXISTS sport TEXT NOT NULL DEFAULT 'baloncesto';

-- Add team_id to audit_log
ALTER TABLE public.audit_log 
ADD COLUMN IF NOT EXISTS team_id UUID REFERENCES public.teams(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_audit_log_team_id ON public.audit_log(team_id);
CREATE INDEX IF NOT EXISTS idx_teams_paid_until ON public.teams(paid_until);

-- ----------------------------------------------------------------------------
-- 2. Table: public.team_billing_events (Immutable billing history)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.team_billing_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE RESTRICT,
    event_type TEXT NOT NULL,
    amount NUMERIC(12, 2) DEFAULT NULL,
    currency TEXT NOT NULL DEFAULT 'USD',
    period_months INT NOT NULL DEFAULT 1,
    period_start TIMESTAMPTZ NOT NULL DEFAULT now(),
    period_end TIMESTAMPTZ NOT NULL,
    note TEXT,
    registered_by UUID NOT NULL REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_team_billing_events_team_id ON public.team_billing_events(team_id, created_at DESC);

ALTER TABLE public.team_billing_events ENABLE ROW LEVEL SECURITY;

-- Platform Admin has full access to view and record billing events
CREATE POLICY "billing_events_platform_admin_select" ON public.team_billing_events
    FOR SELECT
    TO authenticated
    USING (public.is_platform_admin(auth.uid()));

CREATE POLICY "billing_events_platform_admin_insert" ON public.team_billing_events
    FOR INSERT
    TO authenticated
    WITH CHECK (public.is_platform_admin(auth.uid()));

-- Club Admin can view billing events strictly for their own club
CREATE POLICY "billing_events_club_admin_select" ON public.team_billing_events
    FOR SELECT
    TO authenticated
    USING (team_id = public.current_staff_team_id());

-- Prevent updates or deletes on billing events (immutable ledger rule)
REVOKE UPDATE, DELETE ON TABLE public.team_billing_events FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT ON TABLE public.team_billing_events TO authenticated;
GRANT ALL ON TABLE public.team_billing_events TO service_role;

-- ----------------------------------------------------------------------------
-- 3. Table: public.platform_settings
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.platform_settings (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.platform_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "platform_settings_read" ON public.platform_settings
    FOR SELECT
    TO authenticated
    USING (public.is_platform_admin(auth.uid()));

CREATE POLICY "platform_settings_write" ON public.platform_settings
    FOR ALL
    TO authenticated
    USING (public.is_platform_admin(auth.uid()))
    WITH CHECK (public.is_platform_admin(auth.uid()));

REVOKE ALL ON TABLE public.platform_settings FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE ON TABLE public.platform_settings TO authenticated;
GRANT ALL ON TABLE public.platform_settings TO service_role;

-- Defaults
INSERT INTO public.platform_settings (key, value)
VALUES 
    ('billing_grace_days', '3'::jsonb),
    ('billing_reminder_days', '[7, 1]'::jsonb)
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now();

-- ----------------------------------------------------------------------------
-- 4. Table: public.email_outbox (Asynchronous email queue)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.email_outbox (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_email TEXT NOT NULL,
    subject TEXT NOT NULL,
    body_html TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    status TEXT NOT NULL DEFAULT 'pending',
    error TEXT,
    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_email_outbox_pending ON public.email_outbox(status, created_at) WHERE (status = 'pending');

ALTER TABLE public.email_outbox ENABLE ROW LEVEL SECURITY;

CREATE POLICY "email_outbox_platform_admin_select" ON public.email_outbox
    FOR SELECT
    TO authenticated
    USING (public.is_platform_admin(auth.uid()));

REVOKE ALL ON TABLE public.email_outbox FROM PUBLIC, anon;
GRANT SELECT ON TABLE public.email_outbox TO authenticated;
GRANT ALL ON TABLE public.email_outbox TO service_role;

-- ----------------------------------------------------------------------------
-- 5. Storage: bucket team-logos
-- ----------------------------------------------------------------------------

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'team-logos',
    'team-logos',
    true,
    2097152, -- 2 MB
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/svg+xml']::text[]
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 2097152,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/svg+xml']::text[];

-- Storage policies for team-logos
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'team_logos_public_read'
    ) THEN
        CREATE POLICY "team_logos_public_read" ON storage.objects
            FOR SELECT TO anon, authenticated USING (bucket_id = 'team-logos');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'team_logos_platform_write'
    ) THEN
        CREATE POLICY "team_logos_platform_write" ON storage.objects
            FOR ALL TO authenticated
            USING (bucket_id = 'team-logos' AND public.is_platform_admin(auth.uid()))
            WITH CHECK (bucket_id = 'team-logos' AND public.is_platform_admin(auth.uid()));
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 6. RPC: admin_record_team_payment (Extends paid_until, logs event & audit)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.admin_record_team_payment(
    p_team_id UUID,
    p_event_type TEXT,
    p_amount NUMERIC DEFAULT NULL,
    p_months INT DEFAULT 1,
    p_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_actor_id UUID := auth.uid();
    v_team RECORD;
    v_now TIMESTAMPTZ := now();
    v_period_start TIMESTAMPTZ;
    v_new_paid_until TIMESTAMPTZ;
    v_billing_id UUID;
    v_months INT := COALESCE(p_months, 1);
BEGIN
    PERFORM public.assert_admin();

    IF NOT public.is_platform_admin(v_actor_id) THEN
        RAISE EXCEPTION 'Solo los administradores de plataforma pueden registrar pagos.' USING ERRCODE = '42501';
    END IF;

    IF v_months < 1 THEN
        RAISE EXCEPTION 'El período de extensión debe ser de al menos 1 mes.' USING ERRCODE = 'P0001';
    END IF;

    SELECT id, name, slug, status, paid_until INTO v_team
    FROM public.teams
    WHERE id = p_team_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Equipo no encontrado.' USING ERRCODE = 'P0002';
    END IF;

    -- Calculate periods
    IF v_team.paid_until IS NULL OR v_team.paid_until < v_now THEN
        v_period_start := v_now;
        v_new_paid_until := v_now + (v_months || ' months')::interval;
    ELSE
        v_period_start := v_team.paid_until;
        v_new_paid_until := v_team.paid_until + (v_months || ' months')::interval;
    END IF;

    -- Update team paid_until (and reactivate if it was inactive due to billing)
    UPDATE public.teams
    SET paid_until = v_new_paid_until,
        status = CASE WHEN status = 'inactive' THEN 'active' ELSE status END,
        updated_at = v_now
    WHERE id = p_team_id;

    -- Insert billing event
    INSERT INTO public.team_billing_events (
        team_id, event_type, amount, period_months, period_start, period_end, note, registered_by, created_at
    ) VALUES (
        p_team_id, p_event_type, p_amount, v_months, v_period_start, v_new_paid_until, p_note, v_actor_id, v_now
    ) RETURNING id INTO v_billing_id;

    -- Record in audit_log
    INSERT INTO public.audit_log (
        actor_id, team_id, action, entity, entity_id, before, after
    ) VALUES (
        v_actor_id,
        p_team_id,
        'team_payment_recorded',
        'teams',
        p_team_id::text,
        jsonb_build_object('paid_until', v_team.paid_until, 'status', v_team.status),
        jsonb_build_object('paid_until', v_new_paid_until, 'months', v_months, 'amount', p_amount, 'event_type', p_event_type, 'billing_id', v_billing_id)
    );

    RETURN jsonb_build_object(
        'success', true,
        'billing_id', v_billing_id,
        'team_id', p_team_id,
        'previous_paid_until', v_team.paid_until,
        'new_paid_until', v_new_paid_until,
        'message', 'Pago registrado exitosamente y período extendido.'
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_record_team_payment(UUID, TEXT, NUMERIC, INT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_record_team_payment(UUID, TEXT, NUMERIC, INT, TEXT) TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 7. RPC: admin_toggle_team_status (Manual activate / deactivate with audit)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.admin_toggle_team_status(
    p_team_id UUID,
    p_status public.team_status,
    p_reason TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_actor_id UUID := auth.uid();
    v_team RECORD;
    v_now TIMESTAMPTZ := now();
BEGIN
    PERFORM public.assert_admin();

    IF NOT public.is_platform_admin(v_actor_id) THEN
        RAISE EXCEPTION 'Solo los administradores de plataforma pueden cambiar el estado de un equipo.' USING ERRCODE = '42501';
    END IF;

    IF p_reason IS NULL OR trim(p_reason) = '' THEN
        RAISE EXCEPTION 'Debe proporcionar un motivo para el cambio de estado.' USING ERRCODE = 'P0001';
    END IF;

    SELECT id, name, slug, status INTO v_team
    FROM public.teams
    WHERE id = p_team_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Equipo no encontrado.' USING ERRCODE = 'P0002';
    END IF;

    UPDATE public.teams
    SET status = p_status,
        updated_at = v_now
    WHERE id = p_team_id;

    INSERT INTO public.audit_log (
        actor_id, team_id, action, entity, entity_id, before, after
    ) VALUES (
        v_actor_id,
        p_team_id,
        'team_status_changed',
        'teams',
        p_team_id::text,
        jsonb_build_object('status', v_team.status),
        jsonb_build_object('status', p_status, 'reason', p_reason)
    );

    RETURN jsonb_build_object(
        'success', true,
        'team_id', p_team_id,
        'previous_status', v_team.status,
        'new_status', p_status,
        'reason', p_reason
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_toggle_team_status(UUID, public.team_status, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_toggle_team_status(UUID, public.team_status, TEXT) TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 8. RPC: admin_update_team (Update general team attributes)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.admin_update_team(
    p_team_id UUID,
    p_name TEXT,
    p_short_name TEXT DEFAULT NULL,
    p_sport TEXT DEFAULT 'baloncesto',
    p_primary_color TEXT DEFAULT NULL,
    p_secondary_color TEXT DEFAULT NULL,
    p_logo_url TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_actor_id UUID := auth.uid();
    v_is_platform BOOLEAN := public.is_platform_admin(v_actor_id);
    v_staff_team UUID := public.current_staff_team_id();
    v_team RECORD;
    v_now TIMESTAMPTZ := now();
BEGIN
    PERFORM public.assert_admin();

    -- Authorization: must be platform admin OR club admin for this team
    IF NOT v_is_platform AND (v_staff_team IS NULL OR v_staff_team != p_team_id) THEN
        RAISE EXCEPTION 'No tienes autorización para editar este equipo.' USING ERRCODE = '42501';
    END IF;

    IF p_name IS NULL OR trim(p_name) = '' THEN
        RAISE EXCEPTION 'El nombre del equipo no puede estar vacío.' USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_team FROM public.teams WHERE id = p_team_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Equipo no encontrado.' USING ERRCODE = 'P0002';
    END IF;

    UPDATE public.teams
    SET name = trim(p_name),
        short_name = NULLIF(trim(p_short_name), ''),
        sport = COALESCE(NULLIF(trim(p_sport), ''), v_team.sport),
        primary_color = COALESCE(NULLIF(trim(p_primary_color), ''), v_team.primary_color),
        secondary_color = COALESCE(NULLIF(trim(p_secondary_color), ''), v_team.secondary_color),
        logo_url = COALESCE(p_logo_url, v_team.logo_url),
        updated_at = v_now
    WHERE id = p_team_id;

    INSERT INTO public.audit_log (
        actor_id, team_id, action, entity, entity_id, before, after
    ) VALUES (
        v_actor_id,
        p_team_id,
        'team_updated',
        'teams',
        p_team_id::text,
        jsonb_build_object('name', v_team.name, 'short_name', v_team.short_name, 'sport', v_team.sport),
        jsonb_build_object('name', p_name, 'short_name', p_short_name, 'sport', p_sport)
    );

    RETURN jsonb_build_object(
        'success', true,
        'team_id', p_team_id,
        'message', 'Equipo actualizado correctamente.'
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_update_team(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_team(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 9. RPC: admin_list_teams (Rich platform listing with counts & payment status)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.admin_list_teams(
    p_search TEXT DEFAULT NULL,
    p_status TEXT DEFAULT NULL,
    p_billing_status TEXT DEFAULT NULL,
    p_limit INT DEFAULT 50,
    p_offset INT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_actor_id UUID := auth.uid();
    v_now TIMESTAMPTZ := now();
    v_res JSONB;
    v_total BIGINT;
BEGIN
    PERFORM public.assert_admin();

    IF NOT public.is_platform_admin(v_actor_id) THEN
        RAISE EXCEPTION 'Solo los administradores de plataforma pueden listar todos los equipos.' USING ERRCODE = '42501';
    END IF;

    WITH filtered AS (
        SELECT 
            t.id,
            t.name,
            t.slug,
            t.short_name,
            t.logo_url,
            t.primary_color,
            t.secondary_color,
            t.status,
            t.sport,
            t.joined_at,
            t.paid_until,
            CASE 
                WHEN t.paid_until IS NULL THEN 'no_payment'
                WHEN t.paid_until < v_now THEN 'expired'
                WHEN t.paid_until <= v_now + INTERVAL '7 days' THEN 'expiring_soon'
                ELSE 'current'
            END AS billing_status,
            COALESCE(tf_count.followers, 0)::int AS team_follower_count,
            COALESCE(sm_count.active_staff, 0)::int AS active_staff_count
        FROM public.teams t
        LEFT JOIN (
            SELECT team_id, count(*) AS followers
            FROM public.team_follows
            GROUP BY team_id
        ) tf_count ON tf_count.team_id = t.id
        LEFT JOIN (
            SELECT team_id, count(*) AS active_staff
            FROM public.staff_members
            WHERE active = true
            GROUP BY team_id
        ) sm_count ON sm_count.team_id = t.id
        WHERE (p_search IS NULL OR t.name ILIKE '%' || trim(p_search) || '%' OR t.slug ILIKE '%' || trim(p_search) || '%')
          AND (p_status IS NULL OR p_status = 'all' OR t.status::text = p_status)
    ),
    filtered_with_billing AS (
        SELECT * FROM filtered
        WHERE (p_billing_status IS NULL OR p_billing_status = 'all' OR billing_status = p_billing_status)
    )
    SELECT 
        (SELECT count(*) FROM filtered_with_billing) AS total_count,
        COALESCE(jsonb_agg(to_jsonb(r.*) ORDER BY r.joined_at ASC), '[]'::jsonb) AS teams_json
    INTO v_total, v_res
    FROM (
        SELECT * FROM filtered_with_billing
        LIMIT COALESCE(p_limit, 50)
        OFFSET COALESCE(p_offset, 0)
    ) r;

    RETURN jsonb_build_object(
        'total', COALESCE(v_total, 0),
        'teams', COALESCE(v_res, '[]'::jsonb)
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_list_teams(TEXT, TEXT, TEXT, INT, INT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_teams(TEXT, TEXT, TEXT, INT, INT) TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 10. RPC: admin_get_platform_analytics (Cross-team metrics)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.admin_get_platform_analytics()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_actor_id UUID := auth.uid();
    v_total_teams INT;
    v_active_teams INT;
    v_total_fans INT;
    v_total_pearls_issued BIGINT;
    v_total_pearls_redeemed BIGINT;
    v_teams_breakdown JSONB;
    v_trend_30d JSONB;
BEGIN
    PERFORM public.assert_admin();

    IF NOT public.is_platform_admin(v_actor_id) THEN
        RAISE EXCEPTION 'Solo los administradores de plataforma pueden consultar analítica global.' USING ERRCODE = '42501';
    END IF;

    SELECT count(*)::int, count(*) FILTER (WHERE status = 'active')::int
    INTO v_total_teams, v_active_teams
    FROM public.teams;

    SELECT count(DISTINCT id)::int INTO v_total_fans
    FROM public.profiles
    WHERE status = 'active';

    SELECT 
        COALESCE(SUM(amount) FILTER (WHERE amount > 0 AND status = 'confirmed'), 0)::bigint,
        COALESCE(ABS(SUM(amount) FILTER (WHERE amount < 0 AND status = 'confirmed')), 0)::bigint
    INTO v_total_pearls_issued, v_total_pearls_redeemed
    FROM public.ledger_entries;

    -- Per-team breakdown
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'team_id', t.id,
        'team_name', t.name,
        'team_slug', t.slug,
        'status', t.status,
        'sport', t.sport,
        'followers', COALESCE(tf.cnt, 0),
        'active_staff', COALESCE(sm.cnt, 0),
        'pearls_issued', COALESCE(le.issued, 0),
        'pearls_redeemed', COALESCE(le.redeemed, 0),
        'redemptions_count', COALESCE(rc.cnt, 0)
    )), '[]'::jsonb)
    INTO v_teams_breakdown
    FROM public.teams t
    LEFT JOIN (SELECT team_id, count(*) AS cnt FROM public.team_follows GROUP BY team_id) tf ON tf.team_id = t.id
    LEFT JOIN (SELECT team_id, count(*) AS cnt FROM public.staff_members WHERE active = true GROUP BY team_id) sm ON sm.team_id = t.id
    LEFT JOIN (
        SELECT team_id,
               COALESCE(SUM(amount) FILTER (WHERE amount > 0 AND status = 'confirmed'), 0) AS issued,
               COALESCE(ABS(SUM(amount) FILTER (WHERE amount < 0 AND status = 'confirmed')), 0) AS redeemed
        FROM public.ledger_entries
        GROUP BY team_id
    ) le ON le.team_id = t.id
    LEFT JOIN (SELECT team_id, count(*) AS cnt FROM public.redemptions GROUP BY team_id) rc ON rc.team_id = t.id;

    -- 30-day activity trend
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'date', d.day::date,
        'pearls_issued', COALESCE(SUM(l.amount) FILTER (WHERE l.amount > 0 AND l.status = 'confirmed'), 0),
        'pearls_redeemed', COALESCE(ABS(SUM(l.amount) FILTER (WHERE l.amount < 0 AND l.status = 'confirmed')), 0)
    ) ORDER BY d.day ASC), '[]'::jsonb)
    INTO v_trend_30d
    FROM generate_series(CURRENT_DATE - INTERVAL '29 days', CURRENT_DATE, '1 day'::interval) d(day)
    LEFT JOIN public.ledger_entries l ON l.created_at::date = d.day::date
    GROUP BY d.day;

    RETURN jsonb_build_object(
        'total_teams', v_total_teams,
        'active_teams', v_active_teams,
        'total_fans', v_total_fans,
        'total_pearls_issued', v_total_pearls_issued,
        'total_pearls_redeemed', v_total_pearls_redeemed,
        'teams', v_teams_breakdown,
        'trend_30d', v_trend_30d
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_get_platform_analytics() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_get_platform_analytics() TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 11. Scheduled Job: job_deactivate_expired_teams (Daily auto-deactivation)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.job_deactivate_expired_teams()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_grace_days INT := 3;
    v_deactivated_count INT := 0;
    v_team RECORD;
    v_admin_record RECORD;
    v_now TIMESTAMPTZ := now();
BEGIN
    SELECT COALESCE((value)::int, 3) INTO v_grace_days
    FROM public.platform_settings
    WHERE key = 'billing_grace_days';

    FOR v_team IN
        SELECT id, name, slug, paid_until
        FROM public.teams
        WHERE status = 'active'
          AND paid_until IS NOT NULL
          AND v_now > (paid_until + (v_grace_days || ' days')::interval)
    LOOP
        -- Update status to inactive
        UPDATE public.teams
        SET status = 'inactive',
            updated_at = v_now
        WHERE id = v_team.id;

        v_deactivated_count := v_deactivated_count + 1;

        -- Record in audit log
        INSERT INTO public.audit_log (
            actor_id, team_id, action, entity, entity_id, before, after
        ) VALUES (
            NULL,
            v_team.id,
            'team_auto_deactivated',
            'teams',
            v_team.id::text,
            jsonb_build_object('status', 'active', 'paid_until', v_team.paid_until),
            jsonb_build_object('status', 'inactive', 'reason', 'Período de gracia por vencimiento de pago agotado (' || v_grace_days || ' días).')
        );

        -- Notify team admins in-app and via email outbox
        FOR v_admin_record IN
            SELECT sm.user_id, u.email, p.display_name
            FROM public.staff_members sm
            JOIN auth.users u ON u.id = sm.user_id
            JOIN public.profiles p ON p.id = sm.user_id
            WHERE sm.team_id = v_team.id
              AND sm.role = 'admin'
              AND sm.active = true
        LOOP
            -- In-app notification
            INSERT INTO public.notifications (
                user_id, type, title, body, data, dedup_key
            ) VALUES (
                v_admin_record.user_id,
                'team_billing_warning',
                'Equipo Suspendido por Pago Vencido',
                'El servicio para ' || v_team.name || ' ha sido desactivado al finalizar el período de gracia. Regularice el pago para reactivar.',
                jsonb_build_object('team_id', v_team.id, 'paid_until', v_team.paid_until),
                'team_deactivated_' || v_team.id::text || '_' || v_now::date::text
            ) ON CONFLICT (user_id, dedup_key) DO NOTHING;

            -- Email outbox queue
            INSERT INTO public.email_outbox (
                recipient_email, subject, body_html, metadata
            ) VALUES (
                v_admin_record.email,
                'Aviso Importante: Suspensión de cuenta de club (' || v_team.name || ')',
                '<p>Estimado/a ' || COALESCE(v_admin_record.display_name, 'Administrador') || ':</p>' ||
                '<p>El período de gracia para <strong>' || v_team.name || '</strong> ha concluido y el equipo ha pasado a estado inactivo.</p>' ||
                '<p>Por favor contacte a la administración de la plataforma para registrar el pago correspondiente y restablecer el servicio.</p>',
                jsonb_build_object('team_id', v_team.id, 'action', 'auto_deactivation')
            );
        END LOOP;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'deactivated_teams', v_deactivated_count,
        'grace_days_used', v_grace_days,
        'executed_at', v_now
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.job_deactivate_expired_teams() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.job_deactivate_expired_teams() TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 12. Scheduled Job: job_send_team_billing_reminders (7d and 1d warnings)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.job_send_team_billing_reminders()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_reminders_sent INT := 0;
    v_team RECORD;
    v_admin_record RECORD;
    v_days_left INT;
    v_now TIMESTAMPTZ := now();
    v_dedup TEXT;
BEGIN
    FOR v_team IN
        SELECT id, name, paid_until,
               CEIL(EXTRACT(EPOCH FROM (paid_until - v_now)) / 86400)::int AS days_remaining
        FROM public.teams
        WHERE status = 'active'
          AND paid_until IS NOT NULL
          AND paid_until > v_now
    LOOP
        v_days_left := v_team.days_remaining;

        -- Send only when exactly 7 days or 1 day remain
        IF v_days_left IN (7, 1) THEN
            v_dedup := 'billing_remind_' || v_team.id::text || '_' || v_days_left::text || 'd_' || v_team.paid_until::date::text;

            FOR v_admin_record IN
                SELECT sm.user_id, u.email, p.display_name
                FROM public.staff_members sm
                JOIN auth.users u ON u.id = sm.user_id
                JOIN public.profiles p ON p.id = sm.user_id
                WHERE sm.team_id = v_team.id
                  AND sm.role = 'admin'
                  AND sm.active = true
            LOOP
                -- In-app notification
                INSERT INTO public.notifications (
                    user_id, type, title, body, data, dedup_key
                ) VALUES (
                    v_admin_record.user_id,
                    'team_billing_warning',
                    'Vencimiento de Suscripción Próximo',
                    'La suscripción de ' || v_team.name || ' vencerá en ' || v_days_left || ' día(s). Coordina tu pago para evitar interrupciones.',
                    jsonb_build_object('team_id', v_team.id, 'days_remaining', v_days_left, 'paid_until', v_team.paid_until),
                    v_dedup || '_' || v_admin_record.user_id::text
                ) ON CONFLICT (user_id, dedup_key) DO NOTHING;

                -- Email outbox
                INSERT INTO public.email_outbox (
                    recipient_email, subject, body_html, metadata
                ) VALUES (
                    v_admin_record.email,
                    'Recordatorio de Vencimiento: ' || v_team.name || ' (' || v_days_left || ' día' || (CASE WHEN v_days_left > 1 THEN 's' ELSE '' END) || ')',
                    '<p>Estimado/a ' || COALESCE(v_admin_record.display_name, 'Administrador') || ':</p>' ||
                    '<p>Le recordamos que la suscripción de su equipo <strong>' || v_team.name || '</strong> vencerá en <strong>' || v_days_left || ' día(s)</strong>.</p>' ||
                    '<p>Fecha de vencimiento: ' || to_char(v_team.paid_until, 'YYYY-MM-DD HH24:MI') || '</p>',
                    jsonb_build_object('team_id', v_team.id, 'days_remaining', v_days_left)
                );

                v_reminders_sent := v_reminders_sent + 1;
            END LOOP;
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'reminders_sent', v_reminders_sent,
        'executed_at', v_now
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.job_send_team_billing_reminders() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.job_send_team_billing_reminders() TO authenticated, service_role;
