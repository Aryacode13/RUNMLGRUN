-- Enable Realtime for notifications table
-- This is required for push notifications to work
-- Run this SQL in Supabase SQL Editor

-- Enable Realtime for notifications table
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;

-- Verify Realtime is enabled
-- You can check this in Supabase Dashboard > Database > Replication
-- The 'notifications' table should appear in the list












