-- Migration: Add registration_fee to projects table
-- Run this in Supabase SQL Editor

-- Add registration_fee column to projects table
ALTER TABLE projects
ADD COLUMN IF NOT EXISTS registration_fee DECIMAL(10, 2) DEFAULT 0;

-- Add comment to column
COMMENT ON COLUMN projects.registration_fee IS 'Harga pendaftaran dalam Rupiah (0 = gratis)';

-- Create index for better query performance (optional)
CREATE INDEX IF NOT EXISTS idx_projects_registration_fee ON projects(registration_fee);
















