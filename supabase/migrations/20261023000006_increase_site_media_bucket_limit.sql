-- ==============================================================================
-- Migration: Increase site-media bucket size limit to 20 MB and add all image MIME types
-- Prevents net::ERR_HTTP2_PROTOCOL_ERROR when uploading large high-res PNG/JPG images.
-- ==============================================================================

UPDATE storage.buckets
SET file_size_limit = 20971520, -- 20 MB
    allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/svg+xml', 'image/gif', 'image/avif']
WHERE id = 'site-media';
