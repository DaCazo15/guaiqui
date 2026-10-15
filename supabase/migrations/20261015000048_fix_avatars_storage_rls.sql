-- Migration: 20261015000048_fix_avatars_storage_rls.sql
-- Description: Repair avatars bucket storage RLS policies using native TO authenticated and WITH CHECK clauses, avoiding deprecated auth.role() check.

-- 1. Ensure bucket configuration allows common image mime types
UPDATE storage.buckets
SET allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
WHERE id = 'avatars';

-- 2. Storage RLS Policies for 'avatars'
DROP POLICY IF EXISTS "Avatars Public Read" ON storage.objects;
CREATE POLICY "Avatars Public Read" ON storage.objects
    FOR SELECT TO public
    USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Avatars User Insert" ON storage.objects;
CREATE POLICY "Avatars User Insert" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'avatars' AND
        (storage.foldername(name))[1] = auth.uid()::text
    );

DROP POLICY IF EXISTS "Avatars User Update" ON storage.objects;
CREATE POLICY "Avatars User Update" ON storage.objects
    FOR UPDATE TO authenticated
    USING (
        bucket_id = 'avatars' AND
        (storage.foldername(name))[1] = auth.uid()::text
    )
    WITH CHECK (
        bucket_id = 'avatars' AND
        (storage.foldername(name))[1] = auth.uid()::text
    );

DROP POLICY IF EXISTS "Avatars User Delete" ON storage.objects;
CREATE POLICY "Avatars User Delete" ON storage.objects
    FOR DELETE TO authenticated
    USING (
        bucket_id = 'avatars' AND
        (storage.foldername(name))[1] = auth.uid()::text
    );
