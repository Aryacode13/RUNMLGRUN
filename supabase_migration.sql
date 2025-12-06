-- ==========================
-- Supabase SQL: Flutter + Strava App
-- ==========================
-- WARNING: copy entire block and run once in Supabase SQL Editor
-- Drops existing objects then re-create schema (development)
-- ==========================

-- Drop objects if exist
DROP VIEW IF EXISTS event_stats CASCADE;
DROP TABLE IF EXISTS registrations CASCADE;
DROP TABLE IF EXISTS events CASCADE;
DROP TABLE IF EXISTS activities CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;

-- Create users table
CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  strava_id bigint UNIQUE,
  username text,
  firstname text,
  lastname text,
  profile_picture text,
  access_token text,
  refresh_token text,
  token_expires bigint,
  role text DEFAULT 'user',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create activities table
CREATE TABLE activities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  strava_activity_id bigint UNIQUE,
  name text,
  distance double precision,
  moving_time integer,
  elapsed_time integer,
  type text,
  start_date timestamptz,
  map_polyline text,
  created_at timestamptz DEFAULT now()
);

-- Create events table
CREATE TABLE events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text,
  quota integer NOT NULL,
  created_by uuid REFERENCES users(id),
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create registrations table
CREATE TABLE registrations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid REFERENCES events(id) ON DELETE CASCADE,
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  registered_at timestamptz DEFAULT now(),
  CONSTRAINT unique_registration UNIQUE(event_id, user_id)
);

-- View: event stats
CREATE VIEW event_stats AS
SELECT
  e.id,
  e.title,
  e.description,
  e.quota,
  e.is_active,
  e.created_by,
  e.created_at,
  (SELECT COUNT(*) FROM registrations r WHERE r.event_id = e.id) AS total_registered,
  (e.quota - (SELECT COUNT(*) FROM registrations r WHERE r.event_id = e.id)) AS remaining_quota
FROM events e;

-- Trigger function for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_events_updated_at ON events;
CREATE TRIGGER update_events_updated_at
  BEFORE UPDATE ON events
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE registrations ENABLE ROW LEVEL SECURITY;

-- Development-friendly policies (change for production)
-- USERS
DROP POLICY IF EXISTS "Users Select" ON users;
CREATE POLICY "Users Select" ON users FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users Insert" ON users;
CREATE POLICY "Users Insert" ON users FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Users Update" ON users;
CREATE POLICY "Users Update" ON users FOR UPDATE USING (true);

DROP POLICY IF EXISTS "Users Delete" ON users;
CREATE POLICY "Users Delete" ON users FOR DELETE USING (true);

-- ACTIVITIES
DROP POLICY IF EXISTS "Activities Select" ON activities;
CREATE POLICY "Activities Select" ON activities FOR SELECT USING (true);

DROP POLICY IF EXISTS "Activities Insert" ON activities;
CREATE POLICY "Activities Insert" ON activities FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Activities Update" ON activities;
CREATE POLICY "Activities Update" ON activities FOR UPDATE USING (true);

DROP POLICY IF EXISTS "Activities Delete" ON activities;
CREATE POLICY "Activities Delete" ON activities FOR DELETE USING (true);

-- EVENTS
DROP POLICY IF EXISTS "Events Select" ON events;
CREATE POLICY "Events Select" ON events FOR SELECT USING (true);

DROP POLICY IF EXISTS "Events Insert" ON events;
CREATE POLICY "Events Insert" ON events FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Events Update" ON events;
CREATE POLICY "Events Update" ON events FOR UPDATE USING (true);

DROP POLICY IF EXISTS "Events Delete" ON events;
CREATE POLICY "Events Delete" ON events FOR DELETE USING (true);

-- REGISTRATIONS
DROP POLICY IF EXISTS "Registrations Select" ON registrations;
CREATE POLICY "Registrations Select" ON registrations FOR SELECT USING (true);

DROP POLICY IF EXISTS "Registrations Insert" ON registrations;
CREATE POLICY "Registrations Insert" ON registrations FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Registrations Update" ON registrations;
CREATE POLICY "Registrations Update" ON registrations FOR UPDATE USING (true);

DROP POLICY IF EXISTS "Registrations Delete" ON registrations;
CREATE POLICY "Registrations Delete" ON registrations FOR DELETE USING (true);

-- ==========================
-- End of SQL
-- ==========================

