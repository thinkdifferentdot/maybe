class LunchflowAccount::PostProcessor
  attr_reader :lunchflow_account

  def initialize(lunchflow_account)
    @lunchflow_account = lunchflow_account
  end

  def process(transaction_ids)
    return unless ai_categorize_enabled?
    return unless lunchflow_account.current_account.present?

    account = lunchflow_account.current_account
    family = account.family

    # Find uncategorized transactions from this sync
    uncategorized_transactions = family.transactions
      .where(id: transaction_ids, category_id: nil)
      .enrichable(:category_id)

    uncategorized_ids = uncategorized_transactions.pluck(:id)

    return unless uncategorized_ids.any?

    Rails.logger.info("LunchflowAccount::PostProcessor - Triggering AI categorization for #{uncategorized_ids.count} transactions")

    family.auto_categorize_transactions_later(
      Transaction.where(id: uncategorized_ids)
    )
  end

  private

  def ai_categorize_enabled?
    Setting.ai_categorize_on_sync == true
  end
end
