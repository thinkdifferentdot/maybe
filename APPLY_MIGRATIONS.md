# Apply Lunchflow Migrations to Supabase

## The Issue

Your edge function is working, but the database tables don't exist yet:
```
Could not find the table 'public.lunchflow_sync_log' in the schema cache
```

## Quick Fix: Run Migrations via Dashboard

### Method 1: Copy-Paste SQL (Easiest)

1. **Go to Supabase Dashboard**
2. Navigate to **SQL Editor**
3. Click **"New Query"**
4. **Copy and paste** the complete SQL below
5. Click **"Run"**

```sql
-- Migration 1: Create lunchflow_accounts table
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

-- Migration 2: Create lunchflow_transactions table
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

-- Migration 3: Create lunchflow_balances table
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

-- Migration 4: Create lunchflow_sync_log table
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
```

6. **Verify tables were created:**
   - Go to **Table Editor**
   - You should see: `lunchflow_accounts`, `lunchflow_transactions`, `lunchflow_balances`, `lunchflow_sync_log`

---

### Method 2: Using Supabase CLI

If you have the CLI linked to your project:

```bash
# Link to your remote project (if not already linked)
supabase link --project-ref your-project-ref

# Push migrations to remote database
supabase db push

# Or reset the remote database (⚠️ destructive!)
# supabase db reset --linked
```

---

## Verify Tables Exist

After running the migration, verify in **Dashboard → Table Editor**:

- ✅ `lunchflow_accounts` - Stores connected bank accounts
- ✅ `lunchflow_transactions` - Stores transaction data
- ✅ `lunchflow_balances` - Stores account balances
- ✅ `lunchflow_sync_log` - Tracks sync operations

Or via SQL:

```sql
-- Check all tables exist
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name LIKE 'lunchflow_%';
```

Expected output:
```
lunchflow_accounts
lunchflow_balances
lunchflow_sync_log
lunchflow_transactions
```

---

## Test the Function Again

Once tables are created:

1. **Edge Functions** → **sync-lunchflow**
2. Click **"Invoke"**
3. Check **Logs**

**Expected successful logs:**
```
Starting Lunchflow sync...
Created sync log: 1
Fetching accounts from Lunchflow...
Accounts response status: 200
Found X accounts
Syncing account: 123 - Chase Checking
...
Sync completed successfully
```

**Expected response:**
```json
{
  "success": true,
  "accounts_synced": 5,
  "transactions_synced": 150
}
```

---

## Troubleshooting

### "relation already exists"

If you get this error, tables are already created. Skip to testing the function.

### "permission denied"

Make sure you're using the **SQL Editor** in the Dashboard with your project's admin credentials.

### "foreign key violation"

The migrations must run in order:
1. accounts (first, no dependencies)
2. transactions (depends on accounts)
3. balances (depends on accounts)
4. sync_log (no dependencies)

The SQL above is already in the correct order.

---

## Next Steps

After migrations are applied and function works:

1. ✅ Verify data appears in tables
2. ✅ Test Rails sync (`LunchflowConnection::Syncer`)
3. ✅ Verify data flows to Maybe
4. Set up automated syncing
