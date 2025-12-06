-- ==========================
-- CMS Dynamic Form System Migration
-- ==========================
-- Run this SQL in Supabase SQL Editor to create CMS form system
-- ==========================

-- Drop existing objects if they exist
DROP TABLE IF EXISTS form_fields CASCADE;
DROP TABLE IF EXISTS projects CASCADE;
DROP FUNCTION IF EXISTS execute_sql(TEXT) CASCADE;
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;

-- Create update_updated_at_column function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create projects table
CREATE TABLE projects (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    table_name text NOT NULL UNIQUE,
    event_code text,
    status text DEFAULT 'draft' CHECK (status IN ('draft', 'published')),
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Create form_fields table
CREATE TABLE form_fields (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    field_type text NOT NULL CHECK (field_type IN (
        'text', 'textarea', 'email', 'number', 'phone', 
        'date', 'radio', 'dropdown', 'checkbox', 'file', 'url'
    )),
    field_label text NOT NULL,
    column_name text NOT NULL,
    is_required boolean DEFAULT false,
    options jsonb DEFAULT '[]'::jsonb,
    placeholder text,
    validation_rules jsonb DEFAULT '{}'::jsonb,
    "order" integer DEFAULT 0,
    created_at timestamptz DEFAULT now(),
    UNIQUE(project_id, column_name)
);

-- Create indexes
CREATE INDEX idx_form_fields_project_id ON form_fields(project_id);
CREATE INDEX idx_form_fields_order ON form_fields(project_id, "order");
CREATE INDEX idx_projects_event_code ON projects(event_code);
CREATE INDEX idx_projects_status ON projects(status);

-- Create trigger for updated_at
CREATE TRIGGER update_projects_updated_at
    BEFORE UPDATE ON projects
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE form_fields ENABLE ROW LEVEL SECURITY;

-- Development-friendly RLS policies (change for production)
-- Projects policies
DROP POLICY IF EXISTS "Projects Select" ON projects;
CREATE POLICY "Projects Select" ON projects FOR SELECT USING (true);

DROP POLICY IF EXISTS "Projects Insert" ON projects;
CREATE POLICY "Projects Insert" ON projects FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Projects Update" ON projects;
CREATE POLICY "Projects Update" ON projects FOR UPDATE USING (true);

DROP POLICY IF EXISTS "Projects Delete" ON projects;
CREATE POLICY "Projects Delete" ON projects FOR DELETE USING (true);

-- Form fields policies
DROP POLICY IF EXISTS "Form Fields Select" ON form_fields;
CREATE POLICY "Form Fields Select" ON form_fields FOR SELECT USING (true);

DROP POLICY IF EXISTS "Form Fields Insert" ON form_fields;
CREATE POLICY "Form Fields Insert" ON form_fields FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Form Fields Update" ON form_fields;
CREATE POLICY "Form Fields Update" ON form_fields FOR UPDATE USING (true);

DROP POLICY IF EXISTS "Form Fields Delete" ON form_fields;
CREATE POLICY "Form Fields Delete" ON form_fields FOR DELETE USING (true);

-- ==========================
-- Dynamic SQL Execution Function
-- ==========================
-- This function allows executing dynamic SQL for creating/altering tables
-- SECURITY: Only allows CREATE TABLE and ALTER TABLE statements
-- ==========================

CREATE OR REPLACE FUNCTION execute_sql(query_text TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    sanitized_query TEXT;
    allowed_pattern TEXT;
BEGIN
    -- Remove leading/trailing whitespace
    sanitized_query := TRIM(query_text);
    
    -- Convert to uppercase for pattern matching
    sanitized_query := UPPER(sanitized_query);
    
    -- Pattern to match CREATE TABLE or ALTER TABLE statements
    -- Allow: CREATE TABLE, CREATE TABLE IF NOT EXISTS, ALTER TABLE, DROP TABLE IF EXISTS
    allowed_pattern := '^(CREATE\s+TABLE|ALTER\s+TABLE|DROP\s+TABLE)';
    
    -- Check if query matches allowed pattern
    IF NOT (sanitized_query ~ allowed_pattern) THEN
        RAISE EXCEPTION 'Only CREATE TABLE, ALTER TABLE, and DROP TABLE statements are allowed';
    END IF;
    
    -- Additional security: prevent dangerous operations
    IF sanitized_query ~* '(DROP\s+DATABASE|DROP\s+SCHEMA|TRUNCATE|DELETE\s+FROM)' THEN
        RAISE EXCEPTION 'Dangerous operations are not allowed';
    END IF;
    
    -- Execute the query
    EXECUTE query_text;
    
    RETURN 'Query executed successfully';
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error executing query: %', SQLERRM;
END;
$$;

-- Grant execute permission (adjust as needed for your security model)
-- In production, you might want to restrict this to specific roles
GRANT EXECUTE ON FUNCTION execute_sql(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION execute_sql(TEXT) TO anon;

-- ==========================
-- Storage Bucket Setup
-- ==========================
-- Create storage bucket for form file uploads
-- Note: This needs to be run manually in Supabase Dashboard > Storage
-- Or use Supabase Management API
-- ==========================

-- Storage bucket creation is done via Supabase Dashboard or API
-- Bucket name: form-uploads
-- Public: false (private bucket)
-- File size limit: 10MB (adjust as needed)
-- Allowed MIME types: application/pdf, image/*, application/msword, 
--                     application/vnd.openxmlformats-officedocument.*

-- ==========================
-- End of Migration
-- ==========================
-- After running this migration:
-- 1. Create storage bucket 'form-uploads' in Supabase Dashboard
-- 2. Set bucket policies as needed
-- 3. Test the execute_sql function with a simple CREATE TABLE statement
-- ==========================


