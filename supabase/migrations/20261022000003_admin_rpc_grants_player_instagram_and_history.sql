-- Migration: 20261022000003_admin_rpc_grants_player_instagram_and_history.sql
-- Description:
-- 1. Add instagram_url to players table and update admin_upsert_player.
-- 2. Grant EXECUTE to authenticated for admin RPCs (admin_get_fan, admin_adjust_pearls, etc.)
-- 3. Populate official club history milestones into history_milestones table.

-- 1. Players instagram_url column
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS instagram_url TEXT;

-- Update admin_upsert_player to handle instagram_url
CREATE OR REPLACE FUNCTION public.admin_upsert_player(p_player jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_player_id UUID;
BEGIN
    PERFORM public.assert_admin();

    v_player_id := (p_player->>'id')::UUID;

    IF v_player_id IS NULL THEN
        INSERT INTO public.players (
            name, jersey_number, position, height, age, nationality, bio, is_active, is_star, instagram_url
        ) VALUES (
            p_player->>'name',
            (p_player->>'jersey_number')::INT,
            p_player->>'position',
            p_player->>'height',
            (p_player->>'age')::INT,
            COALESCE(p_player->>'nationality', 'Venezuela'),
            p_player->>'bio',
            COALESCE((p_player->>'is_active')::BOOLEAN, true),
            COALESCE((p_player->>'is_star')::BOOLEAN, false),
            p_player->>'instagram_url'
        ) RETURNING id INTO v_player_id;
    ELSE
        UPDATE public.players SET
            name = COALESCE(p_player->>'name', name),
            jersey_number = COALESCE((p_player->>'jersey_number')::INT, jersey_number),
            position = COALESCE(p_player->>'position', position),
            height = COALESCE(p_player->>'height', height),
            age = COALESCE((p_player->>'age')::INT, age),
            nationality = COALESCE(p_player->>'nationality', nationality),
            bio = COALESCE(p_player->>'bio', bio),
            is_active = COALESCE((p_player->>'is_active')::BOOLEAN, is_active),
            is_star = COALESCE((p_player->>'is_star')::BOOLEAN, is_star),
            instagram_url = COALESCE(p_player->>'instagram_url', instagram_url)
        WHERE id = v_player_id;
    END IF;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, new_values)
    VALUES (v_admin_id, 'upsert_player', 'players', v_player_id, p_player);

    RETURN jsonb_build_object('success', true, 'player_id', v_player_id);
END;
$function$;

-- 2. Grant EXECUTE to authenticated and service_role for admin functions
-- Note: all of these functions enforce assert_admin() internally.
GRANT EXECUTE ON FUNCTION public.admin_get_fan(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_adjust_pearls(uuid, integer, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_suspend_fan(uuid, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_reactivate_fan(uuid, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_upsert_player(jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_delete_player(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_resolve_risk_flag(uuid, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_resolve_redemption_issue(uuid, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_toggle_staff_active(uuid, boolean) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_update_staff_role(uuid, staff_role) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_archive_trivia(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_publish_policy(text, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_upsert_segment(jsonb) TO authenticated, service_role;

-- 3. Seed real history milestones
INSERT INTO public.history_milestones (year, title, text, order_index, is_published)
SELECT '1977', 'Fundación del Club', 'Nace Guaiqueríes de Margarita en La Asunción, representando el alma y la identidad de Nueva Esparta en el baloncesto profesional venezolano.', 1, true
WHERE NOT EXISTS (SELECT 1 FROM public.history_milestones WHERE year = '1977');

INSERT INTO public.history_milestones (year, title, text, order_index, is_published)
SELECT '1978 - 1982', 'La Era del Pentacampeonato', 'Hito histórico sin precedentes al conquistar 5 títulos consecutivos de liga con una mítica generación insular.', 2, true
WHERE NOT EXISTS (SELECT 1 FROM public.history_milestones WHERE year = '1978 - 1982');

INSERT INTO public.history_milestones (year, title, text, order_index, is_published)
SELECT '1997', 'Séptima Corona Nacional', 'Victoria inolvidable en la final ante Cocodrilos de Caracas con el Gimnasio Ciudad de La Asunción lleno a reventar.', 3, true
WHERE NOT EXISTS (SELECT 1 FROM public.history_milestones WHERE year = '1997');

INSERT INTO public.history_milestones (year, title, text, order_index, is_published)
SELECT '2007', 'Octavo Título de Campeón', 'Guaiqueríes borda su octava estrella nacional con un baloncesto aguerrido y el respaldo incondicional de la Tribu Verde.', 4, true
WHERE NOT EXISTS (SELECT 1 FROM public.history_milestones WHERE year = '2007');

INSERT INTO public.history_milestones (year, title, text, order_index, is_published)
SELECT '2021', 'Campeones de la Superliga', 'Retorno a la gloria nacional alzando la copa de la Superliga de Baloncesto tras una campaña formidable.', 5, true
WHERE NOT EXISTS (SELECT 1 FROM public.history_milestones WHERE year = '2021');

INSERT INTO public.history_milestones (year, title, text, order_index, is_published)
SELECT '2026', 'Plataforma Digital Fan Zone', 'Lanzamiento oficial de la app de fidelización con economía inmutable de perlitas para empoderar a la fanaticada insular.', 6, true
WHERE NOT EXISTS (SELECT 1 FROM public.history_milestones WHERE year = '2026');
