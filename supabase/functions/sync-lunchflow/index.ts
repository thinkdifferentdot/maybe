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
  currency?: string | null  // Optional - not required per API schema
  status?: string | null    // Optional - not required per API schema
}

interface LunchflowTransaction {
  id: string
  accountId: number  // API uses camelCase
  amount: number
  currency: string
  date: string
  merchant?: string | null  // Optional per schema
  description?: string | null  // Optional per schema
  isPending?: boolean  // Optional per schema (API uses camelCase)
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
    // Create Supabase client with service role key (bypasses RLS)
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const lunchflowApiKey = Deno.env.get('LUNCHFLOW_API_KEY')
    if (!lunchflowApiKey) {
      throw new Error('LUNCHFLOW_API_KEY not configured')
    }

    const baseUrl = 'https://www.lunchflow.app/api/v1'
    const headers = {
      'x-api-key': lunchflowApiKey,
      'Content-Type': 'application/json'
    }

    console.log('Starting Lunchflow sync...')

    // 1. Create sync log record
    const { data: syncLog, error: syncLogError } = await supabase
      .from('lunchflow_sync_log')
      .insert({
        sync_started_at: new Date().toISOString(),
        status: 'pending'
      })
      .select()
      .single()

    if (syncLogError) {
      console.error('Error creating sync log:', syncLogError)
      throw syncLogError
    }

    console.log('Created sync log:', syncLog.id)

    let accountsSynced = 0
    let transactionsSynced = 0

    try {
      // 2. Fetch accounts from Lunchflow
      console.log('Fetching accounts from Lunchflow...')
      const accountsResponse = await fetch(`${baseUrl}/accounts`, { headers })

      console.log('Accounts response status:', accountsResponse.status)

      if (!accountsResponse.ok) {
        const errorText = await accountsResponse.text()
        console.error('Lunchflow API error response:', errorText)
        throw new Error(`Lunchflow API error: ${accountsResponse.status} - ${errorText}`)
      }

      const accountsData = await accountsResponse.json()
      console.log('Accounts response type:', typeof accountsData, 'isArray:', Array.isArray(accountsData))

      // Handle different possible response structures
      let accounts: LunchflowAccount[] = []
      if (Array.isArray(accountsData)) {
        accounts = accountsData
      } else if (accountsData.accounts && Array.isArray(accountsData.accounts)) {
        accounts = accountsData.accounts
      } else if (accountsData.data && Array.isArray(accountsData.data)) {
        accounts = accountsData.data
      } else {
        console.error('Unexpected accounts response structure:', Object.keys(accountsData))
        throw new Error('Unexpected accounts response structure')
      }

      console.log(`Found ${accounts.length} accounts`)

      // 3. Upsert accounts
      for (const account of accounts) {
        console.log(`Syncing account: ${account.id} - ${account.name}`)

        const { error: upsertError } = await supabase
          .from('lunchflow_accounts')
          .upsert({
            id: account.id,
            name: account.name,
            institution_name: account.institution_name,
            institution_logo: account.institution_logo,
            provider: account.provider,
            currency: account.currency ?? null,
            status: account.status ?? null,
            updated_at: new Date().toISOString()
          }, { onConflict: 'id' })

        if (upsertError) {
          console.error('Error upserting account:', upsertError)
          throw upsertError
        }
        accountsSynced++

        // 4. Fetch transactions for each account
        console.log(`Fetching transactions for account ${account.id}...`)
        const txnResponse = await fetch(
          `${baseUrl}/accounts/${account.id}/transactions?include_pending=true`,
          { headers }
        )

        if (txnResponse.ok) {
          const txnData = await txnResponse.json()

          // Handle different possible response structures
          let transactions: LunchflowTransaction[] = []
          if (Array.isArray(txnData)) {
            transactions = txnData
          } else if (txnData.transactions && Array.isArray(txnData.transactions)) {
            transactions = txnData.transactions
          } else if (txnData.data && Array.isArray(txnData.data)) {
            transactions = txnData.data
          }

          console.log(`Found ${transactions.length} transactions for account ${account.id}`)

          for (const txn of transactions) {
            const { error: txnError } = await supabase
              .from('lunchflow_transactions')
              .upsert({
                id: txn.id,
                account_id: txn.accountId,  // Map camelCase to snake_case
                amount: txn.amount,
                currency: txn.currency,
                date: txn.date,
                merchant: txn.merchant ?? null,
                description: txn.description ?? null,
                is_pending: txn.isPending ?? false,  // Map camelCase to snake_case
                updated_at: new Date().toISOString()
              }, { onConflict: 'id' })

            if (txnError) {
              console.error('Error upserting transaction:', txnError)
              throw txnError
            }
            transactionsSynced++
          }
        } else {
          const errorText = await txnResponse.text()
          console.warn(`Failed to fetch transactions for account ${account.id}: ${txnResponse.status} - ${errorText}`)
        }

        // 5. Fetch balance for each account
        console.log(`Fetching balance for account ${account.id}...`)
        const balanceResponse = await fetch(
          `${baseUrl}/accounts/${account.id}/balance`,
          { headers }
        )

        if (balanceResponse.ok) {
          const balanceData = await balanceResponse.json()

          // Handle different possible response structures
          let balance: LunchflowBalance | null = null
          if (balanceData.balance) {
            balance = balanceData.balance
          } else if (balanceData.amount !== undefined) {
            balance = balanceData
          }

          if (balance) {
            const { error: balanceError } = await supabase
              .from('lunchflow_balances')
              .insert({
                account_id: account.id,
                amount: balance.amount,
                currency: balance.currency,
                synced_at: new Date().toISOString()
              })

            if (balanceError) {
              console.error('Error inserting balance:', balanceError)
              // Don't throw - balances might have duplicate constraint
              console.warn('Balance insert failed, continuing...')
            }
          }
        } else {
          const errorText = await balanceResponse.text()
          console.warn(`Failed to fetch balance for account ${account.id}: ${balanceResponse.status} - ${errorText}`)
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

      console.log('Sync completed successfully')

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
      console.error('Sync failed:', syncError)

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
    console.error('Function error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
