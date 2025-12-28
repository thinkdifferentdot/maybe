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
