# Fixing the 401 Unauthorized Error

## The Problem

Your edge function is returning **401 Unauthorized** because the Supabase platform is blocking anonymous invocations. The function needs to be configured to allow calls without user authentication.

## The Solution

I've updated your `index.ts` with:
1. ✅ Better error handling and logging
2. ✅ Flexible response parsing (handles different API response structures)
3. ✅ Changed `accountId` → `account_id` and `isPending` → `is_pending` (likely snake_case)
4. ✅ More detailed console logging

However, you still need to **configure the function to allow anonymous access**.

---

## Method 1: Deploy via Supabase Dashboard (Easiest)

### Step 1: Update Function Settings

1. Go to **Supabase Dashboard** → **Edge Functions** → **sync-lunchflow**
2. Click **Settings** (or **Edit**)
3. Look for **"Verify JWT"** or **"Require Authentication"** setting
4. **Disable it** (or set to "Allow anonymous")
5. Click **Save**

### Step 2: Redeploy the Function

1. Still in **sync-lunchflow** → click **Edit**
2. Replace the entire code with the updated `index.ts` content
3. Click **Deploy**

### Step 3: Test Again

1. Click **Invoke**
2. Check the **Logs** tab
3. You should now see:
   ```
   Starting Lunchflow sync...
   Fetching accounts from Lunchflow...
   Accounts response status: 200
   ```

---

## Method 2: Deploy via Supabase CLI

### Step 1: Configure Function (Create config.toml if missing)

Create or update `supabase/config.toml`:

```toml
[functions.sync-lunchflow]
verify_jwt = false  # Allow anonymous invocation
```

### Step 2: Deploy

```bash
supabase functions deploy sync-lunchflow
```

### Step 3: Invoke with Service Role Key

If you still get 401, invoke with the service role key:

```bash
supabase functions invoke sync-lunchflow \
  --header "Authorization: Bearer YOUR_SERVICE_ROLE_KEY"
```

---

## Method 3: Invoke from Rails with Authorization

If you want to keep JWT verification **enabled** for security, invoke with proper auth:

### Update `app/models/lunchflow_connection/syncer.rb`:

```ruby
def perform_sync(sync)
  # Build authorization header with service role key
  supabase_url = ENV["SUPABASE_URL"] ||
                 Rails.application.credentials.dig(:supabase, :url) ||
                 Setting.supabase_url

  service_key = ENV["SUPABASE_SERVICE_ROLE_KEY"] ||
                Rails.application.credentials.dig(:supabase, :service_key) ||
                Setting.supabase_service_key

  uri = URI("#{supabase_url}/functions/v1/sync-lunchflow")
  request = Net::HTTP::Post.new(uri)
  request["Authorization"] = "Bearer #{service_key}"
  request["Content-Type"] = "application/json"

  http = Net::HTTP.new(uri.hostname, uri.port)
  http.use_ssl = true

  response = http.request(request)

  unless response.is_a?(Net::HTTPSuccess)
    raise "Supabase function error: #{response.code} - #{response.body}"
  end

  # Then fetch the synced data
  supabase_accounts = fetch_accounts_from_supabase
  sync_accounts(supabase_accounts)
  # ... rest of your sync logic
end
```

---

## What Changed in the Updated Function

### 1. Better Response Handling

**Old:**
```typescript
const accounts: LunchflowAccount[] = accountsData.accounts || []
```

**New:**
```typescript
let accounts: LunchflowAccount[] = []
if (Array.isArray(accountsData)) {
  accounts = accountsData
} else if (accountsData.accounts && Array.isArray(accountsData.accounts)) {
  accounts = accountsData.accounts
} else if (accountsData.data && Array.isArray(accountsData.data)) {
  accounts = accountsData.data
}
```

This handles:
- `[...]` (direct array)
- `{ "accounts": [...] }`
- `{ "data": [...] }`

### 2. Fixed Field Names

**Changed from camelCase to snake_case:**
- `accountId` → `account_id`
- `isPending` → `is_pending`

Most APIs use snake_case, not camelCase.

### 3. Enhanced Logging

Every step now logs to help you debug:
```
Starting Lunchflow sync...
Fetching accounts from Lunchflow...
Accounts response status: 200
Found 5 accounts
Syncing account: 123 - Chase Checking
Fetching transactions for account 123...
Found 42 transactions for account 123
```

