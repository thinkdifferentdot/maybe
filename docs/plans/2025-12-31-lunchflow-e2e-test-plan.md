# Lunchflow Supabase Integration - Manual E2E Test Plan

## Goal
Test the full sync flow: Lunchflow → Supabase Edge Function → Supabase Tables → Rails Syncer → Maybe Accounts/Entries

---

## Prerequisites Check

### 1. Verify Supabase Configuration
Need credentials configured via one of:
- ENV variables: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`
- Settings UI: Settings > Self Hosting > Lunchflow Integration
- Rails credentials

### 2. Verify Lunchflow API Key
The edge function needs `LUNCHFLOW_API_KEY` set in Supabase secrets

---

## E2E Test Steps

### Step 1: Verify Supabase Has Data
Check that the edge function has synced Lunchflow data to Supabase tables:
```bash
# Via Supabase CLI or Dashboard
# Check lunchflow_accounts table has records
# Check lunchflow_transactions table has records
# Check lunchflow_sync_log shows successful syncs
```

### Step 2: Configure Rails Supabase Client
```ruby
# In rails console
# Option A: Set via Settings
Setting.supabase_url = "https://YOUR_PROJECT.supabase.co"
Setting.supabase_key = "YOUR_SERVICE_ROLE_KEY"

# Option B: Verify ENV is set
ENV["SUPABASE_URL"]
ENV["SUPABASE_SERVICE_ROLE_KEY"]
```

### Step 3: Test SupabaseClient Connection
```ruby
# In rails console
client = SupabaseClient.from_settings
accounts = client.from("lunchflow_accounts").select("*").execute
puts "Found #{accounts.count} accounts in Supabase"
```

### Step 4: Create LunchflowConnection Record
```ruby
# In rails console
family = Family.first  # or a specific family
connection = family.lunchflow_connections.create!(name: "Test Connection")
```

### Step 5: Trigger Sync
```ruby
# Option A: Synchronous (for debugging)
sync = connection.syncs.create!
syncer = LunchflowConnection::Syncer.new(connection)
syncer.perform_sync(sync)

# Option B: Background job
connection.sync_later
```

### Step 6: Verify Results
```ruby
# Check LunchflowAccount records created
connection.lunchflow_accounts.count
connection.lunchflow_accounts.pluck(:name, :institution_name)

# Check Maybe Account records created/linked
connection.accounts.count
connection.accounts.pluck(:name, :balance)

# Check Entry/Transaction records created
connection.accounts.each do |account|
  puts "#{account.name}: #{account.entries.count} entries"
end
```

---

## Expected Data Flow

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Lunchflow  │ --> │ Supabase Tables  │ --> │   Maybe Rails   │
│    API      │     │                  │     │                 │
└─────────────┘     └──────────────────┘     └─────────────────┘
                           │                         │
                           ▼                         ▼
                    lunchflow_accounts     LunchflowAccount
                    lunchflow_transactions      ↓
                    lunchflow_balances     Account + Entry
```

### Supabase Tables → Rails Models Mapping
| Supabase Table | Rails Model | Notes |
|----------------|-------------|-------|
| `lunchflow_accounts` | `LunchflowAccount` | Mirrors account metadata |
| `lunchflow_accounts` | `Account` | Created via `ensure_account!` |
| `lunchflow_transactions` | `Entry` + `Transaction` | Uses `plaid_id: "lunchflow_#{id}"` |
| `lunchflow_balances` | `Account.balance` | Updates account balance |

---

## Troubleshooting

### If SupabaseClient.from_settings fails
- Check `Setting.supabase_url` and `Setting.supabase_key` are set
- Check ENV variables are not overriding with blank values

### If Edge Function returns 401
- Verify `LUNCHFLOW_API_KEY` is set in Supabase secrets
- Auth header should be `x-api-key` (not Bearer token)

### If No Data in Supabase
- Invoke edge function manually: `supabase functions invoke sync-lunchflow`
- Check `lunchflow_sync_log` for error messages

### If Syncer Fails
- Check Supabase tables have data: `client.from("lunchflow_accounts").select("*").execute`
- Verify `currency` and `status` are not null (or migration allows null)

---

## Critical Files

| File | Purpose |
|------|---------|
| `app/models/lunchflow_connection.rb` | Connection model with `supabase_client` |
| `app/models/lunchflow_connection/syncer.rb` | Sync logic |
| `app/models/lunchflow_account.rb` | `ensure_account!` creates Maybe Account |
| `app/services/supabase_client.rb` | API client with `from_settings` |
| `supabase/functions/sync-lunchflow/index.ts` | Edge function |

---

## E2E Validation Results (2025-12-31)

### Summary
✅ **Full E2E flow validated successfully**

The complete data pipeline from Lunchflow → Supabase → Maybe Rails has been tested and verified working.

### Test Environment
- Supabase project: `wqtzzoasgwvlxlgmziau.supabase.co`
- Credentials configured via `.env.local`
- Rails environment: development

### Issues Fixed During Testing

#### 1. Gzip Response Encoding
**Problem**: Supabase API returns gzip-compressed responses, causing JSON parse errors in Ruby.

**Solution**: Added `decode_response` method to `SupabaseClient` to handle gzip decompression.

**Files Modified**:
- `app/services/supabase_client.rb`: Added gzip decoding support

#### 2. Edge Function Timeout
**Problem**: `invoke_function("sync-lunchflow")` times out after 30 seconds.

**Status**: Edge function works but takes longer than HTTP client timeout. Syncer works correctly when using existing Supabase data. This is acceptable for now since the edge function runs independently via cron.

### Data Validated

| Component | Result |
|-----------|--------|
| Supabase accounts table | ✅ 5 accounts |
| Supabase transactions table | ✅ 680 transactions |
| Supabase balances table | ✅ 5 balances |
| LunchflowAccount sync | ✅ 2 active accounts synced |
| Maybe Account creation | ✅ 2 accounts created via `ensure_account!` |
| Transaction import | ✅ 680 entries created |
| Balance sync | ✅ Account balances updated |

### Sample Data Flow
```
American Express - SimplyCash Card
- Lunchflow ID: 4133
- Transactions: 6
- Balance: -171.73 CAD

American Express - Gold Rewards Card
- Lunchflow ID: 4132
- Transactions: 674
- Balance: -1843.83 CAD
```

### Tests Passing
- `test/services/supabase_client_test.rb`: 8 tests, 0 failures
- `test/models/lunchflow_connection/syncer_test.rb`: 2 tests, 0 failures

### Remaining Work
- Consider increasing edge function timeout or making it async
- Add retry logic for edge function invocation
- Monitor sync performance with larger datasets
