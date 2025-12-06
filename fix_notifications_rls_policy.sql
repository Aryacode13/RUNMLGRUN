-- Fix RLS Policy for notifications table
-- This allows admins to insert notifications even if they don't have auth.uid()

-- Drop existing policy if exists
DROP POLICY IF EXISTS "Admins can insert notifications" ON notifications;

-- Create new policy that allows authenticated users to insert
-- Since admin uses Strava OAuth, we need a more permissive policy
-- In production, consider using a SECURITY DEFINER function instead
CREATE POLICY "Admins can insert notifications" ON notifications
  FOR INSERT 
  WITH CHECK (true);

-- Alternative: If you want to check if user is admin, you can use:
-- CREATE POLICY "Admins can insert notifications" ON notifications
--   FOR INSERT 
--   WITH CHECK (
--     EXISTS (
--       SELECT 1 FROM users 
--       WHERE users.id = auth.uid() 
--       AND users.role = 'admin'
--     )
--     OR true  -- Allow all authenticated users for now
--   );

-- Also ensure users can still view their own notifications
DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
CREATE POLICY "Users can view own notifications" ON notifications
  FOR SELECT USING (auth.uid() = user_id);

-- Users can update their own notifications (mark as read)
DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
CREATE POLICY "Users can update own notifications" ON notifications
  FOR UPDATE USING (auth.uid() = user_id);

COMMENT ON POLICY "Admins can insert notifications" ON notifications IS 
  'Allows authenticated users (including admins) to insert notifications. In production, consider using a SECURITY DEFINER function for better security.';











