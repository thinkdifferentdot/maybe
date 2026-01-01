class Transactions::BulkAutoCategorizationsController < ApplicationController
  before_action :set_transactions, only: [:preview]
  before_action :validate_batch_size, only: [:preview]

  def preview
    categorizer = Family::AutoCategorizer.new(
      Current.family,
      transaction_ids: @transactions.pluck(:id)
    )

    predictions = categorizer.preview_categorizations

    render json: {
      predictions: predictions.map do |prediction|
        {
          entry_id: prediction[:transaction].entry.id,
          transaction_name: prediction[:transaction].entry.name,
          account_name: prediction[:transaction].entry.account.name,
          amount: helpers.format_money(-prediction[:transaction].entry.amount_money),
          category_id: prediction[:category]&.id,
          category_name: prediction[:category]&.name,
          confidence: prediction[:confidence]
        }
      end
    }
  rescue Family::AutoCategorizer::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def create
    predictions = (params[:predictions] || []).reject(&:blank?)

    if predictions.empty?
      redirect_to transactions_path, alert: "No categorizations selected"
      return
    end

    applied_count = 0
    predictions.each do |prediction_json|
      prediction = JSON.parse(prediction_json)
      entry = Current.family.entries.find(prediction["entry_id"])
      transaction = entry.entryable

      if prediction["category_id"].present?
        transaction.enrich_attribute(:category_id, prediction["category_id"], source: "ai")
        transaction.lock_attr!(:category_id)
        applied_count += 1
      end
    end

    redirect_to transactions_path,
                notice: "Successfully categorized #{applied_count} transaction#{'s' unless applied_count == 1}"
  end

  private

  def set_transactions
    entry_ids = JSON.parse(params[:entry_ids] || "[]")
    @transactions = Current.family.transactions
                                  .joins(:entry)
                                  .where(entries: { id: entry_ids })
  end

  def validate_batch_size
    max_size = Setting.categorization_batch_size

    if @transactions.count > max_size
      render json: {
        error: "Cannot categorize more than #{max_size} transactions at once. Please adjust your selection or increase batch size in settings."
      }, status: :unprocessable_entity
    end
  end
end
