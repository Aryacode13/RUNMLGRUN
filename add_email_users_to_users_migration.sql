-- ==========================
-- Add email_users column to users table
-- ==========================
-- Run this SQL in Supabase SQL Editor
-- ==========================

-- Add email_users column to users table
ALTER TABLE users
ADD COLUMN IF NOT EXISTS email_users text UNIQUE;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_users_email_users ON users(email_users);

-- ==========================
-- Notes:
-- - email_users: email address untuk login email/Google
-- - UNIQUE: satu email hanya bisa digunakan sekali
-- - Tabel users tetap khusus untuk Strava connection
-- - email_users diisi jika user login via email/Google
-- ==========================














