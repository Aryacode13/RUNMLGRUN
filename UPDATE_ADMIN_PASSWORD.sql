-- ==========================
-- Update Admin Email & Link Strava ID
-- ==========================
-- Run this SQL to update admin email or link Strava ID to admin
-- ==========================

-- Update admin email (if needed)
UPDATE admins
SET email = 'aryahidayatz1111@gmail.com'
WHERE email != 'aryahidayatz1111@gmail.com';

-- Link Strava ID to admin (replace YOUR_STRAVA_ID with actual Strava ID)
-- To get your Strava ID: login with Strava first, then check the users table
-- Example:
-- UPDATE admins
-- SET strava_id = 12345678  -- Replace with your actual Strava ID
-- WHERE email = 'aryahidayatz1111@gmail.com';

-- ==========================
-- How to Link Strava ID to Admin:
-- ==========================
-- 1. Login to your app with Strava OAuth (as regular user)
-- 2. Check the users table in Supabase to find your strava_id
-- 3. Run the UPDATE query above with your strava_id
-- 4. After linking, you can login as admin using Strava OAuth
--
-- OR use the admin login page:
-- - Login with Strava OAuth
-- - Enter your email: aryahidayatz1111@gmail.com
-- - System will automatically link your Strava ID to admin email
-- ==========================

-- ==========================
-- Add New Admin Email:
-- ==========================
-- To add another admin email, run:
-- INSERT INTO admins (email, full_name, is_active)
-- VALUES (
--   'newadmin@example.com',
--   'New Administrator',
--   true
-- );
-- ==========================
