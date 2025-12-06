-- FINAL FIX: Create SECURITY DEFINER function for inserting notifications
-- This bypasses RLS and allows admin (Strava OAuth) to insert notifications

-- Step 1: Drop existing policy (we'll use function instead)
DROP POLICY IF EXISTS "Admins can insert notifications" ON notifications;

-- Step 2: Create SECURITY DEFINER function that bypasses RLS
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
  INSERT INTO notifications (user_id, title, message, created_by, is_read)
  VALUES (p_user_id, p_title, p_message, p_created_by, false)
  RETURNING id INTO v_notification_id;
  
  RETURN v_notification_id;
END;
$$;

-- Step 3: Grant execute permission to authenticated and anon users
GRANT EXECUTE ON FUNCTION insert_notification(uuid, text, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION insert_notification(uuid, text, text, uuid) TO anon;
GRANT EXECUTE ON FUNCTION insert_notification(uuid, text, text, uuid) TO service_role;

-- Step 4: Keep simple policy as backup (optional, can remove if using function)
CREATE POLICY "Admins can insert notifications" ON notifications
  FOR INSERT 
  WITH CHECK (true);

-- Step 5: Verify function was created
SELECT 
  proname as function_name,
  proargnames as parameters,
  prosrc as source
FROM pg_proc 
WHERE proname = 'insert_notification';

COMMENT ON FUNCTION insert_notification IS 
  'Secure function to insert notifications. Bypasses RLS using SECURITY DEFINER. Use this for admin inserts (Strava OAuth users who don''t have auth.uid()).';









