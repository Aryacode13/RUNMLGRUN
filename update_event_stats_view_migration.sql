-- Migration: Update event_stats view to include image_url
-- This ensures that image_url is included when fetching events

-- Drop existing view first (to avoid column order conflicts)
DROP VIEW IF EXISTS event_stats;

-- Recreate view with image_url, maintaining the correct column order
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
  e.image_url,  -- Add image_url column
  e.created_at,
  e.updated_at,
  (SELECT COUNT(*) FROM registrations r WHERE r.event_id = e.id) AS total_registered,
  (e.quota - (SELECT COUNT(*) FROM registrations r WHERE r.event_id = e.id)) AS remaining_quota
FROM events e;

