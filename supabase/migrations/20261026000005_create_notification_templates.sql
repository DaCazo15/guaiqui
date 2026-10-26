-- Migration: 20261026000005_create_notification_templates.sql
-- Description: Creates notification_templates table, notification automation for trivias and held pearls, and admin management RPCs.

-- 1. Create notification_templates table
CREATE TABLE IF NOT EXISTS public.notification_templates (
    id TEXT NOT NULL,
    title_template TEXT NOT NULL,
    body_template TEXT NOT NULL,
    description TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('trivias', 'economy', 'system')),
    available_variables JSONB NOT NULL DEFAULT '[]'::jsonb,
    is_active BOOLEAN NOT NULL DEFAULT true,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by UUID REFERENCES public.profiles(id),
    CONSTRAINT notification_templates_pkey PRIMARY KEY (id)
);

-- Enable RLS
ALTER TABLE public.notification_templates ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'notification_templates' AND policyname = 'Anyone authenticated can view notification templates'
    ) THEN
        CREATE POLICY "Anyone authenticated can view notification templates"
            ON public.notification_templates
            FOR SELECT
            TO authenticated
            USING (true);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'notification_templates' AND policyname = 'Admins can update notification templates'
    ) THEN
        CREATE POLICY "Admins can update notification templates"
            ON public.notification_templates
            FOR UPDATE
            TO authenticated
            USING (
                EXISTS (
                    SELECT 1 FROM public.staff_members sm
                    WHERE sm.user_id = auth.uid()
                      AND sm.role = 'admin'
                      AND sm.active = true
                )
            )
            WITH CHECK (
                EXISTS (
                    SELECT 1 FROM public.staff_members sm
                    WHERE sm.user_id = auth.uid()
                      AND sm.role = 'admin'
                      AND sm.active = true
                )
            );
    END IF;
END $$;

-- 2. Seed initial 4 notification templates
INSERT INTO public.notification_templates (id, title_template, body_template, description, category, available_variables, is_active)
VALUES
    (
        'new_trivia',
        '¡Nueva trivia disponible en La Tribu!',
        'Participa en "{trivia_title}" y gana hasta {reward_pearls} perlitas para canjear por premios.',
        'Notificación enviada a los fanáticos cuando se publica una nueva trivia o reto.',
        'trivias',
        '[
            {"key": "trivia_title", "label": "Nombre del reto / trivia"},
            {"key": "reward_pearls", "label": "Perlitas de recompensa"},
            {"key": "trivia_type", "label": "Tipo de trivia (clásica, silueta, etc.)"}
        ]'::jsonb,
        true
    ),
    (
        'trivia_expiring',
        '¡Últimas horas para jugar "{trivia_title}"!',
        'La trivia "{trivia_title}" finaliza pronto (quedan {hours_left} horas). ¡Participa antes de que cierre!',
        'Aviso recordatorio a fanáticos antes de la fecha límite para trivias no completadas.',
        'trivias',
        '[
            {"key": "trivia_title", "label": "Nombre del reto / trivia"},
            {"key": "hours_left", "label": "Horas restantes para el cierre"}
        ]'::jsonb,
        true
    ),
    (
        'pearls_released',
        '¡Tus perlitas retenidas han sido liberadas!',
        'Se han acreditado {pearls} perlitas en tu billetera tras la verificación de seguridad. Nota: {note}.',
        'Aviso enviado al fanático cuando el administrador aprueba y libera perlitas que estaban en estado retenido.',
        'economy',
        '[
            {"key": "pearls", "label": "Cantidad de perlitas liberadas"},
            {"key": "note", "label": "Motivo / nota del administrador"}
        ]'::jsonb,
        true
    ),
    (
        'pearls_revoked',
        'Aviso sobre tus perlitas retenidas',
        'Las {pearls} perlitas retenidas no fueron liberadas tras la auditoría de seguridad. Motivo: {note}.',
        'Aviso enviado al fanático cuando el administrador revoca y no libera perlitas que estaban retenidas.',
        'economy',
        '[
            {"key": "pearls", "label": "Cantidad de perlitas retenidas"},
            {"key": "note", "label": "Motivo / nota del administrador"}
        ]'::jsonb,
        true
    )
ON CONFLICT (id) DO UPDATE SET
    title_template = EXCLUDED.title_template,
    body_template = EXCLUDED.body_template,
    description = EXCLUDED.description,
    category = EXCLUDED.category,
    available_variables = EXCLUDED.available_variables;

