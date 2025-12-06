-- ==========================
-- Remove field_label column from form_fields table
-- ==========================
-- Run this SQL in Supabase SQL Editor to remove field_label column
-- ==========================

-- Remove field_label column from form_fields table
ALTER TABLE form_fields DROP COLUMN IF EXISTS field_label;

-- ==========================
-- Note: After running this migration, update your Flutter code:
-- 1. Remove fieldLabel from FormFieldModel
-- 2. Use columnName for display (convert to Title Case)
-- 3. Update all UI to use columnName instead of fieldLabel
-- ==========================


















