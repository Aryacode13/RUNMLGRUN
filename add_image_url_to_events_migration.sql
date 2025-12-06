-- Migration: Add image_url column to events table
-- This allows events to have an associated image displayed in the event card

-- Add image_url column
ALTER TABLE events
ADD COLUMN IF NOT EXISTS image_url TEXT;

-- Add comment
COMMENT ON COLUMN events.image_url IS 'URL of the event image stored in Supabase Storage';

-- Create index for faster queries (optional, but recommended if you'll filter by image_url)
-- CREATE INDEX IF NOT EXISTS idx_events_image_url ON events(image_url) WHERE image_url IS NOT NULL;
