### 4. Better Error Messages

**Old:**
```typescript
throw new Error(`Lunchflow API error: ${accountsResponse.status}`)
```

**New:**
```typescript
const errorText = await accountsResponse.text()
console.error('Lunchflow API error response:', errorText)
throw new Error(`Lunchflow API error: ${accountsResponse.status} - ${errorText}`)
```

Now you see the **actual error message** from Lunchflow.

---

## Testing Steps

### 1. Verify Secrets are Set

In Supabase Dashboard → **Project Settings** → **Edge Functions** → **Secrets**:

- ✅ `LUNCHFLOW_API_KEY` = your Lunchflow API key
- ✅ `SUPABASE_URL` = auto-set
- ✅ `SUPABASE_SERVICE_ROLE_KEY` = auto-set

### 2. Deploy Updated Function

Use Method 1 (Dashboard) or Method 2 (CLI) above.

### 3. Invoke and Check Logs

**Dashboard:**
1. Edge Functions → sync-lunchflow
2. Click **Invoke**
3. Check **Logs** tab

**Expected successful output:**
```json
{
  "success": true,
  "accounts_synced": 5,
  "transactions_synced": 150
}
```

**Expected logs:**
```
Starting Lunchflow sync...
Created sync log: a1b2c3d4-...
Fetching accounts from Lunchflow...
Accounts response status: 200
Accounts response type: object isArray: false
Found 5 accounts
Syncing account: 123 - Chase Checking
Fetching transactions for account 123...
Found 42 transactions for account 123
...
Sync completed successfully
```

### 4. Verify Data in Database

**Dashboard → Table Editor:**

```sql
-- Check sync logs
SELECT * FROM lunchflow_sync_log ORDER BY sync_started_at DESC LIMIT 5;

-- Check accounts
SELECT * FROM lunchflow_accounts;

-- Check transactions
SELECT * FROM lunchflow_transactions ORDER BY date DESC LIMIT 20;

-- Check balances
SELECT * FROM lunchflow_balances ORDER BY synced_at DESC LIMIT 10;
```

---

## Common Issues

### Issue 1: Still Getting 401

**Cause:** JWT verification is still enabled

**Fix:** Make sure you disabled "Verify JWT" in function settings, or use service role key

### Issue 2: "LUNCHFLOW_API_KEY not configured"

**Cause:** Secret not set

**Fix:**
```bash
supabase secrets set LUNCHFLOW_API_KEY=your_key_here
```

Or in Dashboard → Edge Functions → Secrets

### Issue 3: "Lunchflow API error: 401"

**Cause:** Invalid Lunchflow API key

**Fix:**
1. Go to https://lunchflow.app/dashboard
2. Generate a new API key
3. Update the secret in Supabase

### Issue 4: "Unexpected accounts response structure"

**Cause:** Lunchflow API returns different structure than we handle

**Fix:** Check the logs for:
```
Accounts response type: object isArray: false
```

Then share this with me and I'll update the parsing logic.

### Issue 5: Transactions show 0 even though accounts synced

**Cause:** Field name mismatch (accountId vs account_id)

**Fix:** Already fixed in the updated code! Just redeploy.

---

## Quick Checklist

- [ ] Updated `index.ts` with new code
- [ ] Disabled "Verify JWT" in function settings (or using service role key)
- [ ] Deployed function to Supabase
- [ ] Set `LUNCHFLOW_API_KEY` secret
- [ ] Verified Lunchflow account has connected banks
- [ ] Invoked function from dashboard
- [ ] Checked logs for errors
- [ ] Verified data in database tables

---

## Next Steps After Success

Once the sync works:

1. **Set up automated syncing:**
   - Create a cron job in Supabase to run sync every hour/day
   - Or trigger via webhook from Lunchflow

2. **Update Rails sync:**
   - Verify `LunchflowConnection::Syncer` can read the data
   - Test full flow: Lunchflow → Supabase → Rails → Maybe

3. **Monitor sync health:**
   - Check `lunchflow_sync_log` table regularly
   - Set up alerts for failed syncs

4. **Production deployment:**
   - Ensure secrets are set in production
   - Test with production Lunchflow account
   - Document the sync frequency
