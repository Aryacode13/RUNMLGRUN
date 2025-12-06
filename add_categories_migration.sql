-- ==========================
-- Categories Migration
-- ==========================
-- Run this SQL in Supabase SQL Editor to add category support
-- ==========================

-- Create categories table
CREATE TABLE IF NOT EXISTS categories (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    name text NOT NULL,
    price DECIMAL(10, 2) DEFAULT 0,
    "order" integer DEFAULT 0,
    created_at timestamptz DEFAULT now(),
    UNIQUE(project_id, name)
);

-- Create category_fields table
-- This table maps which fields should be added/removed/hidden/shown for each category
CREATE TABLE IF NOT EXISTS category_fields (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id uuid NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    field_id uuid NOT NULL REFERENCES form_fields(id) ON DELETE CASCADE,
    action text NOT NULL CHECK (action IN ('add', 'remove', 'hide', 'show')),
    created_at timestamptz DEFAULT now(),
    UNIQUE(category_id, field_id)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_categories_project_id ON categories(project_id);
CREATE INDEX IF NOT EXISTS idx_categories_order ON categories(project_id, "order");
CREATE INDEX IF NOT EXISTS idx_category_fields_category_id ON category_fields(category_id);
CREATE INDEX IF NOT EXISTS idx_category_fields_field_id ON category_fields(field_id);

-- Add comments
COMMENT ON TABLE categories IS 'Categories for projects (e.g., 10k, 5k, 7k for running events)';
COMMENT ON TABLE category_fields IS 'Maps fields to categories - defines which fields to add/remove/hide/show for each category';
COMMENT ON COLUMN categories.price IS 'Price for this category (overrides project registration_fee if set)';
COMMENT ON COLUMN category_fields.action IS 'add: add this field for this category, remove: remove this field for this category, hide: hide this field for this category, show: show this field for this category';

-- Enable RLS
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE category_fields ENABLE ROW LEVEL SECURITY;

-- Development-friendly RLS policies (change for production)
-- Categories policies
DROP POLICY IF EXISTS "Categories Select" ON categories;
CREATE POLICY "Categories Select" ON categories FOR SELECT USING (true);

DROP POLICY IF EXISTS "Categories Insert" ON categories;
CREATE POLICY "Categories Insert" ON categories FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Categories Update" ON categories;
CREATE POLICY "Categories Update" ON categories FOR UPDATE USING (true);

DROP POLICY IF EXISTS "Categories Delete" ON categories;
CREATE POLICY "Categories Delete" ON categories FOR DELETE USING (true);

-- Category fields policies
DROP POLICY IF EXISTS "Category Fields Select" ON category_fields;
CREATE POLICY "Category Fields Select" ON category_fields FOR SELECT USING (true);

DROP POLICY IF EXISTS "Category Fields Insert" ON category_fields;
CREATE POLICY "Category Fields Insert" ON category_fields FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Category Fields Update" ON category_fields;
CREATE POLICY "Category Fields Update" ON category_fields FOR UPDATE USING (true);

DROP POLICY IF EXISTS "Category Fields Delete" ON category_fields;
CREATE POLICY "Category Fields Delete" ON category_fields FOR DELETE USING (true);
















