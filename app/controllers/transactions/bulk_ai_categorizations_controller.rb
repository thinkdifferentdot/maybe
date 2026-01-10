class Transactions::BulkAiCategorizationsController < ApplicationController
  include ActionView::RecordIdentifier

  CONFIDENCE_THRESHOLD = 0.60

  def create
    entry_ids = params.dig(:bulk_ai_categorize, :entry_ids)&.reject(&:blank?)

    if entry_ids.blank?
      flash[:error] = t("transactions.bulk_ai_categorize.error")
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
      end
      return
    end

    # Find transactions and filter to only uncategorized, enrichable ones
    entries = Current.family.entries.transactions.where(id: entry_ids)
    transactions = entries.map(&:entryable).select do |txn|
      txn.category_id.nil? && txn.enrichable?(:category_id)
    end

    if transactions.empty?
      flash[:error] = t("transactions.bulk_ai_categorize.error")
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
      end
      return
    end

    transaction_ids = transactions.map(&:id)
    categorizer = Family::AutoCategorizer.new(Current.family, transaction_ids: transaction_ids)

    begin
      modified_count = categorizer.auto_categorize

      # Reload transactions to get updated categories and confidence scores
      transactions = Current.family.transactions.where(id: transaction_ids).to_a

      # Build results array
      results = transactions.map do |txn|
        confidence = txn.extra.dig("ai_categorization_confidence") || 1.0
        {
          transaction_id: txn.id,
          entry_id: txn.entry.id,
          category_name: txn.category&.name,
          confidence: confidence,
          status: txn.category_id.present? ? :success : :skipped
        }
      end

      # Count results
      success_count = results.count { |r| r[:status] == :success }
      skipped_count = results.count { |r| r[:status] == :skipped }

      respond_to do |format|
        format.turbo_stream do
          streams = []

          # Update each transaction row that was categorized
          results.select { |r| r[:status] == :success }.each do |result|
            txn = transactions.find { |t| t.id == result[:transaction_id] }
            streams << turbo_stream.replace(
              dom_id(txn, :category_menu),
              partial: "categories/menu",
              locals: { transaction: txn }
            )
            streams << turbo_stream.replace(
              "category_name_mobile_#{txn.id}",
              partial: "categories/category_name_mobile",
              locals: { transaction: txn }
            )
          end

          # Show summary modal
          streams << turbo_stream.append(
            "body",
            partial: "transactions/bulk_ai_summary",
            locals: {
              success_count: success_count,
              skipped_count: skipped_count,
              error_count: 0
            }
          )

          render turbo_stream: streams
        end
      end
    rescue Family::AutoCategorizer::Error => e
      flash[:error] = t("transactions.bulk_ai_categorize.error")
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
      end
    end
  end
end
