-- ==========================
-- Migration: Add event_code column to events table
-- ==========================
-- Run this SQL in Supabase SQL Editor to add event_code column to events table
-- ==========================

-- Step 1: Add event_code column (nullable)
ALTER TABLE events
ADD COLUMN IF NOT EXISTS event_code text;

-- Step 2: Create index on event_code (for faster lookups)
CREATE INDEX IF NOT EXISTS idx_events_event_code ON events(event_code);

-- Step 3: Add comment to event_code column
COMMENT ON COLUMN events.event_code IS 'Kode event untuk menghubungkan event dengan form pendaftaran dan menghitung kuota';

-- Step 4: Update event_stats view to include event_code
-- Drop existing view
DROP VIEW IF EXISTS event_stats;

-- Recreate view with event_code
CREATE VIEW event_stats AS
SELECT
  e.id,
  e.title,
  e.description,
  e.quota,
  e.is_active,
  e.created_by,
  e.event_code,
  e.created_at,
  e.updated_at,
  (SELECT COUNT(*) FROM registrations r WHERE r.event_id = e.id) AS total_registered,
  (e.quota - (SELECT COUNT(*) FROM registrations r WHERE r.event_id = e.id)) AS remaining_quota
FROM events e;

-- ==========================
-- Notes:
-- ==========================
-- 1. event_code is nullable (optional) - events can exist without being linked to a form
-- 2. event_code should match event_code in projects table to link event with registration form
-- 3. When a form submission is made with matching event_code, it can be counted towards event quota
-- ==========================

















