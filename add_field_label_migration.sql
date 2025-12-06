-- ==========================
-- Add field_label column to form_fields table
-- ==========================
-- Run this SQL in Supabase SQL Editor to add field_label column
-- ==========================

-- Step 1: Add field_label column (nullable first to allow update)
ALTER TABLE form_fields 
ADD COLUMN IF NOT EXISTS field_label text;

-- Step 2: Update existing records to use column_name as field_label
UPDATE form_fields 
SET field_label = column_name 
WHERE field_label IS NULL OR field_label = '';

-- Step 3: Make field_label NOT NULL after populating all records
ALTER TABLE form_fields 
ALTER COLUMN field_label SET NOT NULL;

-- Step 4: Verify the update (optional - uncomment to check)
-- SELECT id, field_label, column_name FROM form_fields LIMIT 10;

-- ==========================
-- Note: After running this migration, update your Flutter code:
-- 1. FormFieldModel now includes fieldLabel
-- 2. UI now has separate "Title" and "Column Name" fields
-- 3. Title is used for display, Column Name is for database
-- ==========================
