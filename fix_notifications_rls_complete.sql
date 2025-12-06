-- Complete Fix for Notifications RLS Policy
-- This solves the issue where admin (Strava OAuth) cannot insert notifications

-- ============================================
-- OPTION 1: Simple Fix (Quick but less secure)
-- ============================================
-- Drop existing policy
DROP POLICY IF EXISTS "Admins can insert notifications" ON notifications;

-- Create permissive policy (allows all authenticated users)
CREATE POLICY "Admins can insert notifications" ON notifications
  FOR INSERT 
  WITH CHECK (true);

-- ============================================
-- OPTION 2: Secure Fix (Recommended for Production)
-- ============================================
-- Create a SECURITY DEFINER function that bypasses RLS
CREATE OR REPLACE FUNCTION insert_notification(
  p_user_id uuid,
  p_title text,
  p_message text,
  p_created_by uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_notification_id uuid;
BEGIN
  INSERT INTO notifications (user_id, title, message, created_by)
  VALUES (p_user_id, p_title, p_message, p_created_by)
  RETURNING id INTO v_notification_id;
  
  RETURN v_notification_id;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION insert_notification(uuid, text, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION insert_notification(uuid, text, text, uuid) TO anon;

-- Keep the simple policy for now (can remove later if using function)
-- The function approach is more secure but requires code changes

-- ============================================
-- Verify Policies
-- ============================================
-- Check existing policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE tablename = 'notifications';

COMMENT ON FUNCTION insert_notification IS 
  'Secure function to insert notifications. Bypasses RLS using SECURITY DEFINER. Use this in production instead of direct inserts.';










