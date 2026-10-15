-- Migration: 20261015000049_allow_avif_in_avatars_bucket.sql
-- Description: Allow image/avif MIME type in avatars storage bucket.

UPDATE storage.buckets
SET allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/avif']
WHERE id = 'avatars';
