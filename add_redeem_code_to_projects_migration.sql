-- Migration: Add redeem_code and redeem_discount_percentage to projects table
-- Run this in Supabase SQL Editor

-- Add redeem_code column to projects table
ALTER TABLE projects
ADD COLUMN IF NOT EXISTS redeem_code TEXT;

-- Add redeem_discount_percentage column to projects table
ALTER TABLE projects
ADD COLUMN IF NOT EXISTS redeem_discount_percentage DECIMAL(5, 2) DEFAULT 0;

-- Add comments to columns
COMMENT ON COLUMN projects.redeem_code IS 'Kode redeem/promo untuk pendaftaran (opsional, bisa multiple codes dipisahkan koma)';
COMMENT ON COLUMN projects.redeem_discount_percentage IS 'Persentase diskon jika menggunakan kode redeem (0-100, default 0)';

-- Create index for better query performance (optional)
CREATE INDEX IF NOT EXISTS idx_projects_redeem_code ON projects(redeem_code);

