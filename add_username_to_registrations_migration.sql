-- Add username column to registrations table
ALTER TABLE registrations
ADD COLUMN IF NOT EXISTS username text;

-- Add comment to explain the column
COMMENT ON COLUMN registrations.username IS 'Username of the user who registered for the event';














