-- Migration: 20261026000001_add_opponent_logo_url_to_games.sql
-- Description: Adds opponent_logo_url column to public.games and updates admin_upsert_game function.

ALTER TABLE public.games
ADD COLUMN IF NOT EXISTS opponent_logo_url TEXT;

-- Update admin_upsert_game function to accept and save opponent_logo_url
CREATE OR REPLACE FUNCTION public.admin_upsert_game(p_game jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_admin_id UUID := auth.uid();
    v_game_id UUID;
BEGIN
    PERFORM public.assert_admin();

    v_game_id := (p_game->>'id')::UUID;

    IF v_game_id IS NULL THEN
        INSERT INTO public.games (
            opponent,
            opponent_logo_url,
            location,
            game_date,
            is_home,
            status,
            our_score,
            opponent_score
        ) VALUES (
            p_game->>'opponent',
            NULLIF(TRIM(p_game->>'opponent_logo_url'), ''),
            COALESCE(p_game->>'location', 'Gimnasio Ciudad de La Asunción'),
            (p_game->>'game_date')::TIMESTAMPTZ,
            COALESCE((p_game->>'is_home')::BOOLEAN, true),
            COALESCE((p_game->>'status')::game_status, 'scheduled'),
            COALESCE((p_game->>'our_score')::INT, 0),
            COALESCE((p_game->>'opponent_score')::INT, 0)
        ) RETURNING id INTO v_game_id;
    ELSE
        UPDATE public.games SET
            opponent = COALESCE(p_game->>'opponent', opponent),
            opponent_logo_url = CASE 
                WHEN p_game ? 'opponent_logo_url' THEN NULLIF(TRIM(p_game->>'opponent_logo_url'), '')
                ELSE opponent_logo_url
            END,
            location = COALESCE(p_game->>'location', location),
            game_date = COALESCE((p_game->>'game_date')::TIMESTAMPTZ, game_date),
            is_home = COALESCE((p_game->>'is_home')::BOOLEAN, is_home),
            status = COALESCE((p_game->>'status')::game_status, status),
            our_score = COALESCE((p_game->>'our_score')::INT, our_score),
            opponent_score = COALESCE((p_game->>'opponent_score')::INT, opponent_score)
        WHERE id = v_game_id;
    END IF;

    INSERT INTO public.audit_log (actor_id, action, entity, entity_id, after)
    VALUES (v_admin_id, 'upsert_game', 'games', v_game_id::text, p_game);

    RETURN jsonb_build_object('id', v_game_id, 'status', 'success');
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_upsert_game(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_upsert_game(jsonb) TO authenticated;
