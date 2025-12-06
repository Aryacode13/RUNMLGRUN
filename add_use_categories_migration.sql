-- ==========================
-- Add use_categories to projects and category_id to form_fields
-- ==========================
-- Run this SQL in Supabase SQL Editor
-- ==========================

-- Add use_categories column to projects table
ALTER TABLE projects
ADD COLUMN IF NOT EXISTS use_categories BOOLEAN DEFAULT false;

-- Add category_id column to form_fields table
-- This links a field to a specific category (null = base field for all categories)
ALTER TABLE form_fields
ADD COLUMN IF NOT EXISTS category_id uuid REFERENCES categories(id) ON DELETE SET NULL;

-- Create index for category_id in form_fields
CREATE INDEX IF NOT EXISTS idx_form_fields_category_id ON form_fields(category_id);

-- Add comments
COMMENT ON COLUMN projects.use_categories IS 'Jika true, project menggunakan categories untuk pricing dan field management';
COMMENT ON COLUMN form_fields.category_id IS 'ID category untuk field ini. NULL = base field untuk semua category';
















