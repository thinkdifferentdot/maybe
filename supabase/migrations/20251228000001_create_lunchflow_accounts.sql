-- supabase/migrations/20251228000001_create_lunchflow_accounts.sql

CREATE TABLE lunchflow_accounts (
  id BIGINT PRIMARY KEY,
  name TEXT NOT NULL,
  institution_name TEXT NOT NULL,
  institution_logo TEXT,
  provider TEXT NOT NULL,
  currency TEXT NOT NULL,
  status TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_lunchflow_accounts_status ON lunchflow_accounts(status);

-- Trigger to auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_lunchflow_accounts_updated_at
  BEFORE UPDATE ON lunchflow_accounts
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
