-- ==============================================================================
-- MIGRACIÓN: 20261022000005_update_storage_bucket_limits.sql
-- Propósito: Blindar los límites de tamaño en Storage para evitar archivos pesados.
-- Avatares: límite estricto de 15 KB (15360 bytes) para alojar miniaturas WebP de 2 KB a 5 KB.
-- ==============================================================================

UPDATE storage.buckets
SET file_size_limit = 15360, -- 15 KB (garantiza que las miniaturas subidas pesen < 10 KB)
    allowed_mime_types = ARRAY['image/webp', 'image/jpeg', 'image/png', 'image/avif']
WHERE id = 'avatars';
