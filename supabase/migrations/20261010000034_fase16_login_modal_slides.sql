-- Migration: 20261010000034_fase16_login_modal_slides.sql
-- Description: Login Modal Carousel (Fase 16) - Table, URL validation, 5-slide cap, RLS policies, and RPCs for fans & admin management.

-- 1. Create login_modal_slides table
CREATE TABLE IF NOT EXISTS public.login_modal_slides (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    position INT NOT NULL CHECK (position >= 1 AND position <= 5),
    image_url TEXT,
    title TEXT NOT NULL CHECK (char_length(title) <= 80),
    subtitle TEXT CHECK (char_length(subtitle) <= 160),
    cta_label TEXT NOT NULL DEFAULT 'Ver más',
    cta_url TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published')),
    starts_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ends_at TIMESTAMPTZ,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.login_modal_slides ENABLE ROW LEVEL SECURITY;

-- 2. URL Validation Helper Function
CREATE OR REPLACE FUNCTION public.validate_login_modal_urls(
    p_image_url TEXT,
    p_cta_url TEXT
)
RETURNS VOID AS $$
DECLARE
    v_clean_img TEXT := LOWER(TRIM(COALESCE(p_image_url, '')));
    v_clean_cta TEXT := LOWER(TRIM(COALESCE(p_cta_url, '')));
BEGIN
    -- Check image URL
    IF v_clean_img != '' THEN
        IF v_clean_img LIKE 'javascript:%' OR v_clean_img LIKE 'data:%' OR v_clean_img LIKE 'vbscript:%' THEN
            RAISE EXCEPTION 'Esquema de URL no permitido en la imagen.' USING ERRCODE = '22023';
        END IF;

        IF NOT (v_clean_img LIKE 'https://%' OR v_clean_img LIKE '/%') THEN
            RAISE EXCEPTION 'La URL de la imagen debe ser una ruta segura https:// o relativa /.' USING ERRCODE = '22023';
        END IF;
    END IF;

    -- Check CTA URL
    IF v_clean_cta = '' THEN
        RAISE EXCEPTION 'La URL del botón CTA es obligatoria.' USING ERRCODE = '22023';
    END IF;

    IF v_clean_cta LIKE 'javascript:%' OR v_clean_cta LIKE 'data:%' OR v_clean_cta LIKE 'vbscript:%' THEN
        RAISE EXCEPTION 'Esquema de URL no permitido en el botón CTA.' USING ERRCODE = '22023';
    END IF;

    IF NOT (v_clean_cta LIKE 'https://%' OR v_clean_cta LIKE '/%') THEN
        RAISE EXCEPTION 'La URL del botón CTA debe empezar por https:// o /.' USING ERRCODE = '22023';
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.validate_login_modal_urls(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.validate_login_modal_urls(TEXT, TEXT) TO authenticated, service_role;

-- 3. Trigger to enforce max 5 active published slides
CREATE OR REPLACE FUNCTION public.check_max_5_published_login_modal_slides()
RETURNS TRIGGER AS $$
DECLARE
    v_published_count INT;
BEGIN
    IF NEW.status = 'published' AND (NEW.ends_at IS NULL OR NEW.ends_at >= NOW()) THEN
        SELECT COUNT(*) INTO v_published_count
        FROM public.login_modal_slides
        WHERE status = 'published'
          AND (ends_at IS NULL OR ends_at >= NOW())
          AND id != NEW.id;

        IF v_published_count >= 5 THEN
            RAISE EXCEPTION 'No se pueden publicar más de 5 diapositivas vigentes al mismo tiempo.' USING ERRCODE = '23514';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS trg_check_max_5_published_login_modal_slides ON public.login_modal_slides;
CREATE TRIGGER trg_check_max_5_published_login_modal_slides
BEFORE INSERT OR UPDATE ON public.login_modal_slides
FOR EACH ROW
EXECUTE FUNCTION public.check_max_5_published_login_modal_slides();

-- 4. RLS Policies
DROP POLICY IF EXISTS "LoginModalSlides Fan Read" ON public.login_modal_slides;
CREATE POLICY "LoginModalSlides Fan Read" ON public.login_modal_slides
    FOR SELECT TO authenticated, anon
    USING (
        status = 'published'
        AND starts_at <= NOW()
        AND (ends_at IS NULL OR ends_at >= NOW())
    );

DROP POLICY IF EXISTS "LoginModalSlides Admin All" ON public.login_modal_slides;
CREATE POLICY "LoginModalSlides Admin All" ON public.login_modal_slides
    FOR ALL TO authenticated
    USING (public.is_admin_check());

-- 5. RPC get_login_modal() for fans
CREATE OR REPLACE FUNCTION public.get_login_modal()
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_slides JSONB;
BEGIN
    v_user_id := public.assert_active_verified_fan();

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', id,
            'position', position,
            'image_url', image_url,
            'title', title,
            'subtitle', subtitle,
            'cta_label', cta_label,
            'cta_url', cta_url
        ) ORDER BY position ASC
    ), '[]'::jsonb) INTO v_slides
    FROM public.login_modal_slides
    WHERE status = 'published'
      AND starts_at <= NOW()
      AND (ends_at IS NULL OR ends_at >= NOW());

    RETURN v_slides;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.get_login_modal() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_login_modal() TO authenticated, service_role;

