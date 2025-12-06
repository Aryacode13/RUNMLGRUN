-- Create table to store FCM tokens for push notifications
-- This allows backend to send FCM push notifications to specific users

CREATE TABLE IF NOT EXISTS user_fcm_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  fcm_token text NOT NULL UNIQUE,
  device_info text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_user_id ON user_fcm_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_token ON user_fcm_tokens(fcm_token);

-- Enable RLS
ALTER TABLE user_fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see and update their own tokens
DROP POLICY IF EXISTS "Users can manage own FCM tokens" ON user_fcm_tokens;
CREATE POLICY "Users can manage own FCM tokens" ON user_fcm_tokens
  FOR ALL USING (auth.uid() = user_id);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_user_fcm_tokens_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update updated_at
DROP TRIGGER IF EXISTS update_user_fcm_tokens_updated_at ON user_fcm_tokens;
CREATE TRIGGER update_user_fcm_tokens_updated_at
  BEFORE UPDATE ON user_fcm_tokens
  FOR EACH ROW
  EXECUTE FUNCTION update_user_fcm_tokens_updated_at();

COMMENT ON TABLE user_fcm_tokens IS 'Stores FCM tokens for push notifications to users';
COMMENT ON COLUMN user_fcm_tokens.user_id IS 'ID of the user who owns this FCM token';
COMMENT ON COLUMN user_fcm_tokens.fcm_token IS 'Firebase Cloud Messaging token for push notifications';
COMMENT ON COLUMN user_fcm_tokens.device_info IS 'Optional device information (model, OS version, etc.)';












