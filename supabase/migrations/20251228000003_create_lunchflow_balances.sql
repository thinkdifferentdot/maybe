-- supabase/migrations/20251228000003_create_lunchflow_balances.sql

CREATE TABLE lunchflow_balances (
  id BIGSERIAL PRIMARY KEY,
  account_id BIGINT NOT NULL REFERENCES lunchflow_accounts(id) ON DELETE CASCADE,
  amount NUMERIC NOT NULL,
  currency TEXT NOT NULL,
  synced_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_lunchflow_balances_account_synced
  ON lunchflow_balances(account_id, synced_at DESC);
