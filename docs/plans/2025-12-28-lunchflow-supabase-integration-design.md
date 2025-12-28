# Lunchflow + Supabase Integration Design

**Date:** 2025-12-28
**Status:** Design Approved
**Author:** Claude Code (with user input)

## Overview

This document describes the architecture and implementation plan for integrating Maybe with Lunchflow financial data via Supabase as an intermediary data layer. This enables multiple applications to consume centralized financial data while Maybe maintains its own optimized database for calculations and reporting.

## Goals

1. Enable Maybe to sync financial data (accounts, transactions, balances) from Lunchflow
2. Use Supabase as a centralized data store accessible by multiple applications
3. Support both automatic periodic syncing and manual user-triggered syncs
4. Provide hybrid account mapping to prevent duplicate accounts while maintaining ease of use
5. Follow Maybe's existing architectural patterns (similar to Plaid integration)

## High-Level Architecture

The integration consists of three main components:

### 1. Supabase Data Layer (Central Hub)
- PostgreSQL tables storing normalized Lunchflow data (accounts, transactions, balances)
- Acts as the single source of truth for multiple consuming applications
- Provides real-time capabilities and row-level security for future apps

### 2. Supabase Edge Function (Data Collection)
- Scheduled serverless function (runs every 6 hours, configurable)
- Fetches data from Lunchflow API using stored API key
- Writes/updates Supabase tables with latest financial data
- Handles error logging and retry logic for failed syncs

### 3. Maybe Integration (Data Consumption)
- New `LunchflowConnection` model (similar to `PlaidItem`)
- Links Lunchflow accounts from Supabase to Maybe's `Account` model
- Uses existing `Sync` infrastructure for tracking sync state
- Supports both automatic periodic syncing (via Sidekiq cron) and manual UI triggers
- Hybrid account mapping: auto-create new accounts or map to existing ones

### Data Flow

```
Lunchflow API → Edge Function (scheduled) → Supabase Tables
                                                    ↓
                                              Maybe reads & imports
                                                    ↓
                                              Maybe PostgreSQL
```

This architecture keeps data collection decoupled from consumption, allowing other apps to read from Supabase while Maybe maintains its own optimized database for financial calculations and reporting.

## Supabase Schema Design

The Supabase database mirrors Lunchflow's data structure with four main tables plus sync metadata.

### `lunchflow_accounts` Table

```sql
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
```

### `lunchflow_transactions` Table

```sql
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
```

### `lunchflow_balances` Table

```sql
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

### `lunchflow_sync_log` Table

```sql
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

## Supabase Edge Function Design

The Edge Function handles syncing Lunchflow → Supabase. Written in TypeScript (Deno runtime), it can be triggered by schedule or HTTP request.

### Function Structure

```typescript
// supabase/functions/sync-lunchflow/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  )

  const lunchflowApiKey = Deno.env.get('LUNCHFLOW_API_KEY')
  const baseUrl = 'https://lunchflow.com/api/v1'

  // Main sync flow:
  // 1. Create sync_log record (status: pending)
  // 2. Fetch accounts from Lunchflow API
  // 3. Upsert accounts to lunchflow_accounts table
  // 4. For each account:
  //    - Fetch transactions (with pagination if needed)
  //    - Upsert transactions to lunchflow_transactions table
  //    - Fetch current balance
  //    - Insert balance snapshot to lunchflow_balances table
  // 5. Update sync_log record (status: completed, stats)
  // 6. Return summary response
})
```

### Key Implementation Details

- **Authentication**: Lunchflow API key stored in Supabase secrets (`LUNCHFLOW_API_KEY`)
- **HTTP Client**: Use Deno's native `fetch` to call Lunchflow API
- **Database Access**: Supabase client with service role key for unrestricted access
- **Upsert Strategy**:
  - Accounts: `INSERT ... ON CONFLICT (id) DO UPDATE SET ...`
  - Transactions: `INSERT ... ON CONFLICT (id) DO UPDATE SET ...`
  - Balances: Always insert new snapshot (never update)
- **Error Handling**: Try/catch blocks with detailed error logging to `sync_log.error_message`
- **Rate Limiting**: Add configurable delays between API calls if needed

### Scheduling

**Supabase Cron Job:**
```sql
-- In migration file
SELECT cron.schedule(
  'sync-lunchflow',
  '0 */6 * * *',  -- Every 6 hours
  $$
  SELECT
    net.http_post(
      url:='https://<project-ref>.supabase.co/functions/v1/sync-lunchflow',
      headers:='{"Authorization": "Bearer <anon-key>"}'::jsonb
    );
  $$
);
```

