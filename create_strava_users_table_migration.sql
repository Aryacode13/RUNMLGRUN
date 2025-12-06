-- ==========================
-- Create separate table for Strava connection
-- Remove Strava columns from users table
-- ==========================
-- Run this SQL in Supabase SQL Editor
-- ==========================

-- Step 1: Create strava_users table
CREATE TABLE IF NOT EXISTS strava_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  strava_id bigint NOT NULL UNIQUE,
  access_token text,
  refresh_token text,
  token_expires bigint,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_strava_users_user_id ON strava_users(user_id);
CREATE INDEX IF NOT EXISTS idx_strava_users_strava_id ON strava_users(strava_id);

-- Trigger function for updated_at
CREATE OR REPLACE FUNCTION update_strava_users_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for updated_at
DROP TRIGGER IF EXISTS update_strava_users_updated_at ON strava_users;
CREATE TRIGGER update_strava_users_updated_at
  BEFORE UPDATE ON strava_users
  FOR EACH ROW
  EXECUTE FUNCTION update_strava_users_updated_at();

-- Enable RLS
ALTER TABLE strava_users ENABLE ROW LEVEL SECURITY;

-- RLS Policies for strava_users
DROP POLICY IF EXISTS "Strava Users Select" ON strava_users;
CREATE POLICY "Strava Users Select" ON strava_users 
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Strava Users Insert" ON strava_users;
CREATE POLICY "Strava Users Insert" ON strava_users 
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Strava Users Update" ON strava_users;
CREATE POLICY "Strava Users Update" ON strava_users 
  FOR UPDATE USING (true);

DROP POLICY IF EXISTS "Strava Users Delete" ON strava_users;
CREATE POLICY "Strava Users Delete" ON strava_users 
  FOR DELETE USING (true);

-- Step 2: Migrate existing Strava data from users to strava_users
-- (Hanya jika ada data Strava yang sudah ada)
INSERT INTO strava_users (user_id, strava_id, access_token, refresh_token, token_expires, created_at, updated_at)
SELECT 
  id as user_id,
  strava_id,
  access_token,
  refresh_token,
  token_expires,
  created_at,
  updated_at
FROM users
WHERE strava_id IS NOT NULL
ON CONFLICT (user_id) DO NOTHING;

-- Step 3: Remove Strava columns from users table
ALTER TABLE users
DROP COLUMN IF EXISTS strava_id,
DROP COLUMN IF EXISTS access_token,
DROP COLUMN IF EXISTS refresh_token,
DROP COLUMN IF EXISTS token_expires;

-- ==========================
-- Notes:
-- - strava_users: tabel khusus untuk Strava connection
-- - user_id: link ke users table (UNIQUE, satu user = satu Strava account)
-- - strava_id: Strava user ID (UNIQUE)
-- - users table: sekarang hanya untuk profil RMR (username, firstname, lastname, email_users, dll)
-- - Data Strava yang sudah ada akan di-migrate otomatis
-- ==========================














