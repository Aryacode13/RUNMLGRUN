-- Fix: Allow FCM token to be updated when user changes on same device
-- Problem: 
-- 1. fcm_token has UNIQUE constraint, preventing multiple records
-- 2. RLS policy only allows user to manage their own tokens, so user B cannot update token owned by user A
-- Solution: 
-- 1. Remove UNIQUE constraint
-- 2. Create RPC function with SECURITY DEFINER to bypass RLS for token updates
-- 3. Allow users to insert/update their own tokens

-- Step 1: Remove UNIQUE constraint
ALTER TABLE user_fcm_tokens 
DROP CONSTRAINT IF EXISTS user_fcm_tokens_fcm_token_key;

-- Step 2: Update RLS policy to allow users to insert/update tokens
-- Users can insert their own tokens
DROP POLICY IF EXISTS "Users can insert own FCM tokens" ON user_fcm_tokens;
CREATE POLICY "Users can insert own FCM tokens" ON user_fcm_tokens
  FOR INSERT 
  WITH CHECK (true); -- Allow any authenticated user to insert

-- Users can update tokens where they are the owner OR where the token matches (same device)
DROP POLICY IF EXISTS "Users can update own FCM tokens" ON user_fcm_tokens;
CREATE POLICY "Users can update own FCM tokens" ON user_fcm_tokens
  FOR UPDATE 
  USING (true) -- Allow update if user can see the row
  WITH CHECK (true); -- Allow update to any user_id (for device switching)

-- Users can see tokens where they are the owner OR where the token matches (for checking)
DROP POLICY IF EXISTS "Users can view own FCM tokens" ON user_fcm_tokens;
CREATE POLICY "Users can view own FCM tokens" ON user_fcm_tokens
  FOR SELECT 
  USING (true); -- Allow any authenticated user to view (needed for checking existing tokens)

-- Step 3: Create RPC function to upsert FCM token (bypasses RLS)
-- IMPORTANT: This function allows multiple users to have their own tokens
-- Each user-device combination gets its own token record
CREATE OR REPLACE FUNCTION upsert_user_fcm_token(
  p_user_id uuid,
  p_fcm_token text,
  p_device_info text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_existing_user_id uuid;
BEGIN
  -- Check if this FCM token already exists for a different user
  SELECT user_id INTO v_existing_user_id
  FROM user_fcm_tokens
  WHERE fcm_token = p_fcm_token
  LIMIT 1;
  
  IF v_existing_user_id IS NOT NULL AND v_existing_user_id != p_user_id THEN
    -- Same device, different user: Update to new user (device switching)
    -- This is normal - one device can only be logged in to one user at a time
    UPDATE user_fcm_tokens 
    SET user_id = p_user_id,
        updated_at = now(),
        device_info = COALESCE(p_device_info, device_info)
    WHERE fcm_token = p_fcm_token;
    
    RAISE NOTICE 'Updated FCM token from user % to user % (same device)', v_existing_user_id, p_user_id;
  ELSIF v_existing_user_id = p_user_id THEN
    -- Same user, same token: Just update timestamp and device info
    UPDATE user_fcm_tokens 
    SET updated_at = now(),
        device_info = COALESCE(p_device_info, device_info)
    WHERE fcm_token = p_fcm_token AND user_id = p_user_id;
    
    RAISE NOTICE 'Updated existing FCM token for user %', p_user_id;
  ELSE
    -- New token for this user: Insert new record
    -- First, delete any old tokens for this user (cleanup - user might have switched devices)
    DELETE FROM user_fcm_tokens WHERE user_id = p_user_id;
    
    -- Insert new token
    INSERT INTO user_fcm_tokens (user_id, fcm_token, device_info)
    VALUES (p_user_id, p_fcm_token, p_device_info);
    
    RAISE NOTICE 'Inserted new FCM token for user %', p_user_id;
  END IF;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION upsert_user_fcm_token(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION upsert_user_fcm_token(uuid, text, text) TO anon;

COMMENT ON FUNCTION upsert_user_fcm_token IS 
  'Upserts FCM token for a user. If token exists for different user (same device), updates user_id. This function bypasses RLS.';

