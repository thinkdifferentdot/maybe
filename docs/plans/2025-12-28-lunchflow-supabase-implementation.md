# Lunchflow + Supabase Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable Maybe to sync financial data from Lunchflow via Supabase as an intermediary data layer.

**Architecture:** Supabase Edge Function fetches Lunchflow data on a schedule (or on-demand) and stores it in Supabase tables. Maybe reads from these tables via a SupabaseClient, creating/updating LunchflowConnection and LunchflowAccount records that link to Maybe's Account model. Transactions flow through as Entry records.

**Tech Stack:** Ruby on Rails, Supabase (PostgreSQL + Edge Functions), TypeScript/Deno, Sidekiq

**Design Doc:** `docs/plans/2025-12-28-lunchflow-supabase-integration-design.md`

---

## ✅ **Progress Update (2025-12-30)**

### **Completed: Supabase Edge Function (Phase 2)**

The Supabase edge function is now **fully working** and successfully syncing data from Lunchflow:

**What works:**
- ✅ Edge function deployed and tested
- ✅ Correct API endpoints: `https://www.lunchflow.app/api/v1`
- ✅ Correct authentication: `x-api-key` header
- ✅ Proper response parsing for all API responses (accounts, transactions, balances)
- ✅ Field mapping: camelCase (API) → snake_case (DB)
- ✅ Nullable fields: currency and status now optional per actual API schema
- ✅ All 4 Supabase tables created and populated
- ✅ Verified syncing: 5 accounts, 625+ transactions, balances

**Key fixes made:**
1. Base URL: `lunchflow.com` → `www.lunchflow.app`
2. Auth header: `Authorization: Bearer` → `x-api-key`
3. Response structure handling (supports multiple formats)
4. Made `currency` and `status` nullable in DB schema
5. Added SSL certificate fixes to SupabaseClient
6. Enhanced error logging and debugging

**Documentation created:**
- `SUPABASE_VERIFICATION.md` - How to verify sync from CLI/dashboard
- `LUNCHFLOW_API_VERIFICATION.md` - API implementation details
- `FIX_401_ERROR.md` - Authentication troubleshooting
- `APPLY_MIGRATIONS.md` - Migration application guide

**Commit:** `58b1139c` - "feat: implement working Supabase edge function for Lunchflow sync"

### **Next Steps:**

**Immediate (Phase 3-4):**
- [ ] Test Rails sync from Supabase → Maybe (Task 11: LunchflowConnection::Syncer)
- [ ] Verify transactions flow into Maybe Entry records
- [ ] Test full end-to-end flow: Lunchflow → Supabase → Maybe

**Near-term:**
- [ ] Set up automated syncing (cron or webhook)
- [ ] Add admin UI for Supabase settings (LUNCHFLOW_API_KEY, SUPABASE_URL, etc.)
- [ ] Production deployment testing

---

## Phase 1: Supabase Schema Setup

### Task 1: Create Supabase Migration for lunchflow_accounts (COMPLETED)

**Recommended Agent:** Gemini

This task creates the Supabase table to store Lunchflow account data.

**Files:**
- Create: `supabase/migrations/20251228000001_create_lunchflow_accounts.sql`

**Step 1: Create directory and migration file**

Ensure `supabase/migrations` directory exists.

```sql
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
```

**Step 2: Commit**

```bash
git add supabase/migrations/20251228000001_create_lunchflow_accounts.sql
git commit -m "feat(supabase): add lunchflow_accounts table migration"
```

---

### Task 2: Create Supabase Migration for lunchflow_transactions (COMPLETED)

**Recommended Agent:** Gemini

**Files:**
- Create: `supabase/migrations/20251228000002_create_lunchflow_transactions.sql`

**Step 1: Create the migration file**

```sql
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
```

**Step 2: Commit**

```bash
git add supabase/migrations/20251228000002_create_lunchflow_transactions.sql
git commit -m "feat(supabase): add lunchflow_transactions table migration"
```

---

### Task 3: Create Supabase Migration for lunchflow_balances (COMPLETED)

**Recommended Agent:** Gemini

**Files:**
- Create: `supabase/migrations/20251228000003_create_lunchflow_balances.sql`

**Step 1: Create the migration file**

```sql
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
```

**Step 2: Commit**

```bash
git add supabase/migrations/20251228000003_create_lunchflow_balances.sql
git commit -m "feat(supabase): add lunchflow_balances table migration"
```

---

### Task 4: Create Supabase Migration for lunchflow_sync_log (COMPLETED)

**Recommended Agent:** Gemini

**Files:**
- Create: `supabase/migrations/20251228000004_create_lunchflow_sync_log.sql`

**Step 1: Create the migration file**

```sql
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
```

**Step 2: Commit**

```bash
git add supabase/migrations/20251228000004_create_lunchflow_sync_log.sql
git commit -m "feat(supabase): add lunchflow_sync_log table migration"
```

---

## Phase 2: Supabase Edge Function

### Task 5: Create Edge Function Directory Structure (COMPLETED)

**Recommended Agent:** Claude

**Files:**
- Create: `supabase/functions/sync-lunchflow/index.ts`

**Step 1: Create directory and base file**

Ensure `supabase/functions/sync-lunchflow` directory exists.

