class Transactions::ReviewsController < ApplicationController
  def index
    # Fetch transactions with AI categorization confidence but no feedback given
    @transactions = Current.family.transactions
      .includes(:category, :merchant, entry: { account: :family })
      .where.not(category_id: nil)
      .where("transactions.extra->>'ai_categorization_confidence' IS NOT NULL")
      .where("transactions.extra->>'ai_feedback_given' IS NULL")
      .order(updated_at: :desc)
      .limit(50)
  end
end