-- 3. Helper: Template variable interpolation
CREATE OR REPLACE FUNCTION public.format_notification_text(p_text text, p_params jsonb)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_res text := p_text;
    v_key text;
    v_val text;
BEGIN
    IF p_params IS NULL OR p_params = '{}'::jsonb THEN
        RETURN v_res;
    END IF;

    FOR v_key, v_val IN SELECT key, value#>>'{}' FROM jsonb_each(p_params) LOOP
        v_res := replace(v_res, '{' || v_key || '}', COALESCE(v_val, ''));
    END LOOP;

    RETURN v_res;
END;
$$;

-- 4. Admin RPC to update templates
CREATE OR REPLACE FUNCTION public.admin_update_notification_template(
    p_template_id text,
    p_title_template text,
    p_body_template text,
    p_is_active boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_updated_template notification_templates%ROWTYPE;
BEGIN
    PERFORM public.assert_admin();

    IF trim(COALESCE(p_title_template, '')) = '' THEN
        RAISE EXCEPTION 'El título de la plantilla no puede estar vacío.';
    END IF;

    IF trim(COALESCE(p_body_template, '')) = '' THEN
        RAISE EXCEPTION 'El cuerpo de la plantilla no puede estar vacío.';
    END IF;

    UPDATE public.notification_templates
    SET
        title_template = trim(p_title_template),
        body_template = trim(p_body_template),
        is_active = COALESCE(p_is_active, true),
        updated_at = NOW(),
        updated_by = v_admin_id
    WHERE id = p_template_id
    RETURNING * INTO v_updated_template;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Plantilla de notificación "%" no encontrada.', p_template_id;
    END IF;

    -- Audit log entry
    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id,
        'update_notification_template',
        'notification_templates',
        p_template_id,
        jsonb_build_object(
            'title_template', v_updated_template.title_template,
            'body_template', v_updated_template.body_template,
            'is_active', v_updated_template.is_active
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'template', jsonb_build_object(
            'id', v_updated_template.id,
            'title_template', v_updated_template.title_template,
            'body_template', v_updated_template.body_template,
            'description', v_updated_template.description,
            'category', v_updated_template.category,
            'available_variables', v_updated_template.available_variables,
            'is_active', v_updated_template.is_active,
            'updated_at', v_updated_template.updated_at
        )
    );
END;
$$;

-- 5. Update admin_release_held_pearls to dispatch notification
CREATE OR REPLACE FUNCTION public.admin_release_held_pearls(p_ledger_id uuid, p_note text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_entry public.ledger_entries%ROWTYPE;
    v_release_entry_id UUID := gen_random_uuid();
    v_tmpl notification_templates%ROWTYPE;
    v_title TEXT;
    v_body TEXT;
    v_params JSONB;
BEGIN
    PERFORM public.assert_admin();

    IF p_note IS NULL OR trim(p_note) = '' THEN
        RAISE EXCEPTION 'La justificación es obligatoria para liberar perlitas retenidas.';
    END IF;

    SELECT * INTO v_entry FROM public.ledger_entries WHERE id = p_ledger_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Registro de libro no encontrado.';
    END IF;

    IF v_entry.status != 'held' THEN
        RAISE EXCEPTION 'El registro no se encuentra en estado retenido (held).';
    END IF;

    IF EXISTS (SELECT 1 FROM public.ledger_hold_resolutions WHERE ledger_id = p_ledger_id) THEN
        RAISE EXCEPTION 'El registro retenido ya ha sido resuelto previamente (liberado o revocado).';
    END IF;

    -- A) Insert Resolution Record
    INSERT INTO public.ledger_hold_resolutions (
        ledger_id, action, note, resolved_by
    ) VALUES (
        p_ledger_id, 'release', p_note, v_admin_id
    );

    -- B) Append-Only: Insert NEW Confirmed Entry in Ledger
    INSERT INTO public.ledger_entries (
        id, fan_id, amount, type, status, source_type, source_id, note
    ) VALUES (
        v_release_entry_id, v_entry.fan_id, v_entry.amount, v_entry.type, 'confirmed', 'hold_release', p_ledger_id::text,
        'Liberado por admin: ' || p_note
    );

    -- C) Update Wallet Balance Cache
    INSERT INTO public.wallets (fan_id, balance_cache)
    VALUES (v_entry.fan_id, v_entry.amount)
    ON CONFLICT (fan_id)
    DO UPDATE SET balance_cache = wallets.balance_cache + v_entry.amount, updated_at = NOW();

    -- D) Audit Log
    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'release_held_pearls', 'ledger_entries', p_ledger_id::text,
        jsonb_build_object('fan_id', v_entry.fan_id, 'amount', v_entry.amount, 'note', p_note, 'release_entry_id', v_release_entry_id)
    );

    -- E) Send Notification to Fan
    SELECT * INTO v_tmpl FROM public.notification_templates WHERE id = 'pearls_released';
    IF FOUND AND v_tmpl.is_active THEN
        v_params := jsonb_build_object(
            'pearls', v_entry.amount::text,
            'note', p_note
        );
        v_title := public.format_notification_text(v_tmpl.title_template, v_params);
        v_body := public.format_notification_text(v_tmpl.body_template, v_params);

        PERFORM public.create_notification(
            v_entry.fan_id,
            'pearls_released',
            v_title,
            v_body,
            jsonb_build_object('url', '/app/billetera', 'ledger_id', p_ledger_id),
            'pearls_released_' || p_ledger_id::text
        );
    END IF;

    RETURN jsonb_build_object(
        'status', 'released',
        'ledger_id', p_ledger_id,
        'release_entry_id', v_release_entry_id,
        'amount', v_entry.amount
    );