```typescript
// supabase/functions/sync-lunchflow/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface LunchflowAccount {
  id: number
  name: string
  institution_name: string
  institution_logo: string | null
  provider: string
  currency: string
  status: string
}

interface LunchflowTransaction {
  id: string
  accountId: number
  amount: number
  currency: string
  date: string
  merchant: string | null
  description: string | null
  isPending: boolean
}

interface LunchflowBalance {
  amount: number
  currency: string
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const lunchflowApiKey = Deno.env.get('LUNCHFLOW_API_KEY')
    if (!lunchflowApiKey) {
      throw new Error('LUNCHFLOW_API_KEY not configured')
    }

    const baseUrl = 'https://lunchflow.com/api/v1'
    const headers = {
      'Authorization': `Bearer ${lunchflowApiKey}`,
      'Content-Type': 'application/json'
    }

    // 1. Create sync log record
    const { data: syncLog, error: syncLogError } = await supabase
      .from('lunchflow_sync_log')
      .insert({
        sync_started_at: new Date().toISOString(),
        status: 'pending'
      })
      .select()
      .single()

    if (syncLogError) throw syncLogError

    let accountsSynced = 0
    let transactionsSynced = 0

    try {
      // 2. Fetch accounts from Lunchflow
      const accountsResponse = await fetch(`${baseUrl}/accounts`, { headers })
      if (!accountsResponse.ok) {
        throw new Error(`Lunchflow API error: ${accountsResponse.status}`)
      }
      const accountsData = await accountsResponse.json()
      const accounts: LunchflowAccount[] = accountsData.accounts || []

      // 3. Upsert accounts
      for (const account of accounts) {
        const { error: upsertError } = await supabase
          .from('lunchflow_accounts')
          .upsert({
            id: account.id,
            name: account.name,
            institution_name: account.institution_name,
            institution_logo: account.institution_logo,
            provider: account.provider,
            currency: account.currency,
            status: account.status,
            updated_at: new Date().toISOString()
          }, { onConflict: 'id' })

        if (upsertError) throw upsertError
        accountsSynced++

        // 4. Fetch transactions for each account
        const txnResponse = await fetch(
          `${baseUrl}/accounts/${account.id}/transactions?include_pending=true`,
          { headers }
        )
        if (txnResponse.ok) {
          const txnData = await txnResponse.json()
          const transactions: LunchflowTransaction[] = txnData.transactions || []

          for (const txn of transactions) {
            const { error: txnError } = await supabase
              .from('lunchflow_transactions')
              .upsert({
                id: txn.id,
                account_id: txn.accountId,
                amount: txn.amount,
                currency: txn.currency,
                date: txn.date,
                merchant: txn.merchant,
                description: txn.description,
                is_pending: txn.isPending,
                updated_at: new Date().toISOString()
              }, { onConflict: 'id' })

            if (txnError) throw txnError
            transactionsSynced++
          }
        }

        // 5. Fetch balance for each account
        const balanceResponse = await fetch(
          `${baseUrl}/accounts/${account.id}/balance`,
          { headers }
        )
        if (balanceResponse.ok) {
          const balanceData = await balanceResponse.json()
          const balance: LunchflowBalance = balanceData.balance

          const { error: balanceError } = await supabase
            .from('lunchflow_balances')
            .insert({
              account_id: account.id,
              amount: balance.amount,
              currency: balance.currency,
              synced_at: new Date().toISOString()
            })

          if (balanceError) throw balanceError
        }
      }

      // 6. Update sync log as completed
      await supabase
        .from('lunchflow_sync_log')
        .update({
          sync_completed_at: new Date().toISOString(),
          status: 'completed',
          accounts_synced: accountsSynced,
          transactions_synced: transactionsSynced
        })
        .eq('id', syncLog.id)

      return new Response(
        JSON.stringify({
          success: true,
          accounts_synced: accountsSynced,
          transactions_synced: transactionsSynced
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )

    } catch (syncError) {
      // Update sync log as failed
      await supabase
        .from('lunchflow_sync_log')
        .update({
          sync_completed_at: new Date().toISOString(),
          status: 'failed',
          error_message: syncError.message,
          accounts_synced: accountsSynced,
          transactions_synced: transactionsSynced
        })
        .eq('id', syncLog.id)

      throw syncError
    }

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
```

**Step 2: Commit**

```bash
git add supabase/functions/sync-lunchflow/index.ts
git commit -m "feat(supabase): add sync-lunchflow edge function"
```

---

## Phase 3: Maybe Rails Migrations

### Task 6: Create Migration for lunchflow_connections Table

**Recommended Agent:** Claude

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_create_lunchflow_connections.rb`

**Step 1: Generate the migration**

Run: `bin/rails generate migration CreateLunchflowConnections`

**Step 2: Write the migration**

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_lunchflow_connections.rb
class CreateLunchflowConnections < ActiveRecord::Migration[7.2]
  def change
    create_table :lunchflow_connections, id: :uuid do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :status, default: 'active', null: false
      t.datetime :last_synced_at
      t.timestamps
    end
  end
end
```

**Step 3: Run migration**

Run: `bin/rails db:migrate`
Expected: Migration completes successfully

**Step 4: Verify table exists**

Run: `bin/rails runner "puts LunchflowConnection.table_name"`
Expected: `lunchflow_connections`

