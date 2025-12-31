# Supabase to Lunchflow Sync Verification Guide

## Prerequisites

- Supabase CLI installed ✓ (confirmed at `/opt/homebrew/bin/supabase`)
- Docker Desktop running (needed for local testing)
- Supabase project credentials (URL and service role key)
- Lunchflow API key

## Environment Variables Required

Make sure these are set in your environment:

```bash
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"
export LUNCHFLOW_API_KEY="your-lunchflow-api-key"
```

---

## Method 1: Verify via Supabase Dashboard

### Step 1: Check Edge Function

1. Go to https://supabase.com/dashboard
2. Select your project
3. Navigate to **Edge Functions** → **sync-lunchflow**
4. Click **"Invoke"** to manually trigger a sync

### Step 2: Verify Tables

Navigate to **Table Editor** and check:

#### lunchflow_accounts
```sql
SELECT * FROM lunchflow_accounts
WHERE status = 'ACTIVE'
ORDER BY updated_at DESC;
```

#### lunchflow_transactions
```sql
SELECT * FROM lunchflow_transactions
ORDER BY date DESC
LIMIT 20;
```

#### lunchflow_balances
```sql
SELECT * FROM lunchflow_balances
ORDER BY synced_at DESC
LIMIT 10;
```

#### lunchflow_sync_log
```sql
SELECT * FROM lunchflow_sync_log
ORDER BY sync_started_at DESC
LIMIT 5;
```

Expected results:
- **Sync status**: "completed" (not "failed" or "pending")
- **Accounts synced**: > 0
- **Transactions synced**: > 0
- **No error_message** values

---

## Method 2: Verify via Supabase CLI

### Step 1: Initialize Supabase (if not already done)

```bash
# From the project root
cd /Users/andrewbewernick/GitHub/local-budget/maybe/.worktrees/lunchflow-supabase

# Link to your remote project
supabase link --project-ref your-project-ref
```

### Step 2: Start Docker Desktop

The Supabase CLI requires Docker to run locally. Make sure Docker Desktop is running.

### Step 3: Start Local Supabase (Optional)

```bash
# Start local Supabase instance
supabase start
```

This will give you local URLs:
- API URL: http://localhost:54321
- Studio URL: http://localhost:54323
- Inbucket URL: http://localhost:54324

### Step 4: Deploy Edge Function

```bash
# Deploy the sync function to your remote Supabase project
supabase functions deploy sync-lunchflow

# Set environment secrets
supabase secrets set LUNCHFLOW_API_KEY=your-api-key
```

### Step 5: Invoke Edge Function via CLI

```bash
# Invoke the function remotely
supabase functions invoke sync-lunchflow \
  --project-ref your-project-ref
```

Expected response:
```json
{
  "success": true,
  "accounts_synced": 5,
  "transactions_synced": 150
}
```

### Step 6: Query Tables via CLI

```bash
# Check accounts
supabase db dump --data-only -t lunchflow_accounts

# Or use SQL directly
supabase db execute --project-ref your-project-ref \
  "SELECT COUNT(*) FROM lunchflow_accounts WHERE status = 'ACTIVE';"
```

---

## Method 3: Verify via HTTP API

You can also invoke the edge function directly via HTTP:

```bash
curl -X POST "https://your-project.supabase.co/functions/v1/sync-lunchflow" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json"
```

Expected response:
```json
{
  "success": true,
  "accounts_synced": 5,
  "transactions_synced": 150
}
```

---

## Method 4: Verify the Full Flow (Supabase → Rails)

### Step 1: Trigger Supabase Sync

Use any of the methods above to trigger the `sync-lunchflow` function.

### Step 2: Verify Data in Supabase

Check that data exists in Supabase tables:
- `lunchflow_accounts`
- `lunchflow_transactions`
- `lunchflow_balances`

### Step 3: Trigger Rails Sync

In your Rails console:

```ruby
# Open Rails console
bin/rails console

# Find or create a Lunchflow connection
connection = LunchflowConnection.first
# or create one: connection = LunchflowConnection.create!(name: "My Connection", family: Family.first)

# Create a sync record
sync = connection.syncs.create!

# Perform the sync
syncer = LunchflowConnection::Syncer.new(connection)
syncer.perform_sync(sync)

# Check results
connection.lunchflow_accounts.count
# => Should show accounts

connection.accounts.first&.entries&.count
# => Should show transactions
```

### Step 4: Verify Data in Maybe

```ruby
# Check lunchflow accounts
LunchflowAccount.all

# Check linked Maybe accounts
Account.joins(:lunchflow_account)

# Check imported transactions
Entry.where("plaid_id LIKE 'lunchflow_%'")
```

---

## Troubleshooting

### Edge Function Fails

Check logs:
```bash
# View function logs
supabase functions logs sync-lunchflow --project-ref your-project-ref
```

Common issues:
- Missing `LUNCHFLOW_API_KEY` secret
- Invalid Lunchflow API credentials
- Network/firewall blocking Lunchflow API

### No Data in Supabase Tables

1. Check that migrations were applied:
   ```bash
   supabase db diff --linked
   ```

2. Apply migrations if needed:
   ```bash
   supabase db push
   ```

### Rails Sync Fails

Check the Rails logs:
```bash
tail -f log/development.log
```

Common issues:
- `SUPABASE_URL` or `SUPABASE_SERVICE_ROLE_KEY` not set
- Network issues connecting to Supabase
- Invalid Supabase credentials

---

## Monitoring Sync Health

### Check Sync Logs

```sql
-- Via Supabase Dashboard SQL Editor
SELECT
  id,
  status,
  accounts_synced,
  transactions_synced,
  sync_started_at,
  sync_completed_at,
  error_message,
  EXTRACT(EPOCH FROM (sync_completed_at - sync_started_at)) as duration_seconds
FROM lunchflow_sync_log
ORDER BY sync_started_at DESC
LIMIT 10;
```

### Expected Healthy Sync:
- Status: `completed`
- Accounts synced: > 0
- Transactions synced: > 0
- Duration: < 30 seconds typically
- Error message: NULL

---

## Quick Reference Commands

```bash
# Check Supabase CLI version
supabase --version

# Link to project
supabase link --project-ref YOUR_REF

# Deploy function
supabase functions deploy sync-lunchflow

# Set secrets
supabase secrets set LUNCHFLOW_API_KEY=xxx

# Invoke function
supabase functions invoke sync-lunchflow

# View logs
supabase functions logs sync-lunchflow

# Check database status
supabase db diff

# Push migrations
supabase db push
```

---

## Next Steps

Once verification is complete:

1. ✓ Verify Supabase edge function works
2. ✓ Verify data appears in Supabase tables
3. ✓ Verify Rails can read from Supabase
4. ✓ Verify data appears in Maybe
5. Set up automated syncing (cron job or webhook)
6. Monitor sync performance and errors
