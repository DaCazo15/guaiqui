-- ============================================================================
-- Migration: 20261028000013_stabilization_fixes.sql
-- Description: Estabilización de esquemas, triggers, firmas RPC y seguridad de funciones.
--              1. Corrige trg_notify_on_trivia_published (usa reward_rules en vez de reward_pearls).
--              2. Asegura validación de permisos en notify_fans_new_trivia (staff del equipo o service_role).
--              3. REVOKE EXECUTE FROM anon (y PUBLIC) en funciones de notificación y triggers tenant.
--              4. Elimina la sobrecarga duplicada de analytics_funnel(timestamptz, timestamptz).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. notify_fans_new_trivia con validación estricta de caller (staff del equipo o service_role)
-- ----------------------------------------------------------------------------
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
    v_trivia_team_id UUID;
    v_is_authorized BOOLEAN := FALSE;
BEGIN
    -- Validar permisos del llamador: service_role o staff activo del equipo (o admin de plataforma)
    IF auth.role() = 'service_role' OR current_user = 'postgres' THEN
        v_is_authorized := TRUE;
    ELSIF auth.uid() IS NOT NULL THEN
        -- Obtener el team_id de la trivia
        SELECT team_id INTO v_trivia_team_id FROM public.trivias WHERE id = p_trivia_id;
        IF v_trivia_team_id IS NULL THEN
            SELECT team_id INTO v_trivia_team_id FROM public.trivia_polls WHERE id = p_trivia_id;
        END IF;

        -- Verificar si el llamador es staff activo de ese equipo o admin de plataforma (team_id IS NULL)
        SELECT EXISTS (
            SELECT 1 FROM public.staff_members sm
            WHERE sm.user_id = auth.uid()
              AND sm.active = TRUE
              AND (sm.team_id IS NULL OR v_trivia_team_id IS NULL OR sm.team_id = v_trivia_team_id)
        ) INTO v_is_authorized;
    END IF;

    IF NOT v_is_authorized THEN
        RAISE EXCEPTION 'No autorizado para emitir notificaciones de esta trivia.' USING ERRCODE = '42501';
    END IF;

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

    -- Notificar a fanáticos activos (si tiene team_id, priorizar seguidores del equipo con notificaciones activas)
    FOR v_fan IN
        SELECT p.id 
        FROM public.profiles p
        WHERE p.role = 'fan'
          AND p.status = 'active'
          AND (
            v_trivia_team_id IS NULL 
            OR EXISTS (
                SELECT 1 FROM public.team_follows tf 
                WHERE tf.user_id = p.id 
                  AND tf.team_id = v_trivia_team_id 
                  AND tf.notifications_enabled = TRUE
            )
          )
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

-- ----------------------------------------------------------------------------
-- 2. Trigger trg_notify_on_trivia_published (usa reward_rules sin referenciar columnas inexistentes)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_notify_on_trivia_published()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_reward_pearls INT := 0;
BEGIN
    IF (TG_OP = 'INSERT' AND NEW.status = 'published') OR
       (TG_OP = 'UPDATE' AND NEW.status = 'published' AND OLD.status != 'published') THEN
        
        -- Extraer per_correct_pearls o fixed_pearls del objeto JSONB reward_rules
        IF NEW.reward_rules IS NOT NULL AND jsonb_typeof(NEW.reward_rules) = 'object' THEN
            v_reward_pearls := COALESCE(
                (NEW.reward_rules->>'per_correct_pearls')::INT,
                (NEW.reward_rules->>'fixed_pearls')::INT,
                0
            );
        END IF;

        PERFORM public.notify_fans_new_trivia(
            NEW.id,
            NEW.title,
            v_reward_pearls,
            'trivia'
        );
    END IF;
    RETURN NEW;
END;
$$;

-- ----------------------------------------------------------------------------
-- 3. REVOKE EXECUTE FROM anon y PUBLIC en funciones y triggers especificados
-- ----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.notify_fans_new_trivia(uuid, text, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.notify_fans_new_trivia(uuid, text, int, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.cron_notify_expiring_trivias() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cron_notify_expiring_trivias() TO service_role;

REVOKE ALL ON FUNCTION public.trg_notify_on_trivia_published() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.trg_notify_on_trivia_published() TO service_role;

REVOKE ALL ON FUNCTION public.trg_enforce_tenant_team_id() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.trg_enforce_tenant_team_id() TO service_role;

REVOKE ALL ON FUNCTION public.trg_enforce_child_team_consistency() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.trg_enforce_child_team_consistency() TO service_role;

-- ----------------------------------------------------------------------------
-- 4. Eliminar sobrecarga duplicada de analytics_funnel
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.analytics_funnel(TIMESTAMPTZ, TIMESTAMPTZ);

-- Asegurar permisos sobre la única firma canónica con team_id
REVOKE ALL ON FUNCTION public.analytics_funnel(TIMESTAMPTZ, TIMESTAMPTZ, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.analytics_funnel(TIMESTAMPTZ, TIMESTAMPTZ, UUID) TO authenticated, service_role;