**Step 5: Commit**

```bash
git add db/migrate/*_create_lunchflow_connections.rb db/schema.rb
git commit -m "feat: add lunchflow_connections table"
```

---

### Task 7: Create Migration for lunchflow_accounts Table

**Recommended Agent:** Claude

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_create_lunchflow_accounts.rb`

**Step 1: Generate the migration**

Run: `bin/rails generate migration CreateLunchflowAccounts`

**Step 2: Write the migration**

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_lunchflow_accounts.rb
class CreateLunchflowAccounts < ActiveRecord::Migration[7.2]
  def change
    create_table :lunchflow_accounts, id: :uuid do |t|
      t.references :lunchflow_connection, null: false, foreign_key: true, type: :uuid
      t.references :account, null: true, foreign_key: true, type: :uuid
      t.bigint :lunchflow_id, null: false
      t.string :name, null: false
      t.string :institution_name, null: false
      t.string :institution_logo
      t.string :provider, null: false
      t.string :currency, null: false
      t.string :status, null: false
      t.timestamps

      t.index :lunchflow_id, unique: true
    end
  end
end
```

**Step 3: Run migration**

Run: `bin/rails db:migrate`
Expected: Migration completes successfully

**Step 4: Commit**

```bash
git add db/migrate/*_create_lunchflow_accounts.rb db/schema.rb
git commit -m "feat: add lunchflow_accounts table"
```

---

## Phase 4: Maybe Models

### Task 8: Create SupabaseClient Service

**Recommended Agent:** Claude

**Files:**
- Create: `app/services/supabase_client.rb`
- Test: `test/services/supabase_client_test.rb`

**Step 1: Write the failing test**

```ruby
# test/services/supabase_client_test.rb
require "test_helper"

class SupabaseClientTest < ActiveSupport::TestCase
  setup do
    @client = SupabaseClient.new(
      url: "https://test.supabase.co",
      key: "test-key"
    )
  end

  test "initializes with url and key" do
    assert_equal "https://test.supabase.co", @client.url
  end

  test "builds correct headers" do
    headers = @client.send(:headers)
    assert_equal "Bearer test-key", headers["Authorization"]
    assert_equal "test-key", headers["apikey"]
  end

  test "from method queries table with filters" do
    # This tests the query builder interface
    query = @client.from("lunchflow_accounts")
    assert_kind_of SupabaseClient::QueryBuilder, query
  end

  test "invoke_function calls edge function" do
    stub_request(:post, "https://test.supabase.co/functions/v1/test-func")
      .with(headers: { "Authorization" => "Bearer test-key" })
      .to_return(status: 200, body: '{"success":true}', headers: {})

    response = @client.invoke_function("test-func")
    assert response["success"]
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rails test test/services/supabase_client_test.rb -v`
Expected: FAIL with "uninitialized constant SupabaseClient"

**Step 3: Write minimal implementation**

```ruby
# app/services/supabase_client.rb
class SupabaseClient
  attr_reader :url

  def initialize(url:, key:)
    @url = url
    @key = key
  end

  def from(table_name)
    QueryBuilder.new(self, table_name)
  end

  def invoke_function(function_name, body = {})
    uri = URI("#{@url}/functions/v1/#{function_name}")
    request = Net::HTTP::Post.new(uri)
    headers.each { |k, v| request[k] = v }
    request.body = body.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    raise "Supabase function error: #{response.code}" unless response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body)
  end

  def execute_query(path, params = {})
    uri = URI("#{@url}/rest/v1/#{path}")
    uri.query = URI.encode_www_form(params) if params.any?

    request = Net::HTTP::Get.new(uri)
    headers.each { |k, v| request[k] = v }

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    raise "Supabase error: #{response.code}" unless response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body)
  end

  class QueryBuilder
    def initialize(client, table_name)
      @client = client
      @table_name = table_name
      @filters = {}
      @select_columns = "*"
      @order_column = nil
      @order_direction = nil
      @limit_value = nil
      @single_record = false
    end

    def select(columns)
      @select_columns = columns
      self
    end

    def eq(column, value)
      @filters["#{column}"] = "eq.#{value}"
      self
    end

    def order(column, ascending: true)
      @order_column = column
      @order_direction = ascending ? "asc" : "desc"
      self
    end

    def limit(count)
      @limit_value = count
      self
    end

    def single
      @single_record = true
      @limit_value = 1
      self
    end

    def execute
      params = { select: @select_columns }
      @filters.each { |k, v| params[k] = v }
      params[:order] = "#{@order_column}.#{@order_direction}" if @order_column
      params[:limit] = @limit_value if @limit_value

      result = @client.execute_query(@table_name, params)
      @single_record ? result.first : result
    end
  end

  private

  def headers
    {
      "Authorization" => "Bearer #{@key}",
      "apikey" => @key,
      "Content-Type" => "application/json"
    }
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bin/rails test test/services/supabase_client_test.rb -v`
Expected: PASS

**Step 5: Commit**

```bash
git add app/services/supabase_client.rb test/services/supabase_client_test.rb
git commit -m "feat: add SupabaseClient service for API communication"
```

---

### Task 9: Create LunchflowConnection Model

**Recommended Agent:** Claude