END;
$$;

-- 6. Update admin_revoke_held_pearls to dispatch notification
CREATE OR REPLACE FUNCTION public.admin_revoke_held_pearls(p_ledger_id uuid, p_note text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_entry public.ledger_entries%ROWTYPE;
    v_tmpl notification_templates%ROWTYPE;
    v_title TEXT;
    v_body TEXT;
    v_params JSONB;
BEGIN
    PERFORM public.assert_admin();

    IF p_note IS NULL OR trim(p_note) = '' THEN
        RAISE EXCEPTION 'La justificación es obligatoria para revocar perlitas retenidas.';
    END IF;

    SELECT * INTO v_entry FROM public.ledger_entries WHERE id = p_ledger_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Registro de libro no encontrado.';
    END IF;

    IF v_entry.status != 'held' THEN
        RAISE EXCEPTION 'El registro no se encuentra en estado retenido (held).';
    END IF;

    IF EXISTS (SELECT 1 FROM public.ledger_hold_resolutions WHERE ledger_id = p_ledger_id) THEN
        RAISE EXCEPTION 'El registro retenido ya ha sido resuelto previamente (liberado o revocado).';
    END IF;

    -- A) Insert Resolution Record
    INSERT INTO public.ledger_hold_resolutions (
        ledger_id, action, note, resolved_by
    ) VALUES (
        p_ledger_id, 'revoke', p_note, v_admin_id
    );

    -- B) Audit Log
    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (
        v_admin_id, 'revoke_held_pearls', 'ledger_entries', p_ledger_id::text,
        jsonb_build_object('fan_id', v_entry.fan_id, 'amount', v_entry.amount, 'note', p_note)
    );

    -- C) Send Notification to Fan
    SELECT * INTO v_tmpl FROM public.notification_templates WHERE id = 'pearls_revoked';
    IF FOUND AND v_tmpl.is_active THEN
        v_params := jsonb_build_object(
            'pearls', v_entry.amount::text,
            'note', p_note
        );
        v_title := public.format_notification_text(v_tmpl.title_template, v_params);
        v_body := public.format_notification_text(v_tmpl.body_template, v_params);

        PERFORM public.create_notification(
            v_entry.fan_id,
            'pearls_revoked',
            v_title,
            v_body,
            jsonb_build_object('url', '/app/billetera', 'ledger_id', p_ledger_id),
            'pearls_revoked_' || p_ledger_id::text
        );
    END IF;

    RETURN jsonb_build_object(
        'status', 'revoked',
        'ledger_id', p_ledger_id,
        'amount', v_entry.amount
    );
END;
$$;

-- 7. Function to notify all active fans of a new published trivia
CREATE OR REPLACE FUNCTION public.notify_fans_new_trivia(
    p_trivia_id uuid,
    p_title text,
    p_reward_pearls int,
    p_trivia_type text DEFAULT 'trivia'
)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_tmpl notification_templates%ROWTYPE;
    v_fan RECORD;
    v_title TEXT;
    v_body TEXT;
    v_params JSONB;
    v_count INT := 0;
