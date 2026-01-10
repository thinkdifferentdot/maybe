class Transactions::AiCategorizationsController < ApplicationController
  include ActionView::RecordIdentifier

  def create
    @entry = Current.family.entries.transactions.find(params[:transaction_id])

    begin
      transaction = @entry.entryable
    rescue ActiveRecord::RecordNotFound
      flash[:error] = t("transactions.ai_categorize.error")
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
      end
      return
    end

    # Check if entryable exists (handle orphaned entries)
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
