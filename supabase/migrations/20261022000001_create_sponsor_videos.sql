-- Migration: 20261022000001_create_sponsor_videos.sql
-- Description: Create sponsor_videos table and claim_video_points function for Google Drive video ads

CREATE TABLE IF NOT EXISTS public.sponsor_videos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    sponsor_name TEXT,
    video_url TEXT NOT NULL,
    drive_file_id TEXT NOT NULL,
    redirect_url TEXT,
    cta_text TEXT DEFAULT 'Visitar Patrocinador' NOT NULL,
    min_seconds INT DEFAULT 15 NOT NULL,
    reward_points INT DEFAULT 10 NOT NULL,
    is_active BOOLEAN DEFAULT true NOT NULL,
    order_index INT DEFAULT 0 NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Enable RLS
ALTER TABLE public.sponsor_videos ENABLE ROW LEVEL SECURITY;

-- Read policy: Anyone can see active sponsor videos
CREATE POLICY "sponsor_videos_select_active" ON public.sponsor_videos
    FOR SELECT USING (is_active = true OR EXISTS (
        SELECT 1 FROM public.staff_members WHERE user_id = auth.uid() AND active = true
    ));

-- Staff and admin can manage all sponsor videos
CREATE POLICY "sponsor_videos_insert_staff" ON public.sponsor_videos
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM public.staff_members WHERE user_id = auth.uid() AND active = true)
    );

CREATE POLICY "sponsor_videos_update_staff" ON public.sponsor_videos
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM public.staff_members WHERE user_id = auth.uid() AND active = true)
    );

CREATE POLICY "sponsor_videos_delete_staff" ON public.sponsor_videos
    FOR DELETE USING (
        EXISTS (SELECT 1 FROM public.staff_members WHERE user_id = auth.uid() AND active = true)
    );

GRANT SELECT ON public.sponsor_videos TO anon, authenticated;
GRANT ALL ON public.sponsor_videos TO authenticated;

-- RPC function to claim points for watching a sponsor video
CREATE OR REPLACE FUNCTION public.claim_video_points(p_video_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid UUID;
    v_video RECORD;
    v_today DATE := (NOW() AT TIME ZONE 'America/Caracas')::date;
    v_source_id TEXT;
    v_ledger_id UUID := gen_random_uuid();
    v_new_balance INT;
    v_views_today INT;
BEGIN
    v_uid := public.assert_active_verified_fan();

    -- Verify video exists and is active
    SELECT * INTO v_video FROM public.sponsor_videos WHERE id = p_video_id AND is_active = true;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El video de patrocinador no está disponible o ha sido desactivado.';
    END IF;

    -- Generate idempotent source_id: 1 reward per video per user per day
    v_source_id := 'video_view:' || v_uid::text || ':' || p_video_id::text || ':' || v_today::text;

    -- Check if already rewarded today for this video
    IF EXISTS (
        SELECT 1 FROM public.ledger_entries
        WHERE source_id = v_source_id AND type = 'ad_reward'
    ) THEN
        SELECT balance_cache INTO v_new_balance FROM public.wallets WHERE fan_id = v_uid;
        RETURN jsonb_build_object(
            'success', false,
            'already_claimed', true,
            'message', 'Ya has reclamado los puntos de este video el día de hoy.',
            'balance', v_new_balance,
            'points_awarded', 0
        );
    END IF;

    -- Check daily limit of video claims (max 20 per day)
    SELECT COUNT(*) INTO v_views_today
    FROM public.ledger_entries
    WHERE fan_id = v_uid AND source_type = 'sponsor_video' AND (created_at AT TIME ZONE 'America/Caracas')::date = v_today;

    IF v_views_today >= 20 THEN
        RAISE EXCEPTION 'Has alcanzado el límite diario de videos patrocinados (20 al día). Vuelve mañana para seguir acumulando.';
    END IF;

    -- Insert ledger entry atomically
    INSERT INTO public.ledger_entries (
        id, fan_id, amount, type, status, source_type, source_id, note
    ) VALUES (
        v_ledger_id, v_uid, v_video.reward_points, 'ad_reward', 'confirmed', 'sponsor_video', v_source_id,
        'Puntos por ver video de ' || COALESCE(v_video.sponsor_name, v_video.title)
    );

    -- Update wallet balance cache
    UPDATE public.wallets
    SET balance_cache = balance_cache + v_video.reward_points,
        updated_at = NOW()
    WHERE fan_id = v_uid
    RETURNING balance_cache INTO v_new_balance;

    RETURN jsonb_build_object(
        'success', true,
        'already_claimed', false,
        'message', '¡Puntos acreditados con éxito a tu billetera!',
        'balance', v_new_balance,
        'points_awarded', v_video.reward_points
    );
END;
$$;

REVOKE ALL ON FUNCTION public.claim_video_points(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_video_points(UUID) TO authenticated;
