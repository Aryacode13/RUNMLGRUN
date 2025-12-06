-- ==========================
-- Migration: Replace slug with event_code in projects table
-- ==========================
-- Run this SQL in Supabase SQL Editor to update projects table
-- ==========================

-- Step 1: Add event_code column (nullable for now)
ALTER TABLE projects
ADD COLUMN IF NOT EXISTS event_code text;

-- Step 2: Drop unique constraint on slug if exists
ALTER TABLE projects
DROP CONSTRAINT IF EXISTS projects_slug_key;

-- Step 3: Drop index on slug if exists
DROP INDEX IF EXISTS idx_projects_slug;

-- Step 4: Remove slug column
ALTER TABLE projects
DROP COLUMN IF EXISTS slug;

-- Step 5: Create index on event_code (for faster lookups)
CREATE INDEX IF NOT EXISTS idx_projects_event_code ON projects(event_code);

-- Step 6: Add comment to event_code column
COMMENT ON COLUMN projects.event_code IS 'Kode event untuk menghubungkan form pendaftaran dengan event dan menghitung kuota';

-- ==========================
-- Notes:
-- ==========================
-- 1. event_code is nullable (optional) - forms can exist without being linked to an event
-- 2. If you want to make event_code required, uncomment the following:
--    ALTER TABLE projects ALTER COLUMN event_code SET NOT NULL;
-- 3. If you want to make event_code unique, uncomment the following:
--    ALTER TABLE projects ADD CONSTRAINT projects_event_code_key UNIQUE (event_code);
-- ==========================

















