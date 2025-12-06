-- Migration: Add payment_receipt_url column to registrations table
-- This allows users to view their payment receipt after registering for paid events

ALTER TABLE registrations
ADD COLUMN IF NOT EXISTS payment_receipt_url text;

COMMENT ON COLUMN registrations.payment_receipt_url IS 'URL to the payment receipt/proof of payment uploaded by the user during registration';












