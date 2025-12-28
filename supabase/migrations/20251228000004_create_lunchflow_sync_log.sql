-- supabase/migrations/20251228000004_create_lunchflow_sync_log.sql

CREATE TABLE lunchflow_sync_log (
  id BIGSERIAL PRIMARY KEY,
  sync_started_at TIMESTAMPTZ NOT NULL,
  sync_completed_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'pending',
  accounts_synced INT DEFAULT 0,
  transactions_synced INT DEFAULT 0,
  error_message TEXT
);

CREATE INDEX idx_lunchflow_sync_log_status
  ON lunchflow_sync_log(status, sync_started_at DESC);
