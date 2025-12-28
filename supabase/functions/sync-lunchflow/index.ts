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