**Files:**
- Create: `app/models/lunchflow_connection.rb`
- Test: `test/models/lunchflow_connection_test.rb`
- Create: `test/fixtures/lunchflow_connections.yml`

**Step 1: Write the failing test**

```ruby
# test/models/lunchflow_connection_test.rb
require "test_helper"

class LunchflowConnectionTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
  end

  test "belongs to family" do
    connection = LunchflowConnection.new(
      family: @family,
      name: "Test Connection"
    )
    assert connection.valid?
    assert_equal @family, connection.family
  end

  test "requires name" do
    connection = LunchflowConnection.new(family: @family)
    assert_not connection.valid?
    assert_includes connection.errors[:name], "can't be blank"
  end

  test "has default active status" do
    connection = LunchflowConnection.create!(
      family: @family,
      name: "Test Connection"
    )
    assert_equal "active", connection.status
  end

  test "active scope returns only active connections" do
    active = LunchflowConnection.create!(family: @family, name: "Active", status: "active")
    inactive = LunchflowConnection.create!(family: @family, name: "Inactive", status: "inactive")

    assert_includes LunchflowConnection.active, active
    assert_not_includes LunchflowConnection.active, inactive
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/lunchflow_connection_test.rb -v`
Expected: FAIL with "uninitialized constant LunchflowConnection"

**Step 3: Create fixtures**

```yaml
# test/fixtures/lunchflow_connections.yml
dylan_lunchflow:
  family: dylan_family
  name: Dylan Lunchflow Connection
  status: active
```

**Step 4: Write minimal implementation**

```ruby
# app/models/lunchflow_connection.rb
class LunchflowConnection < ApplicationRecord
  include Syncable

  belongs_to :family
  has_many :lunchflow_accounts, dependent: :destroy
  has_many :accounts, through: :lunchflow_accounts

  validates :name, presence: true

  scope :active, -> { where(status: "active") }
  scope :ordered, -> { order(created_at: :desc) }

  def supabase_client
    @supabase_client ||= SupabaseClient.new(
      url: Rails.application.credentials.dig(:supabase, :url),
      key: Rails.application.credentials.dig(:supabase, :key)
    )
  end
end
```

**Step 5: Run test to verify it passes**

Run: `bin/rails test test/models/lunchflow_connection_test.rb -v`
Expected: PASS

**Step 6: Commit**

```bash
git add app/models/lunchflow_connection.rb test/models/lunchflow_connection_test.rb test/fixtures/lunchflow_connections.yml
git commit -m "feat: add LunchflowConnection model with Syncable concern"
```

---

### Task 10: Create LunchflowAccount Model

**Recommended Agent:** Claude

**Files:**
- Create: `app/models/lunchflow_account.rb`
- Test: `test/models/lunchflow_account_test.rb`
- Create: `test/fixtures/lunchflow_accounts.yml`

**Step 1: Write the failing test**

```ruby
# test/models/lunchflow_account_test.rb
require "test_helper"

class LunchflowAccountTest < ActiveSupport::TestCase
  setup do
    @connection = lunchflow_connections(:dylan_lunchflow)
  end

  test "belongs to lunchflow_connection" do
    account = LunchflowAccount.new(
      lunchflow_connection: @connection,
      lunchflow_id: 123,
      name: "Checking",
      institution_name: "Chase",
      provider: "plaid",
      currency: "USD",
      status: "ACTIVE"
    )
    assert account.valid?
  end

  test "requires lunchflow_id to be unique" do
    LunchflowAccount.create!(
      lunchflow_connection: @connection,
      lunchflow_id: 123,
      name: "Checking",
      institution_name: "Chase",
      provider: "plaid",
      currency: "USD",
      status: "ACTIVE"
    )

    duplicate = LunchflowAccount.new(
      lunchflow_connection: @connection,
      lunchflow_id: 123,
      name: "Savings",
      institution_name: "Chase",
      provider: "plaid",
      currency: "USD",
      status: "ACTIVE"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:lunchflow_id], "has already been taken"
  end

  test "account association is optional" do
    account = LunchflowAccount.new(
      lunchflow_connection: @connection,
      lunchflow_id: 456,
      name: "Savings",
      institution_name: "Chase",
      provider: "plaid",
      currency: "USD",
      status: "ACTIVE",
      account: nil
    )
    assert account.valid?
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/lunchflow_account_test.rb -v`
Expected: FAIL

**Step 3: Create fixtures**

```yaml
# test/fixtures/lunchflow_accounts.yml
dylan_checking:
  lunchflow_connection: dylan_lunchflow
  lunchflow_id: 12345
  name: Checking Account
  institution_name: Chase Bank
  provider: gocardless
  currency: USD
  status: ACTIVE
```

**Step 4: Write minimal implementation**

```ruby
# app/models/lunchflow_account.rb
class LunchflowAccount < ApplicationRecord
  belongs_to :lunchflow_connection
  belongs_to :account, optional: true

  validates :lunchflow_id, presence: true, uniqueness: true
  validates :name, :institution_name, :provider, :currency, :status, presence: true

  def ensure_account!
    return account if account.present?

    new_account = Account.create!(
      family: lunchflow_connection.family,
      name: "#{institution_name} - #{name}",
      currency: currency,
      balance: 0,
      accountable: Depository.new
    )

    update!(account: new_account)
    new_account
  end

  def potential_duplicates
    Account.where(family: lunchflow_connection.family)
           .where("name ILIKE ? OR name ILIKE ?", "%#{institution_name}%", "%#{name}%")
           .limit(5)
  end
end
```