**Manual Trigger:**
- Edge Function accepts HTTP POST requests
- Maybe app can call this endpoint to force an immediate sync
- Protected by API key authentication

The function is idempotent - running it multiple times won't create duplicates, just updates existing records.

## Maybe Integration Design

The Maybe integration follows the existing Plaid pattern with new models connecting to Supabase.

### New Models

#### `LunchflowConnection` Model

```ruby
# app/models/lunchflow_connection.rb
class LunchflowConnection < ApplicationRecord
  include Syncable, Provided

  belongs_to :family
  has_many :lunchflow_accounts, dependent: :destroy
  has_many :accounts, through: :lunchflow_accounts

  validates :name, presence: true

  scope :active, -> { where(status: 'active') }
  scope :ordered, -> { order(created_at: :desc) }

  # Connects to Supabase using stored credentials
  def supabase_client
    @supabase_client ||= SupabaseClient.new(
      url: Rails.application.credentials.supabase.url,
      key: Rails.application.credentials.supabase.key
    )
  end

  # Implements Syncable protocol
  def perform_sync(sync)
    LunchflowConnection::Syncer.new(self).sync
  end

  # Optional: trigger Supabase Edge Function before syncing
  def trigger_supabase_sync
    uri = URI(Rails.application.credentials.supabase.edge_function_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.path)
    request['Authorization'] = "Bearer #{Rails.application.credentials.supabase.anon_key}"

    response = http.request(request)
    response.is_a?(Net::HTTPSuccess)
  end
end
```

#### `LunchflowAccount` Model

```ruby
# app/models/lunchflow_account.rb
class LunchflowAccount < ApplicationRecord
  belongs_to :lunchflow_connection
  belongs_to :account, optional: true # null if not yet mapped

  validates :lunchflow_id, presence: true, uniqueness: true
  validates :name, :institution_name, :provider, :currency, presence: true

  # Auto-creates or returns mapped Maybe account
  def ensure_account!
    return account if account.present?

    create_account!(
      family: lunchflow_connection.family,
      name: "#{institution_name} - #{name}",
      currency: currency,
      accountable: self # polymorphic relation
    )
  end

  # Find potential duplicate accounts
  def potential_duplicates
    Account.where(family: lunchflow_connection.family)
           .where("name ILIKE ?", "%#{institution_name}%")
           .or(Account.where("name ILIKE ?", "%#{name}%"))
  end
end
```

### Database Migrations

```ruby
class CreateLunchflowTables < ActiveRecord::Migration[7.2]
  def change
    create_table :lunchflow_connections do |t|
      t.references :family, null: false, foreign_key: true
      t.string :name, null: false
      t.string :status, default: 'active'
      t.datetime :last_synced_at
      t.timestamps
    end

    create_table :lunchflow_accounts do |t|
      t.references :lunchflow_connection, null: false, foreign_key: true
      t.references :account, null: true, foreign_key: true
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

### Syncer Logic

```ruby
# app/models/lunchflow_connection/syncer.rb
class LunchflowConnection::Syncer
  def initialize(connection)
    @connection = connection
    @supabase = connection.supabase_client
  end

  def sync
    # 1. Fetch accounts from Supabase lunchflow_accounts table
    supabase_accounts = fetch_accounts_from_supabase

    # 2. Upsert LunchflowAccount records
    sync_accounts(supabase_accounts)

    # 3. For each account, sync transactions and balances
    @connection.lunchflow_accounts.each do |lunchflow_account|
      sync_account_data(lunchflow_account)
    end

    # 4. Update last_synced_at
    @connection.update(last_synced_at: Time.current)
  end

  private

  def fetch_accounts_from_supabase
    @supabase.from('lunchflow_accounts')
              .select('*')
              .eq('status', 'ACTIVE')
              .execute
  end

  def sync_accounts(supabase_accounts)
    supabase_accounts.each do |account_data|
      lunchflow_account = @connection.lunchflow_accounts
        .find_or_initialize_by(lunchflow_id: account_data['id'])

      lunchflow_account.update!(
        name: account_data['name'],
        institution_name: account_data['institution_name'],
        institution_logo: account_data['institution_logo'],
        provider: account_data['provider'],
        currency: account_data['currency'],
        status: account_data['status']
      )

      # Auto-create Maybe account if not mapped
      lunchflow_account.ensure_account! if lunchflow_account.account.nil?
    end
  end

  def sync_account_data(lunchflow_account)
    return unless lunchflow_account.account.present?

    # Fetch transactions from Supabase
    transactions = @supabase.from('lunchflow_transactions')
                            .select('*')
                            .eq('account_id', lunchflow_account.lunchflow_id)
                            .order('date', desc: true)
                            .execute

    # Import transactions as Account::Entry records
    transactions.each do |txn|
      import_transaction(lunchflow_account.account, txn)
    end

    # Fetch latest balance from Supabase
    balance = @supabase.from('lunchflow_balances')
                      .select('*')
                      .eq('account_id', lunchflow_account.lunchflow_id)
                      .order('synced_at', desc: true)
                      .limit(1)
                      .single
                      .execute

    # Create Account::Balance record
    import_balance(lunchflow_account.account, balance) if balance
  end

  def import_transaction(account, txn_data)
    # Create or update Account::Entry
    # Map Lunchflow transaction to Maybe's transaction structure
  end

  def import_balance(account, balance_data)
    # Create Account::Balance record
  end
