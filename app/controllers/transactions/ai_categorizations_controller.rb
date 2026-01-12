class Transactions::AiCategorizationsController < ApplicationController
  include ActionView::RecordIdentifier

  # Override StoreLocation concern's rescue_from for this controller
  rescue_from ActiveRecord::RecordNotFound, with: :handle_orphaned_entry

  def create
    @entry = Current.family.entries.transactions.find(params[:transaction_id])
    @transaction = @entry.entryable

    # Handle nil entryable (orphaned entry where association returns nil)
    if @transaction.nil?
      flash[:error] = t("transactions.ai_categorize.error")
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
      end
      return
    end

    categorizer = Family::AutoCategorizer.new(Current.family, transaction_ids: [ @transaction.id ])

    begin
      count = categorizer.auto_categorize

      if count.zero?
        flash[:error] = t("transactions.ai_categorize.error")
      end

      # Reload to get updated category and confidence
      @transaction.reload

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(
              "#{dom_id(@transaction, "category_menu")}_mobile",
              partial: "transactions/transaction_category",
              locals: { transaction: @transaction, entry: @entry, id_suffix: "mobile" }
            ),
            turbo_stream.replace(
              "#{dom_id(@transaction, "category_menu")}_desktop",
              partial: "transactions/transaction_category",
              locals: { transaction: @transaction, entry: @entry, id_suffix: "desktop" }
            ),
            turbo_stream.replace(
              "category_name_mobile_#{@transaction.id}",
              partial: "categories/category_name_mobile",
              locals: { transaction: @transaction }
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

  private

    def handle_orphaned_entry
      flash[:error] = t("transactions.ai_categorize.error")
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
      end
    end
end