BEGIN
    SELECT * INTO v_tmpl FROM public.notification_templates WHERE id = 'new_trivia';
    IF NOT FOUND OR NOT v_tmpl.is_active THEN
        RETURN 0;
    END IF;

    v_params := jsonb_build_object(
        'trivia_title', p_title,
        'reward_pearls', p_reward_pearls::text,
        'trivia_type', p_trivia_type
    );
    v_title := public.format_notification_text(v_tmpl.title_template, v_params);
    v_body := public.format_notification_text(v_tmpl.body_template, v_params);

    FOR v_fan IN
        SELECT id FROM public.profiles
        WHERE role = 'fan'
          AND status = 'active'
    LOOP
        PERFORM public.create_notification(
            v_fan.id,
            'new_trivia',
            v_title,
            v_body,
            jsonb_build_object(
                'url', '/app/trivias',
                'trivia_id', p_trivia_id,
                'trivia_type', p_trivia_type
            ),
            'new_trivia_' || p_trivia_id::text || '_' || v_fan.id::text
        );
        v_count := v_count + 1;
    END LOOP;

    RETURN v_count;
END;
$$;

-- 8. Trigger on trivias table when status becomes 'published'
CREATE OR REPLACE FUNCTION public.trg_notify_on_trivia_published()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
    IF (TG_OP = 'INSERT' AND NEW.status = 'published') OR
       (TG_OP = 'UPDATE' AND NEW.status = 'published' AND OLD.status != 'published') THEN
        PERFORM public.notify_fans_new_trivia(
            NEW.id,
            NEW.title,
            NEW.reward_pearls,
            'trivia'
        );
    END IF;
    RETURN NEW;
END;
$$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'trg_trivias_publish_notification'
    ) THEN
        CREATE TRIGGER trg_trivias_publish_notification
            AFTER INSERT OR UPDATE ON public.trivias
            FOR EACH ROW
            EXECUTE FUNCTION public.trg_notify_on_trivia_published();
    END IF;
END $$;

-- 9. Cron/Scheduled function: Notify expiring trivias
CREATE OR REPLACE FUNCTION public.cron_notify_expiring_trivias()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_tmpl notification_templates%ROWTYPE;
    v_trivia RECORD;
    v_fan RECORD;
    v_title TEXT;
    v_body TEXT;
    v_params JSONB;
    v_hours_left INT;
    v_notif_count INT := 0;
BEGIN
    SELECT * INTO v_tmpl FROM public.notification_templates WHERE id = 'trivia_expiring';
    IF NOT FOUND OR NOT v_tmpl.is_active THEN
        RETURN 0;
    END IF;

    -- Trivias closing in less than 24h but still active
    FOR v_trivia IN
        SELECT id, title, ends_at
        FROM public.trivias
        WHERE status = 'published'
          AND ends_at > NOW()
          AND ends_at <= (NOW() + INTERVAL '24 hours')
    LOOP
        v_hours_left := GREATEST(1, ROUND(EXTRACT(EPOCH FROM (v_trivia.ends_at - NOW())) / 3600))::int;

        v_params := jsonb_build_object(
            'trivia_title', v_trivia.title,
            'hours_left', v_hours_left::text
        );
        v_title := public.format_notification_text(v_tmpl.title_template, v_params);
        v_body := public.format_notification_text(v_tmpl.body_template, v_params);

        -- Find active fans who have NOT submitted an attempt for this trivia
        FOR v_fan IN
            SELECT p.id
            FROM public.profiles p
            WHERE p.role = 'fan'
              AND p.status = 'active'
              AND NOT EXISTS (
                  SELECT 1 FROM public.trivia_attempts ta
                  WHERE ta.trivia_id = v_trivia.id
                    AND ta.fan_id = p.id
                    AND ta.submitted_at IS NOT NULL
              )
        LOOP
            PERFORM public.create_notification(
                v_fan.id,
                'trivia_expiring',
                v_title,
                v_body,
                jsonb_build_object(
                    'url', '/app/trivias/' || v_trivia.id::text,
                    'trivia_id', v_trivia.id,
                    'hours_left', v_hours_left
                ),
                'trivia_expiring_' || v_trivia.id::text || '_' || v_fan.id::text
            );
            v_notif_count := v_notif_count + 1;
        END LOOP;
    END LOOP;

    RETURN v_notif_count;
END;
$$;

-- Permissions
REVOKE ALL ON FUNCTION public.format_notification_text(text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.format_notification_text(text, jsonb) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_update_notification_template(text, text, text, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_update_notification_template(text, text, text, boolean) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.notify_fans_new_trivia(uuid, text, int, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.notify_fans_new_trivia(uuid, text, int, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.cron_notify_expiring_trivias() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cron_notify_expiring_trivias() TO service_role;