**Step 5: Run test to verify it passes**

Run: `bin/rails test test/models/lunchflow_account_test.rb -v`
Expected: PASS

**Step 6: Commit**

```bash
git add app/models/lunchflow_account.rb test/models/lunchflow_account_test.rb test/fixtures/lunchflow_accounts.yml
git commit -m "feat: add LunchflowAccount model with account mapping"
```

---

### Task 11: Create LunchflowConnection::Syncer

**Recommended Agent:** Claude

**Files:**
- Create: `app/models/lunchflow_connection/syncer.rb`
- Test: `test/models/lunchflow_connection/syncer_test.rb`

**Step 1: Write the failing test**

```ruby
# test/models/lunchflow_connection/syncer_test.rb
require "test_helper"

class LunchflowConnection::SyncerTest < ActiveSupport::TestCase
  setup do
    @connection = lunchflow_connections(:dylan_lunchflow)
    @syncer = LunchflowConnection::Syncer.new(@connection)
  end

  test "initializes with connection" do
    assert_equal @connection, @syncer.instance_variable_get(:@connection)
  end

  test "perform_sync invokes edge function, fetches accounts and creates lunchflow_accounts" do
    mock_client = Minitest::Mock.new
    mock_query = Minitest::Mock.new

    # Expect edge function trigger
    mock_client.expect(:invoke_function, { "success" => true }, ["sync-lunchflow"])

    # Mock the supabase client chain
    mock_query.expect(:select, mock_query, ["*"])
    mock_query.expect(:eq, mock_query, ["status", "ACTIVE"])
    mock_query.expect(:execute, [
      {
        "id" => 999,
        "name" => "Test Checking",
        "institution_name" => "Test Bank",
        "institution_logo" => nil,
        "provider" => "gocardless",
        "currency" => "USD",
        "status" => "ACTIVE"
      }
    ])

    mock_client.expect(:from, mock_query, ["lunchflow_accounts"])

    # Mock transactions query (return empty)
    txn_query = Minitest::Mock.new
    txn_query.expect(:select, txn_query, ["*"])
    txn_query.expect(:eq, txn_query, ["account_id", 999])
    txn_query.expect(:order, txn_query, ["date"])
    txn_query.expect(:execute, [])
    mock_client.expect(:from, txn_query, ["lunchflow_transactions"])

    # Mock balance query
    bal_query = Minitest::Mock.new
    bal_query.expect(:select, bal_query, ["*"])
    bal_query.expect(:eq, bal_query, ["account_id", 999])
    bal_query.expect(:order, bal_query, ["synced_at"])
    bal_query.expect(:limit, bal_query, [1])
    bal_query.expect(:single, bal_query)
    bal_query.expect(:execute, nil)
    mock_client.expect(:from, bal_query, ["lunchflow_balances"])

    @connection.stub(:supabase_client, mock_client) do
      sync = @connection.syncs.create!
      @syncer.perform_sync(sync)
    end

    lunchflow_account = @connection.lunchflow_accounts.find_by(lunchflow_id: 999)
    assert_not_nil lunchflow_account
    assert_equal "Test Checking", lunchflow_account.name
    mock_client.verify
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/lunchflow_connection/syncer_test.rb -v`
Expected: FAIL

**Step 3: Write minimal implementation**

```ruby
# app/models/lunchflow_connection/syncer.rb
class LunchflowConnection::Syncer
  def initialize(connection)
    @connection = connection
  end

  def perform_sync(sync)
    # Trigger remote sync to ensure fresh data in Supabase
    @connection.supabase_client.invoke_function("sync-lunchflow")

    supabase_accounts = fetch_accounts_from_supabase
    sync_accounts(supabase_accounts)

    @connection.lunchflow_accounts.each do |lunchflow_account|
      sync_account_data(lunchflow_account)
    end

    @connection.update!(last_synced_at: Time.current)
  end

  def perform_post_sync
    # no-op for now
  end

  private

  def fetch_accounts_from_supabase
    @connection.supabase_client
               .from("lunchflow_accounts")
               .select("*")
               .eq("status", "ACTIVE")
               .execute
  end

  def sync_accounts(supabase_accounts)
    supabase_accounts.each do |account_data|
      lunchflow_account = @connection.lunchflow_accounts
        .find_or_initialize_by(lunchflow_id: account_data["id"])

      lunchflow_account.update!(
        name: account_data["name"],
        institution_name: account_data["institution_name"],
        institution_logo: account_data["institution_logo"],
        provider: account_data["provider"],
        currency: account_data["currency"],
        status: account_data["status"]
      )

      # Auto-create Maybe account if not mapped
      lunchflow_account.ensure_account! if lunchflow_account.account.nil?
    end
  end

  def sync_account_data(lunchflow_account)
    return unless lunchflow_account.account.present?

    sync_transactions(lunchflow_account)
    sync_balance(lunchflow_account)
  end

  def sync_transactions(lunchflow_account)
    transactions = @connection.supabase_client
                              .from("lunchflow_transactions")
                              .select("*")
                              .eq("account_id", lunchflow_account.lunchflow_id)
                              .order("date")
                              .execute

    transactions.each do |txn_data|
      # NOTE: We currently treat pending transactions as posted.
      # Future improvement: Use txn_data['is_pending'] to handle pending state.
      import_transaction(lunchflow_account.account, txn_data)
    end
  end

  def sync_balance(lunchflow_account)
    balance = @connection.supabase_client
                        .from("lunchflow_balances")
                        .select("*")
                        .eq("account_id", lunchflow_account.lunchflow_id)
                        .order("synced_at")
                        .limit(1)
                        .single
                        .execute

    import_balance(lunchflow_account.account, balance) if balance
  end

  def import_transaction(account, txn_data)
    entry = account.entries.find_or_initialize_by(
      plaid_id: "lunchflow_#{txn_data['id']}"
    ) do |e|
      e.entryable = Transaction.new
    end

    entry.assign_attributes(
      amount: txn_data["amount"],
      currency: txn_data["currency"],
      date: txn_data["date"]
    )

    # Use enrich_attribute for name to allow user overrides
    entry.enrich_attribute(
      :name,
      txn_data["merchant"] || txn_data["description"] || "Lunchflow Transaction",
      source: "lunchflow"
    )

    entry.save!
  end

  def import_balance(account, balance_data)
    # Update account balance
    account.update!(balance: balance_data["amount"])
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bin/rails test test/models/lunchflow_connection/syncer_test.rb -v`
Expected: PASS

