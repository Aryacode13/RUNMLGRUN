-- ==========================
-- Admin Table Migration (Strava OAuth)
-- ==========================
-- Run this SQL in Supabase SQL Editor to create admin table
-- Admin login menggunakan Strava OAuth, validasi berdasarkan email
-- ==========================

-- Drop admin table if exists
DROP TABLE IF EXISTS admins CASCADE;

-- Create admins table
CREATE TABLE admins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text UNIQUE NOT NULL,
  full_name text,
  strava_id bigint, -- Optional: untuk tracking Strava ID admin
  is_active boolean DEFAULT true,
  last_login timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create index for faster lookups
CREATE INDEX idx_admins_email ON admins(email);
CREATE INDEX idx_admins_strava_id ON admins(strava_id);

-- Enable RLS
ALTER TABLE admins ENABLE ROW LEVEL SECURITY;

-- Development-friendly policies (change for production)
DROP POLICY IF EXISTS "Admins Select" ON admins;
CREATE POLICY "Admins Select" ON admins FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins Insert" ON admins;
CREATE POLICY "Admins Insert" ON admins FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Admins Update" ON admins;
CREATE POLICY "Admins Update" ON admins FOR UPDATE USING (true);

DROP POLICY IF EXISTS "Admins Delete" ON admins;
CREATE POLICY "Admins Delete" ON admins FOR DELETE USING (true);

-- Trigger for updated_at
DROP TRIGGER IF EXISTS update_admins_updated_at ON admins;
CREATE TRIGGER update_admins_updated_at
  BEFORE UPDATE ON admins
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Insert admin email
INSERT INTO admins (email, full_name, is_active)
VALUES (
  'aryahidayatz1111@gmail.com',
  'Administrator',
  true
);

-- ==========================
-- End of Admin Migration
-- ==========================
-- Admin login menggunakan Strava OAuth
-- Validasi: jika email dari Strava sama dengan email di tabel admins, maka login sebagai admin
-- ==========================
