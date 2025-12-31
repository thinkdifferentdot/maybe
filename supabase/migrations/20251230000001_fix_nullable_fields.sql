-- Fix: Make currency and status nullable to match Lunchflow API schema
-- According to API docs, only id, name, institution_name, institution_logo, and provider are required

ALTER TABLE lunchflow_accounts
ALTER COLUMN currency DROP NOT NULL;

ALTER TABLE lunchflow_accounts
ALTER COLUMN status DROP NOT NULL;