**Step 5: Commit**

```bash
git add app/models/lunchflow_connection/syncer.rb test/models/lunchflow_connection/syncer_test.rb
git commit -m "feat: add LunchflowConnection::Syncer for sync logic"
```

---

### Task 12: Create LunchflowConnection::SyncCompleteEvent

**Recommended Agent:** Claude

**Files:**
- Create: `app/models/lunchflow_connection/sync_complete_event.rb`

**Step 1: Write the implementation**

```ruby
# app/models/lunchflow_connection/sync_complete_event.rb
class LunchflowConnection::SyncCompleteEvent
  attr_reader :lunchflow_connection

  def initialize(lunchflow_connection)
    @lunchflow_connection = lunchflow_connection
  end

  def broadcast
    lunchflow_connection.accounts.each do |account|
      account.broadcast_sync_complete
    end

    lunchflow_connection.family.broadcast_sync_complete
  end
end
```

**Step 2: Commit**

```bash
git add app/models/lunchflow_connection/sync_complete_event.rb
git commit -m "feat: add LunchflowConnection::SyncCompleteEvent for broadcast"
```

---

## Phase 5: Background Jobs

### Task 13: Create SyncLunchflowConnectionsJob (COMPLETED)

**Recommended Agent:** Claude

**Files:**
- Create: `app/jobs/sync_lunchflow_connections_job.rb`
- Test: `test/jobs/sync_lunchflow_connections_job_test.rb`

**Step 1: Write the failing test**

```ruby
# test/jobs/sync_lunchflow_connections_job_test.rb
require "test_helper"

class SyncLunchflowConnectionsJobTest < ActiveJob::TestCase
  test "syncs all active lunchflow connections" do
    connection = lunchflow_connections(:dylan_lunchflow)

    # Stub the sync_later method
    LunchflowConnection.any_instance.expects(:sync_later).once

    SyncLunchflowConnectionsJob.perform_now
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rails test test/jobs/sync_lunchflow_connections_job_test.rb -v`
Expected: FAIL

**Step 3: Write minimal implementation**

```ruby
# app/jobs/sync_lunchflow_connections_job.rb
class SyncLunchflowConnectionsJob < ApplicationJob
  queue_as :default

  def perform
    LunchflowConnection.active.find_each do |connection|
      connection.sync_later
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bin/rails test test/jobs/sync_lunchflow_connections_job_test.rb -v`
Expected: PASS

**Step 5: Commit**

```bash
git add app/jobs/sync_lunchflow_connections_job.rb test/jobs/sync_lunchflow_connections_job_test.rb
git commit -m "feat: add SyncLunchflowConnectionsJob for periodic syncing"
```

---

### Task 14: Add Sidekiq Cron Schedule (COMPLETED)

**Recommended Agent:** Claude

**Files:**
- Modify: `config/schedule.yml` (or create if using sidekiq-cron)

**Step 1: Check if schedule file exists and add configuration**

If using sidekiq-cron, add to initializer:

```ruby
# config/initializers/sidekiq.rb (add to existing file)

Sidekiq.configure_server do |config|
  # ... existing config ...

  config.on(:startup) do
    schedule = [
      {
        "name" => "sync_lunchflow_connections",
        "cron" => "0 */6 * * *", # Every 6 hours
        "class" => "SyncLunchflowConnectionsJob"
      }
    ]

    Sidekiq::Cron::Job.load_from_array(schedule)
  end
end
```

**Step 2: Commit**

```bash
git add config/initializers/sidekiq.rb
git commit -m "feat: add cron schedule for Lunchflow sync job"
```

---

## Phase 6: Controller and Routes

### Task 15: Create LunchflowConnectionsController

**Recommended Agent:** Claude