end
```

## Sync Mechanism Design

The hybrid sync approach provides both automatic and manual syncing with a two-phase process.

### Two-Phase Sync Process

**Phase 1: Lunchflow → Supabase**
- Triggered by Supabase Edge Function (automatic cron or manual HTTP call)
- Runs independently of Maybe app
- Maybe can optionally trigger this via HTTP POST to Edge Function endpoint

**Phase 2: Supabase → Maybe**
- Triggered by Maybe app (automatic periodic job or manual UI button)
- Creates a `Sync` record tracking the sync state
- Calls `LunchflowConnection#perform_sync(sync)`

### Automatic Periodic Sync

```yaml
# config/initializers/sidekiq_cron.yml
sync_lunchflow_connections:
  cron: "0 */6 * * *"  # Every 6 hours
  class: SyncLunchflowConnectionsJob
```

```ruby
# app/jobs/sync_lunchflow_connections_job.rb
class SyncLunchflowConnectionsJob < ApplicationJob
  queue_as :default

  def perform
    # Optional: Trigger Supabase Edge Function first
    # Wait a few minutes for it to complete

    LunchflowConnection.active.each do |connection|
      connection.sync_later  # Uses existing Syncable interface
    end
  end
end
```

### Manual Sync from UI

```ruby
# app/controllers/lunchflow_connections_controller.rb
class LunchflowConnectionsController < ApplicationController
  def sync
    @connection = Current.family.lunchflow_connections.find(params[:id])

    # Optional: trigger Supabase Edge Function first
    @connection.trigger_supabase_sync

    # Then sync from Supabase to Maybe
    @connection.sync_later

    redirect_to lunchflow_connections_path,
      notice: "Sync started for #{@connection.name}"
  end
end
```

### Sync Status Tracking

- Uses existing `Sync` model and state machine (pending → syncing → completed/failed)
- UI shows sync progress via Turbo Streams (like Plaid connections)
- Sync history visible in connection settings
- Error messages captured in `Sync#error` field

### Sync Frequency Considerations

- **Supabase Edge Function**: Every 6 hours (fresh data from Lunchflow)
- **Maybe → Supabase**: Every 6-12 hours (or on-demand)
- Can be staggered so Maybe syncs 30 mins after Edge Function completes

This design balances data freshness with API rate limits and system load.

## Account Mapping Design

The hybrid mapping approach provides automatic onboarding with manual override capability to prevent duplicate accounts.

### Default Behavior (Auto-create)

When syncing a new Lunchflow account:
1. Check if `LunchflowAccount#account_id` is null
2. If null, automatically create a new Maybe `Account` record
3. Link via `lunchflow_accounts.account_id`
4. Transactions flow into this auto-created account

### Manual Mapping UI

**Account Settings Page:**
```
Lunchflow Connections
├─ Chase Connection
   ├─ Chase Checking (...1234) → Maybe Account: "Main Checking" [Change]
   ├─ Chase Savings (...5678) → Auto-created [Map to existing account]
   └─ [Sync Now button]
```