-- 6. Admin RPC admin_upsert_login_modal_slide
CREATE OR REPLACE FUNCTION public.admin_upsert_login_modal_slide(
    p_id UUID,
    p_position INT,
    p_image_url TEXT,
    p_title TEXT,
    p_subtitle TEXT,
    p_cta_label TEXT,
    p_cta_url TEXT,
    p_status TEXT,
    p_starts_at TIMESTAMPTZ,
    p_ends_at TIMESTAMPTZ
)
RETURNS JSONB AS $$
DECLARE
    v_slide_id UUID;
    v_clean_title TEXT := TRIM(p_title);
    v_clean_subtitle TEXT := TRIM(COALESCE(p_subtitle, ''));
    v_clean_cta_label TEXT := COALESCE(NULLIF(TRIM(p_cta_label), ''), 'Ver más');
    v_status TEXT := COALESCE(p_status, 'draft');
BEGIN
    PERFORM public.assert_admin();
    PERFORM public.validate_login_modal_urls(p_image_url, p_cta_url);

    IF p_position < 1 OR p_position > 5 THEN
        RAISE EXCEPTION 'La posición de la diapositiva debe estar entre 1 y 5.';
    END IF;

    IF v_clean_title IS NULL OR v_clean_title = '' OR CHAR_LENGTH(v_clean_title) > 80 THEN
        RAISE EXCEPTION 'El título es obligatorio y debe tener como máximo 80 caracteres.';
    END IF;

    IF CHAR_LENGTH(v_clean_subtitle) > 160 THEN
        RAISE EXCEPTION 'El subtítulo no puede exceder 160 caracteres.';
    END IF;

    IF p_id IS NOT NULL THEN
        UPDATE public.login_modal_slides
        SET position = p_position,
            image_url = p_image_url,
            title = v_clean_title,
            subtitle = v_clean_subtitle,
            cta_label = v_clean_cta_label,
            cta_url = TRIM(p_cta_url),
            status = v_status,
            starts_at = COALESCE(p_starts_at, NOW()),
            ends_at = p_ends_at,
            updated_at = NOW()
        WHERE id = p_id;
        v_slide_id := p_id;
    ELSE
        INSERT INTO public.login_modal_slides (
            position, image_url, title, subtitle, cta_label, cta_url, status, starts_at, ends_at, created_by
        )
        VALUES (
            p_position, p_image_url, v_clean_title, v_clean_subtitle, v_clean_cta_label, TRIM(p_cta_url), v_status, COALESCE(p_starts_at, NOW()), p_ends_at, auth.uid()
        )
        RETURNING id INTO v_slide_id;
    END IF;

    INSERT INTO public.audit_logs (actor_id, action, target_table, target_id, details)
    VALUES (
        auth.uid(),
        'admin_upsert_login_modal_slide',
        'login_modal_slides',
        v_slide_id::text,
        jsonb_build_object('title', v_clean_title, 'position', p_position, 'status', v_status)
    );

    RETURN jsonb_build_object('success', true, 'id', v_slide_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.admin_upsert_login_modal_slide(UUID, INT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_upsert_login_modal_slide(UUID, INT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated, service_role;

-- 7. Admin RPC admin_reorder_login_modal_slides
CREATE OR REPLACE FUNCTION public.admin_reorder_login_modal_slides(p_slide_ids UUID[])
RETURNS JSONB AS $$
DECLARE
    v_id UUID;
    v_pos INT := 1;
BEGIN
    PERFORM public.assert_admin();

    IF p_slide_ids IS NULL OR array_length(p_slide_ids, 1) > 5 THEN
        RAISE EXCEPTION 'Máximo 5 diapositivas pueden ser reordenadas.';
    END IF;

    FOREACH v_id IN ARRAY p_slide_ids LOOP
        UPDATE public.login_modal_slides
        SET position = v_pos, updated_at = NOW()
        WHERE id = v_id;
        v_pos := v_pos + 1;
    END LOOP;

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.admin_reorder_login_modal_slides(UUID[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_reorder_login_modal_slides(UUID[]) TO authenticated, service_role;

-- 8. Admin RPC admin_delete_login_modal_slide
CREATE OR REPLACE FUNCTION public.admin_delete_login_modal_slide(p_slide_id UUID)
RETURNS JSONB AS $$
BEGIN
    PERFORM public.assert_admin();

    DELETE FROM public.login_modal_slides WHERE id = p_slide_id;

    INSERT INTO public.audit_logs (actor_id, action, target_table, target_id, details)
    VALUES (
        auth.uid(),
        'admin_delete_login_modal_slide',
        'login_modal_slides',
        p_slide_id::text,
        jsonb_build_object('deleted_id', p_slide_id)
    );

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.admin_delete_login_modal_slide(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_delete_login_modal_slide(UUID) TO authenticated, service_role;
