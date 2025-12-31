# Lunchflow API Implementation Verification

## API Documentation Summary

Based on https://docs.lunchflow.app/api-reference/introduction

### Base URL
```
https://lunchflow.com/api/v1
```

### Authentication
```
Authorization: Bearer YOUR_API_KEY
```

### Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/accounts` | GET | List all connected bank accounts |
| `/accounts/:accountId/transactions` | GET | Get transactions for a specific account |
| `/accounts/:accountId/balance` | GET | Get the balance for a specific account |
| `/accounts/:accountId/holdings` | GET | Get investment holdings (brokerage only) |

### Query Parameters
- `include_pending=true` on transactions endpoint to include pending transactions

---

## Current Implementation Analysis

### ✅ What Matches the Docs

1. **Base URL**: `https://lunchflow.com/api/v1` ✓
2. **Authentication Header**: `Authorization: Bearer ${lunchflowApiKey}` ✓
3. **Endpoints Used**:
   - `/accounts` ✓
   - `/accounts/${account.id}/transactions?include_pending=true` ✓
   - `/accounts/${account.id}/balance` ✓
4. **HTTP Method**: GET for all endpoints ✓

### ⚠️ Potential Issues

#### 1. Response Structure Assumptions

**Current code assumes:**
```typescript
const accountsData = await accountsResponse.json()
const accounts: LunchflowAccount[] = accountsData.accounts || []
```

**Problem**: We don't know if the response is:
- `{ "accounts": [...] }` (current assumption)
- `[...]` (direct array)
- `{ "data": [...] }` (data wrapper)
- Something else entirely

**Same issue for transactions:**
```typescript
const txnData = await txnResponse.json()
const transactions: LunchflowTransaction[] = txnData.transactions || []
```

**And for balance:**
```typescript
const balanceData = await balanceResponse.json()
const balance: LunchflowBalance = balanceData.balance
```

#### 2. Field Name Mismatches

**Current interface assumptions:**
```typescript
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
  accountId: number  // ⚠️ camelCase
  amount: number
  currency: string
  date: string
  merchant: string | null
  description: string | null
  isPending: boolean  // ⚠️ camelCase
}
```

**Potential issues:**
- API might use `snake_case` instead of `camelCase` (e.g., `account_id` vs `accountId`)
- API might use different field names entirely
- Some fields might be nested in objects

#### 3. Error Handling

Current error handling is minimal:
```typescript
if (!accountsResponse.ok) {
  throw new Error(`Lunchflow API error: ${accountsResponse.status}`)
}
```

**Missing:**
- Actual error message from API
- Response body on error
- Retry logic for transient failures
- Specific handling for 401 (auth), 429 (rate limit), etc.

---

## How to Diagnose the Issue

### Step 1: Deploy Diagnostic Function

I've created `index-diagnostic.ts` that will log the actual API responses.

```bash
# Temporarily deploy the diagnostic version
cd supabase/functions/sync-lunchflow

# Backup the original
cp index.ts index.ts.backup

# Replace with diagnostic version
cp index-diagnostic.ts index.ts

# Deploy
supabase functions deploy sync-lunchflow --project-ref your-project-ref
```

### Step 2: Invoke and Check Logs

```bash
# Invoke the function
supabase functions invoke sync-lunchflow --project-ref your-project-ref

# View the logs
supabase functions logs sync-lunchflow --project-ref your-project-ref
```

Or from the dashboard:
1. Go to Edge Functions → sync-lunchflow
2. Click "Invoke"
3. Check the "Logs" tab

### Step 3: Look for in the Logs

1. **Authentication Issues**:
   ```
   Response status: 401
   Lunchflow API error: Unauthorized
   ```
   → Check your `LUNCHFLOW_API_KEY` secret

2. **Response Structure**:
   ```
   Raw accounts response structure: {...}
   ✓ Response has .accounts property
   ```
   → This tells us the actual structure

3. **Field Names**:
   ```
   First account structure: { "id": 123, "account_name": "..." }
   Account fields: ["id", "account_name", ...]
   ```
   → Shows actual field names used by API

4. **Empty Results**:
   ```
   Found 0 accounts
   ```
   → Either no accounts connected or wrong response parsing

### Step 4: Restore Original Function

```bash
# After getting the diagnostic info
mv index.ts.backup index.ts
supabase functions deploy sync-lunchflow --project-ref your-project-ref
```

---

## Common API Response Patterns

### Pattern 1: Direct Array
```json
[
  {
    "id": 123,
    "name": "Chase Checking",
    ...
  }
]
```
**Code fix:**
```typescript
const accounts = await accountsResponse.json()
```

### Pattern 2: Wrapped in "accounts" key
```json
{
  "accounts": [
    { "id": 123, ... }
  ]
}
```
**Code fix:**
```typescript
const { accounts } = await accountsResponse.json()
```

### Pattern 3: Wrapped in "data" key
```json
{
  "data": [
    { "id": 123, ... }
  ]
}
```
**Code fix:**
```typescript
const { data: accounts } = await accountsResponse.json()
```

### Pattern 4: Paginated Response
```json
{
  "data": [...],
  "pagination": {
    "page": 1,
    "total": 5,
    "hasMore": false
  }
}
```
**Code fix:** May need to handle pagination

---

## Quick Dashboard Test

If you can't use the CLI, test from the Supabase Dashboard:

1. **Navigate to**: Edge Functions → sync-lunchflow → Invocations
2. **Click**: "Invoke function"
3. **Check**: The response and logs

**Look for:**
- ✅ Success: Returns account count and diagnostic info
- ❌ Error 401: Check API key in Secrets
- ❌ Error 404: Check base URL
- ❌ Error 500: Check function logs for details

---

## Verification Checklist

- [ ] API key is set correctly in Supabase secrets (`LUNCHFLOW_API_KEY`)
- [ ] API key has the `Bearer ` prefix in the header (check: not needed, we add it)
- [ ] Base URL matches: `https://lunchflow.com/api/v1`
- [ ] Lunchflow account has connected bank accounts
- [ ] Response structure matches code expectations
- [ ] Field names match (check snake_case vs camelCase)
- [ ] Error messages are being logged properly

---

## Next Steps

1. Run the diagnostic function
2. Review the logs to see actual API response structures
3. Update the main function based on findings
4. Test again with corrected implementation

## Expected Fixes

Based on common patterns, you'll likely need to adjust:

1. **Response structure** - Change how we extract accounts/transactions/balance
2. **Field names** - Update TypeScript interfaces to match actual API
3. **Error handling** - Add better error logging and handling

Once we see the actual API responses in the logs, we can make the exact corrections needed.