**Files:**
- Create: `app/controllers/lunchflow_connections_controller.rb`
- Test: `test/controllers/lunchflow_connections_controller_test.rb`

**Step 1: Write the failing test**

```ruby
# test/controllers/lunchflow_connections_controller_test.rb
require "test_helper"

class LunchflowConnectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
    @connection = lunchflow_connections(:dylan_lunchflow)
  end

  test "should get index" do
    get lunchflow_connections_url
    assert_response :success
  end

  test "should get new" do
    get new_lunchflow_connection_url
    assert_response :success
  end

  test "should create lunchflow_connection" do
    assert_difference("LunchflowConnection.count") do
      post lunchflow_connections_url, params: {
        lunchflow_connection: { name: "New Connection" }
      }
    end

    assert_redirected_to lunchflow_connections_url
  end

  test "should sync connection" do
    LunchflowConnection.any_instance.expects(:sync_later).once

    post sync_lunchflow_connection_url(@connection)
    assert_redirected_to lunchflow_connections_url
  end

  test "should destroy connection" do
    assert_difference("LunchflowConnection.count", -1) do
      delete lunchflow_connection_url(@connection)
    end

    assert_redirected_to lunchflow_connections_url
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/lunchflow_connections_controller_test.rb -v`
Expected: FAIL

**Step 3: Write minimal implementation**

```ruby
# app/controllers/lunchflow_connections_controller.rb
class LunchflowConnectionsController < ApplicationController
  before_action :set_connection, only: [:show, :edit, :update, :destroy, :sync]

  def index
    @connections = Current.family.lunchflow_connections.ordered
  end

  def show
  end

  def new
    @connection = LunchflowConnection.new
  end

  def create
    @connection = Current.family.lunchflow_connections.build(connection_params)

    if @connection.save
      redirect_to lunchflow_connections_path, notice: "Connection created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @connection.update(connection_params)
      redirect_to lunchflow_connections_path, notice: "Connection updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @connection.destroy
    redirect_to lunchflow_connections_path, notice: "Connection deleted."
  end

  def sync
    @connection.sync_later
    redirect_to lunchflow_connections_path, notice: "Sync started for #{@connection.name}"
  end

  private

  def set_connection
    @connection = Current.family.lunchflow_connections.find(params[:id])
  end

  def connection_params
    params.require(:lunchflow_connection).permit(:name)
  end
end
```

**Step 4: Add routes**

```ruby
# config/routes.rb (add to existing routes)
resources :lunchflow_connections do
  member do
    post :sync
  end
end
```

**Step 5: Run test to verify it passes**

Run: `bin/rails test test/controllers/lunchflow_connections_controller_test.rb -v`
Expected: PASS

**Step 6: Commit**

```bash
git add app/controllers/lunchflow_connections_controller.rb test/controllers/lunchflow_connections_controller_test.rb config/routes.rb
git commit -m "feat: add LunchflowConnectionsController with CRUD and sync"
```

---

## Phase 7: Views

### Task 16: Create Lunchflow Connection Views

**Recommended Agent:** Claude

**Files:**
- Create: `app/views/lunchflow_connections/index.html.erb`
- Create: `app/views/lunchflow_connections/new.html.erb`
- Create: `app/views/lunchflow_connections/_form.html.erb`
- Create: `app/views/lunchflow_connections/_connection.html.erb`

**Step 1: Create index view**

```erb
<%# app/views/lunchflow_connections/index.html.erb %>
<div class="space-y-4">
  <div class="flex justify-between items-center">
    <h1 class="text-xl font-semibold text-primary">Lunchflow Connections</h1>
    <%= link_to "Add Connection", new_lunchflow_connection_path, class: "btn btn--primary" %>
  </div>

  <% if @connections.any? %>
    <div class="space-y-2">
      <% @connections.each do |connection| %>
        <%= render partial: "connection", locals: { connection: connection } %>
      <% end %>
    </div>
  <% else %>
    <div class="text-center py-8 text-secondary">
      <p>No Lunchflow connections yet.</p>
      <p class="mt-2">
        <%= link_to "Add your first connection", new_lunchflow_connection_path, class: "text-primary underline" %>
      </p>
    </div>
  <% end %>
</div>
```

**Step 2: Create connection partial**

```erb
<%# app/views/lunchflow_connections/_connection.html.erb %>
<div id="<%= dom_id(connection) %>" class="bg-container border border-primary rounded-lg p-4">
  <div class="flex justify-between items-start">
    <div>
      <h3 class="font-medium text-primary"><%= connection.name %></h3>
      <p class="text-sm text-secondary">
        Status: <%= connection.status %>
        <% if connection.last_synced_at %>
          | Last synced: <%= time_ago_in_words(connection.last_synced_at) %> ago
        <% end %>
      </p>
      <p class="text-sm text-secondary mt-1">
        <%= connection.lunchflow_accounts.count %> accounts linked
      </p>
    </div>
    <div class="flex gap-2">
      <%= button_to "Sync Now", sync_lunchflow_connection_path(connection),
          method: :post, class: "btn btn--secondary btn--sm" %>
      <%= link_to "Edit", edit_lunchflow_connection_path(connection),
          class: "btn btn--secondary btn--sm" %>
      <%= button_to "Delete", lunchflow_connection_path(connection),
          method: :delete,
          data: { confirm: "Are you sure?" },
          class: "btn btn--danger btn--sm" %>
    </div>
  </div>

  <% if connection.lunchflow_accounts.any? %>
    <div class="mt-4 space-y-2">
      <% connection.lunchflow_accounts.each do |lf_account| %>
        <div class="flex justify-between items-center py-2 border-t border-secondary">
          <div>
            <span class="font-medium"><%= lf_account.name %></span>
            <span class="text-secondary text-sm">(<%= lf_account.institution_name %>)</span>
          </div>
          <div class="text-sm">
            <% if lf_account.account %>
              Mapped to: <%= lf_account.account.name %>
            <% else %>
              <span class="text-warning">Not mapped</span>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
  <% end %>
</div>
```

