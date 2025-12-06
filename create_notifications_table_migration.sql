-- Migration: Create notifications table for admin to send notifications to users
-- This allows admins to send messages/notifications to users

CREATE TABLE IF NOT EXISTS notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  title text NOT NULL,
  message text NOT NULL,
  is_read boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  created_by uuid REFERENCES users(id) ON DELETE SET NULL
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);

-- Enable RLS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own notifications
DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
CREATE POLICY "Users can view own notifications" ON notifications
  FOR SELECT USING (auth.uid() = user_id);

-- Policy: Users can update their own notifications (mark as read)
DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
CREATE POLICY "Users can update own notifications" ON notifications
  FOR UPDATE USING (auth.uid() = user_id);

-- Policy: Admins can insert notifications for any user
-- Since admin login uses Strava OAuth and may not have auth.uid(),
-- we'll use a function-based approach or allow inserts with proper validation
-- For now, we'll create a more permissive policy that can be secured later
DROP POLICY IF EXISTS "Admins can insert notifications" ON notifications;
CREATE POLICY "Admins can insert notifications" ON notifications
  FOR INSERT WITH CHECK (true);
  
-- Note: In production, you should use a function or service role key
-- to securely insert notifications. The above policy allows any authenticated
-- user to insert. Consider creating a function like:
-- CREATE OR REPLACE FUNCTION insert_notification(...)
-- SECURITY DEFINER
-- AS $$ ... $$;

COMMENT ON TABLE notifications IS 'Notifications sent by admins to users';
COMMENT ON COLUMN notifications.user_id IS 'ID of the user who will receive this notification';
COMMENT ON COLUMN notifications.title IS 'Title of the notification';
COMMENT ON COLUMN notifications.message IS 'Message content of the notification';
COMMENT ON COLUMN notifications.is_read IS 'Whether the user has read this notification';
COMMENT ON COLUMN notifications.created_by IS 'ID of the admin who created this notification';

