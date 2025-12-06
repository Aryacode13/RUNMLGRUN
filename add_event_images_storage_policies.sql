-- Migration: Add Storage Policies for event-images bucket
-- This allows users to upload and read images from the event-images bucket

-- Policy untuk SELECT (read) - Allow public read access
DROP POLICY IF EXISTS "Public Access" ON storage.objects;
CREATE POLICY "Public Access"
ON storage.objects FOR SELECT
USING (bucket_id = 'event-images');

-- Policy untuk INSERT (upload) - Allow authenticated users to upload
-- Jika ingin allow anonymous upload, ganti 'authenticated' dengan 'public'
DROP POLICY IF EXISTS "Allow authenticated upload" ON storage.objects;
CREATE POLICY "Allow authenticated upload"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'event-images' 
  AND (auth.role() = 'authenticated' OR auth.role() = 'anon')
);

-- Policy untuk UPDATE (replace) - Allow authenticated users to update
DROP POLICY IF EXISTS "Allow authenticated update" ON storage.objects;
CREATE POLICY "Allow authenticated update"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'event-images' 
  AND (auth.role() = 'authenticated' OR auth.role() = 'anon')
);

-- Policy untuk DELETE - Allow authenticated users to delete
DROP POLICY IF EXISTS "Allow authenticated delete" ON storage.objects;
CREATE POLICY "Allow authenticated delete"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'event-images' 
  AND (auth.role() = 'authenticated' OR auth.role() = 'anon')
);

-- ==========================
-- Notes:
-- ==========================
-- 1. Policy "Public Access" memungkinkan siapa saja membaca file (karena bucket public)
-- 2. Policy untuk INSERT/UPDATE/DELETE menggunakan 'authenticated' OR 'anon' 
--    untuk memungkinkan upload dari aplikasi Flutter yang menggunakan anon key
-- 3. Jika ingin lebih secure, bisa ganti 'anon' dengan 'authenticated' saja
-- ==========================

