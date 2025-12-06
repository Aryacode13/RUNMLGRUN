-- ==========================
-- Add is_active column to users table
-- ==========================
-- Run this SQL in Supabase SQL Editor to add is_active column
-- ==========================

-- Step 1: Add is_active column (default true for existing users)
ALTER TABLE users
ADD COLUMN IF NOT EXISTS is_active boolean DEFAULT true NOT NULL;

-- Step 2: Update existing users to be active (optional, already handled by DEFAULT)
-- UPDATE users SET is_active = true WHERE is_active IS NULL;

-- Step 3: Verify the column was added (optional - uncomment to check)
-- SELECT id, username, firstname, lastname, is_active FROM users LIMIT 10;

-- ==========================
-- Notes:
-- - is_active is boolean type
-- - Default value is true (all existing users will be active)
-- - Column is NOT NULL (required)
-- - Use this column to soft-delete or deactivate users instead of hard delete
-- ==========================


















