-- ==========================
-- Migration: Add registration_fee, redeem_code, and redeem_discount_percentage to projects table
-- ==========================
-- Run this SQL in Supabase SQL Editor
-- This migration adds all pricing and redeem code features
-- ==========================

-- Step 1: Add registration_fee column
ALTER TABLE projects
ADD COLUMN IF NOT EXISTS registration_fee DECIMAL(10, 2) DEFAULT 0;

-- Step 2: Add redeem_code column
ALTER TABLE projects
ADD COLUMN IF NOT EXISTS redeem_code TEXT;

-- Step 3: Add redeem_discount_percentage column
ALTER TABLE projects
ADD COLUMN IF NOT EXISTS redeem_discount_percentage DECIMAL(5, 2) DEFAULT 0;

-- Step 4: Add comments to columns
COMMENT ON COLUMN projects.registration_fee IS 'Harga pendaftaran dalam Rupiah (0 = gratis)';
COMMENT ON COLUMN projects.redeem_code IS 'Kode redeem/promo untuk pendaftaran (opsional, bisa multiple codes dipisahkan koma)';
COMMENT ON COLUMN projects.redeem_discount_percentage IS 'Persentase diskon jika menggunakan kode redeem (0-100, default 0)';

-- Step 5: Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_projects_registration_fee ON projects(registration_fee);
CREATE INDEX IF NOT EXISTS idx_projects_redeem_code ON projects(redeem_code);

-- ==========================
-- Verification Query (optional - run to check if columns exist)
-- ==========================
-- SELECT column_name, data_type, column_default
-- FROM information_schema.columns
-- WHERE table_name = 'projects'
-- AND column_name IN ('registration_fee', 'redeem_code', 'redeem_discount_percentage');
-- ==========================
















