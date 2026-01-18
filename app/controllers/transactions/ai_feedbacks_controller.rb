class Transactions::AiFeedbacksController < ApplicationController
  include ActionView::RecordIdentifier

  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found

  def approve
    @transaction = Current.family.transactions.find(params[:transaction_id])
    @entry = @transaction.entry
    @id_suffix = params[:id_suffix]

    if @transaction.nil?
      respond_to do |format|
        format.turbo_stream { render "error", status: :unprocessable_entity }
        format.html { redirect_to transactions_path }
      end
      return
    end

    # Validate this is an AI-categorized transaction
    unless @transaction.ai_categorized?
      respond_to do |format|
        format.turbo_stream { render "error", status: :unprocessable_entity }
        format.html { redirect_to transactions_path }
      end
      return
    end

    # Create LearnedPattern from transaction's merchant and category
    Current.family.learn_pattern_from!(@transaction)

    # Mark feedback as given
    update_feedback_state(@transaction, "approved")

    flash[:notice] = t("transactions.approval_success")

    @transaction.reload
    @entry.reload
    
    respond_to do |format|
      format.turbo_stream
    end
  end

  def reject
    @transaction = Current.family.transactions.find(params[:transaction_id])
    @entry = @transaction.entry
    @id_suffix = params[:id_suffix]

    if @transaction.nil?
      respond_to do |format|
        format.turbo_stream { render "error", status: :unprocessable_entity }
        format.html { redirect_to transactions_path }
      end
      return
    end

    # Validate this is an AI-categorized transaction
    unless @transaction.ai_categorized?
      respond_to do |format|
        format.turbo_stream { render "error", status: :unprocessable_entity }
        format.html { redirect_to transactions_path }
      end
      return
    end

    # Remove category and clear confidence
    @transaction.update!(category_id: nil)

    # Mark feedback as given and store rejection
    update_feedback_state(@transaction, "rejected")

    flash[:notice] = t("transactions.rejection_success")

    @transaction.reload
    @entry.reload

    respond_to do |format|
      format.turbo_stream
    end
  end

  private

  def update_feedback_state(transaction, feedback_type)
    updated_extra = transaction.extra.merge(
      "ai_feedback_given" => true,
      "ai_feedback" => feedback_type,
      "ai_feedback_given_at" => Time.current.iso8601
    )

    # Clear confidence if rejected or approved (we're done with AI state)
    updated_extra.delete("ai_categorization_confidence")

    transaction.update!(extra: updated_extra)
    
    # Remove the enrichment record so it doesn't show as "recent AI" anymore
    transaction.data_enrichments
      .where(source: "ai", attribute_name: "category_id")
      .destroy_all
  end

  def handle_not_found
    respond_to do |format|
      format.turbo_stream { render "error", status: :not_found }
      format.html { redirect_to transactions_path }
    end
  end
end