**Mapping Modal/Form:**
- Shows unmapped Lunchflow accounts
- Dropdown to select existing Maybe account OR "Create new account"
- Displays warnings if mapping to account already connected to Plaid (potential duplicates)
- Shows potential duplicate suggestions using `LunchflowAccount#potential_duplicates`
- Confirmation step explaining what will happen to existing transactions

### Duplicate Detection Logic

```ruby
# app/models/lunchflow_account.rb
def potential_duplicates
  Account.where(family: lunchflow_connection.family)
         .where("name ILIKE ?", "%#{institution_name}%")
         .or(Account.where("name ILIKE ?", "%#{name}%"))
         .limit(5)
end
```

Shows in UI as suggestions when mapping.

### Remapping Behavior

If user changes mapping from Account A → Account B:
1. Update `lunchflow_accounts.account_id` to new account
2. Move existing transactions to Account B (optional, or leave historical data)
3. Trigger account re-sync for balance recalculation
4. Update UI to reflect new mapping

### Edge Cases Handled

- **Multiple Lunchflow accounts → Same Maybe account**: Allowed (useful for tracking account transfers)
- **Unmapping an account**: Set `account_id` to null, stops syncing transactions
- **Deleting a mapped Maybe account**: Either cascade delete or prevent deletion if has active Lunchflow connection
- **Account status changes**: If Lunchflow account becomes DISCONNECTED/ERROR, update UI and stop syncing

## Security Considerations

1. **API Keys**:
   - Lunchflow API key stored in Supabase secrets (Edge Function)
   - Supabase credentials stored in Rails encrypted credentials

2. **Supabase Access**:
   - Use service role key for Edge Function (full access to sync)
   - Maybe uses regular authenticated key with Row Level Security policies

3. **Data Privacy**:
   - Consider encrypting sensitive fields in Supabase (transaction descriptions, merchant names)
   - Use Supabase RLS to ensure families can only access their own data if sharing Supabase instance

4. **Rate Limiting**:
   - Respect Lunchflow API rate limits in Edge Function
   - Implement exponential backoff for failed requests

## Testing Strategy

### Supabase Edge Function
- Unit tests for data transformation logic
- Integration tests hitting Lunchflow test API
- Mock Supabase client for isolated testing

### Maybe Integration
- Model tests for `LunchflowConnection` and `LunchflowAccount`
- Syncer tests with mocked Supabase client
- System tests for account mapping UI
- Test fixtures for Lunchflow data

### End-to-End Testing
- Manual testing with real Lunchflow test account
- Verify data flows correctly: Lunchflow → Supabase → Maybe
- Test sync failure scenarios and error handling

## Rollout Plan

### Phase 1: Supabase Setup
1. Create Supabase project (if not done)
2. Run migrations to create tables
3. Store Lunchflow API key in Supabase secrets

### Phase 2: Edge Function Development
1. Develop and test Edge Function locally
2. Deploy to Supabase
3. Set up cron schedule
4. Verify data syncing from Lunchflow → Supabase

### Phase 3: Maybe Integration
1. Create migrations for `lunchflow_connections` and `lunchflow_accounts`
2. Implement models and syncer logic
3. Add Supabase credentials to Rails credentials
4. Test Supabase → Maybe sync locally

### Phase 4: UI Development
1. Build Lunchflow connections management UI
2. Implement account mapping interface
3. Add manual sync triggers
4. Display sync status and history

### Phase 5: Background Jobs
1. Set up Sidekiq cron for periodic syncing
2. Test automatic sync flow end-to-end
3. Monitor for errors and performance issues

### Phase 6: Production Deployment
1. Deploy Maybe with Lunchflow integration
2. Monitor sync logs and error rates
3. Gather user feedback
4. Iterate on UI/UX improvements

## Future Enhancements

1. **Real-time Sync**: Use Supabase Realtime to push updates to Maybe instantly
2. **Holdings Support**: Add investment holdings sync from Lunchflow
3. **Multi-tenancy**: Support multiple Lunchflow connections per family
4. **Webhook Support**: Listen for Lunchflow webhooks (if available) for instant updates
5. **Analytics Dashboard**: Visualize sync metrics and data freshness
6. **Smart Duplicate Detection**: Use ML to suggest account mappings automatically

## Conclusion

This design provides a robust, scalable integration between Maybe and Lunchflow via Supabase. It follows Maybe's existing architectural patterns while leveraging Supabase as a centralized data layer for multi-app access. The hybrid sync and mapping approaches balance automation with user control, providing a smooth onboarding experience while preventing duplicate data.
