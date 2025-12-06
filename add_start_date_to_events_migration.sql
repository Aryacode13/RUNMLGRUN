-- ==========================
-- Migration: Add start_date column to events table
-- ==========================
-- Run this SQL in Supabase SQL Editor to add start_date column to events table
-- ==========================

-- Step 1: Add start_date column (nullable)
ALTER TABLE events
ADD COLUMN IF NOT EXISTS start_date timestamptz;

-- Step 2: Create index on start_date (for faster queries)
CREATE INDEX IF NOT EXISTS idx_events_start_date ON events(start_date);

-- Step 3: Add comment to start_date column
COMMENT ON COLUMN events.start_date IS 'Tanggal dan waktu mulai event';

-- Step 4: Update event_stats view to include start_date
-- Drop existing view
DROP VIEW IF EXISTS event_stats;

-- Recreate view with start_date
CREATE VIEW event_stats AS
SELECT
  e.id,
  e.title,
  e.description,
  e.quota,
  e.is_active,
  e.created_by,
  e.event_code,
  e.start_date,
  e.created_at,
  e.updated_at,
  (SELECT COUNT(*) FROM registrations r WHERE r.event_id = e.id) AS total_registered,
  (e.quota - (SELECT COUNT(*) FROM registrations r WHERE r.event_id = e.id)) AS remaining_quota
FROM events e;

-- ==========================
-- Notes:
-- ==========================
-- 1. start_date is nullable (optional) - events can exist without a start date
-- 2. is_active column already exists in events table
-- 3. Events with is_active = true will appear in user dashboard
-- ==========================

















