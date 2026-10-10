-- Migration: 20261010000024_securing_trivias_and_profile_updates.sql
-- Description: Securing trivia options (Admin-only SELECT), restricting profile column UPDATEs, and introducing accept_terms & set_birth_date RPCs.

-- 1. Restrict trivia_options SELECT to Admin Only
ALTER TABLE public.trivia_options ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Trivia Options Public Read" ON public.trivia_options;
DROP POLICY IF EXISTS "Trivia Options Admin Select" ON public.trivia_options;
DROP POLICY IF EXISTS "Trivia Options Admin All" ON public.trivia_options;

CREATE POLICY "Trivia Options Admin Select" ON public.trivia_options FOR SELECT TO authenticated USING (public.is_admin_check());
CREATE POLICY "Trivia Options Admin All" ON public.trivia_options FOR ALL TO authenticated USING (public.is_admin_check());

-- 2. RPC admin_get_trivia_with_options for Admin Editor
CREATE OR REPLACE FUNCTION public.admin_get_trivia_with_options(p_trivia_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_trivia public.trivias%ROWTYPE;
    v_questions JSONB;
BEGIN
    PERFORM public.assert_admin();

    SELECT * INTO v_trivia FROM public.trivias WHERE id = p_trivia_id;
    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    SELECT jsonb_agg(
        jsonb_build_object(
            'id', q.id,
            'question_text', q.question_text,
            'points', q.points,
            'order_index', q.order_index,
            'options', (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'id', o.id,
                        'option_text', o.option_text,
                        'is_correct', o.is_correct
                    )
                )
                FROM public.trivia_options o
                WHERE o.question_id = q.id
            )
        )
    ) INTO v_questions
    FROM public.trivia_questions q
    WHERE q.trivia_id = p_trivia_id;

    RETURN jsonb_build_object(
        'trivia', to_jsonb(v_trivia),
        'questions', COALESCE(v_questions, '[]'::jsonb)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.admin_get_trivia_with_options(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_get_trivia_with_options(UUID) TO authenticated, service_role;

-- 3. Column-Level UPDATE Protection on profiles
REVOKE UPDATE ON public.profiles FROM authenticated;
GRANT UPDATE (display_name, avatar_url, municipality, gender, favorite_player_id, shirt_size, referral_source, notification_prefs) ON public.profiles TO authenticated;

-- 4. RPC accept_terms (Sets legal timestamps on server-side)
CREATE OR REPLACE FUNCTION public.accept_terms()
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_now TIMESTAMPTZ := NOW();
BEGIN
    PERFORM public.assert_active_verified_fan();

    UPDATE public.profiles
    SET terms_accepted_at = v_now,
        privacy_accepted_at = v_now,
        pearls_rules_accepted_at = v_now,
        updated_at = v_now
    WHERE id = v_user_id;

    RETURN jsonb_build_object('success', true, 'accepted_at', v_now);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.accept_terms() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accept_terms() TO authenticated, service_role;

-- 5. RPC set_birth_date (Immutable once set)
CREATE OR REPLACE FUNCTION public.set_birth_date(p_birth_date DATE)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_current_bdate DATE;
BEGIN
    PERFORM public.assert_active_verified_fan();

    IF p_birth_date IS NULL THEN
        RAISE EXCEPTION 'La fecha de nacimiento es obligatoria.';
    END IF;

    SELECT birth_date INTO v_current_bdate FROM public.profiles WHERE id = v_user_id;

    IF v_current_bdate IS NOT NULL THEN
        RAISE EXCEPTION 'La fecha de nacimiento no puede ser modificada una vez registrada.';
    END IF;

    UPDATE public.profiles
    SET birth_date = p_birth_date,
        updated_at = NOW()
    WHERE id = v_user_id;

    RETURN jsonb_build_object('success', true, 'birth_date', p_birth_date);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.set_birth_date(DATE) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_birth_date(DATE) TO authenticated, service_role;
