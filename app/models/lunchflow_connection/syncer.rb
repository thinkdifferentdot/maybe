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