**Step 3: Create new view**

```erb
<%# app/views/lunchflow_connections/new.html.erb %>
<div class="max-w-lg mx-auto">
  <h1 class="text-xl font-semibold text-primary mb-4">Add Lunchflow Connection</h1>
  <%= render "form", connection: @connection %>
</div>
```

**Step 4: Create form partial**

```erb
<%# app/views/lunchflow_connections/_form.html.erb %>
<%= form_with model: connection, class: "space-y-4" do |f| %>
  <% if connection.errors.any? %>
    <div class="bg-danger/10 border border-danger rounded p-3">
      <ul class="list-disc list-inside">
        <% connection.errors.full_messages.each do |message| %>
          <li><%= message %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div>
    <%= f.label :name, class: "block text-sm font-medium text-primary mb-1" %>
    <%= f.text_field :name, class: "input w-full", placeholder: "My Lunchflow Connection" %>
  </div>

  <div class="flex gap-2">
    <%= f.submit class: "btn btn--primary" %>
    <%= link_to "Cancel", lunchflow_connections_path, class: "btn btn--secondary" %>
  </div>
<% end %>
```

**Step 5: Commit**

```bash
git add app/views/lunchflow_connections/
git commit -m "feat: add Lunchflow connection views"
```

---

## Phase 8: Credentials Setup

### Task 17: Document Supabase Credentials Setup

**Recommended Agent:** Gemini

**Files:**
- Create: `docs/lunchflow-setup.md`

**Step 1: Create setup documentation**

```markdown
# Lunchflow + Supabase Integration Setup

## Prerequisites

1. A Supabase project
2. A Lunchflow API key

## Supabase Setup

### 1. Run Migrations

Deploy the migrations in `supabase/migrations/` to your Supabase project:

```bash
supabase db push
```

### 2. Deploy Edge Function

```bash
supabase functions deploy sync-lunchflow
```

### 3. Configure Secrets

Set your Lunchflow API key as a secret:

```bash
supabase secrets set LUNCHFLOW_API_KEY=your-api-key-here
```

### 4. Set Up Cron (Optional)

To run the Edge Function on a schedule, enable pg_cron and add:

```sql
SELECT cron.schedule(
  'sync-lunchflow',
  '0 */6 * * *',
  $$
  SELECT net.http_post(
    url:='https://YOUR_PROJECT.supabase.co/functions/v1/sync-lunchflow',
    headers:='{"Authorization": "Bearer YOUR_ANON_KEY"}'::jsonb
  );
  $$
);
```

## Rails Credentials Setup

Add Supabase credentials to your Rails encrypted credentials:

```bash
bin/rails credentials:edit
```

Add:

```yaml
supabase:
  url: https://YOUR_PROJECT.supabase.co
  key: YOUR_SERVICE_ROLE_KEY
  anon_key: YOUR_ANON_KEY
  edge_function_url: https://YOUR_PROJECT.supabase.co/functions/v1/sync-lunchflow
```

## Testing the Integration

1. Create a Lunchflow connection in Maybe
2. Click "Sync Now" to trigger a sync
3. Verify accounts and transactions appear
```

**Step 2: Commit**

```bash
git add docs/lunchflow-setup.md
git commit -m "docs: add Lunchflow + Supabase setup guide"
```

---

## Final Steps

### Task 18: Run Full Test Suite

**Step 1: Run all tests**

Run: `bin/rails test`
Expected: All tests pass (with pre-existing errors still present)

**Step 2: Run linting**

Run: `bin/rubocop -a`
Expected: No new offenses

---

### Task 19: Create Final Commit

**Step 1: Review changes**

Run: `git status && git diff --stat main`

**Step 2: Push branch**

Run: `git push -u origin feature/lunchflow-supabase-integration`

---

## Summary

This implementation plan covers:

1. **Supabase Schema** (Tasks 1-4): Four tables for accounts, transactions, balances, and sync logs
2. **Edge Function** (Task 5): TypeScript function to sync Lunchflow → Supabase
3. **Rails Migrations** (Tasks 6-7): Two tables for connections and accounts
4. **Models** (Tasks 8-12): SupabaseClient, LunchflowConnection, LunchflowAccount, Syncer
5. **Background Jobs** (Tasks 13-14): Periodic sync job with cron schedule
6. **Controller/Routes** (Task 15): Full CRUD + sync endpoint
7. **Views** (Task 16): Index, new, form, and connection partial
8. **Documentation** (Task 17): Setup guide

Total: 19 tasks, approximately 2-3 hours of implementation time.
