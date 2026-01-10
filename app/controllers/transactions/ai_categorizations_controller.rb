class Transactions::AiCategorizationsController < ApplicationController
  include ActionView::RecordIdentifier

  def create
    @entry = Current.family.entries.transactions.find(params[:transaction_id])

    # Check if entryable exists without triggering RecordNotFound exception
    # (StoreLocation concern would catch it and return 404)
    transaction = begin
      # Check if the entryable record exists in the database
      entryable_class = @entry.entryable_type
      entryable_id = @entry.entryable_id

      if entryable_class.nil? || entryable_id.nil?
        nil
      elsif entryable_class.constantize.where(id: entryable_id).exists?
        @entry.entryable
      else
        nil
      end
    rescue ActiveRecord::RecordNotFound
      nil
    end

    # Handle orphaned entries (Entry exists but Transaction was deleted)
    if transaction.nil?
      flash[:error] = t("transactions.ai_categorize.error")
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
      end
      return
    end

    categorizer = Family::AutoCategorizer.new(Current.family, transaction_ids: [transaction.id])

    begin
      count = categorizer.auto_categorize

      if count.zero?
        flash[:error] = t("transactions.ai_categorize.error")
      end

      # Reload to get updated category and confidence
      transaction.reload

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(
              dom_id(transaction, :category_menu),
              partial: "categories/menu",
              locals: { transaction: transaction }
            ),
            turbo_stream.replace(
              "category_name_mobile_#{transaction.id}",
              partial: "categories/category_name_mobile",
              locals: { transaction: transaction }
            )
          ]
        end
      end
    rescue Family::AutoCategorizer::Error => e
      flash[:error] = t("transactions.ai_categorize.error")
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
      end
    end
  end
end
