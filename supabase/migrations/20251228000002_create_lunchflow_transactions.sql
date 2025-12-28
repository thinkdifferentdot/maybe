-- supabase/migrations/20251228000002_create_lunchflow_transactions.sql

CREATE TABLE lunchflow_transactions (
  id TEXT PRIMARY KEY,
  account_id BIGINT NOT NULL REFERENCES lunchflow_accounts(id) ON DELETE CASCADE,
  amount NUMERIC NOT NULL,
  currency TEXT NOT NULL,
  date DATE NOT NULL,
  merchant TEXT,
  description TEXT,
  is_pending BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_lunchflow_transactions_account_date
  ON lunchflow_transactions(account_id, date DESC);
CREATE INDEX idx_lunchflow_transactions_account_pending
  ON lunchflow_transactions(account_id, is_pending);

CREATE TRIGGER update_lunchflow_transactions_updated_at
  BEFORE UPDATE ON lunchflow_transactions
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
