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

## Configuration

### Option 1: Admin UI (Recommended for Self-Hosted)

1. Navigate to Settings > Self Hosting
2. Scroll to "Lunchflow Integration" section
3. Enter:
   - **Supabase URL**: Your Supabase project URL (e.g., `https://abcdefg.supabase.co`)
   - **Supabase Service Role Key**: From Supabase Dashboard > Settings > API
   - **Lunchflow API Key**: Your Lunchflow API key
4. Each field auto-saves on blur
5. Update Supabase edge function secret:
   ```bash
   supabase secrets set LUNCHFLOW_API_KEY=your_lunchflow_api_key
   ```

### Option 2: Environment Variables (Recommended for Production)

Set environment variables (highest precedence):

```bash
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"
export LUNCHFLOW_API_KEY="your-lunchflow-api-key"
```

### Option 3: Rails Credentials (Legacy)

Edit encrypted credentials:

```bash
rails credentials:edit
```

Add:

```yaml
supabase:
  url: https://your-project.supabase.co
  key: your-service-role-key
```

### Credential Precedence

The system checks credentials in this order:
1. Environment variables (highest priority)
2. Rails credentials
3. Database settings (via admin UI)

## Testing the Integration

1. Create a Lunchflow connection in Maybe
2. Click "Sync Now" to trigger a sync
3. Verify accounts and transactions appear
