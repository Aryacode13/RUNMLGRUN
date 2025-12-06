-- Fix: Allow FCM token to be updated when user changes on same device
-- Problem: fcm_token has UNIQUE constraint, so one token can only be linked to one user
-- Solution: Update the constraint to allow updating user_id when same token is used

-- Option 1: Remove UNIQUE constraint (Recommended)
-- This allows one FCM token to be updated to different user_id
-- Since one device = one FCM token, and device can login with different users

ALTER TABLE user_fcm_tokens 
DROP CONSTRAINT IF EXISTS user_fcm_tokens_fcm_token_key;

-- Option 2: Keep UNIQUE but allow update (Alternative)
-- If you want to keep UNIQUE constraint, the code will handle update via upsert with onConflict

-- Note: The Flutter code already handles this by:
-- 1. Checking if FCM token exists with different user_id
-- 2. If exists, update user_id instead of insert
-- 3. Using upsert with onConflict: 'fcm_token'

COMMENT ON TABLE user_fcm_tokens IS 
  'Stores FCM tokens for push notifications. One device (one FCM token) can be linked to different users when user logs in/out.';










