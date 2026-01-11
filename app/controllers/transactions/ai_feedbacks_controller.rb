class Transactions::AifeedbacksController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :authenticate_family!
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found

  def approve
    @entry = Current.family.entries.transactions.find(params[:transaction_id])
    @transaction = @entry.entryable

    if @transaction.nil?
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
      end
      return
    end

    # Validate this is an AI-categorized transaction
    unless @transaction.ai_categorized?
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
      end
      return
    end

    # Create LearnedPattern from transaction's merchant and category
    Current.family.learn_pattern_from!(@transaction)

    # Mark feedback as given
    update_feedback_state(@transaction, "approved")

    respond_to do |format|
      format.turbo_stream
    end
  end

  def reject
    @entry = Current.family.entries.transactions.find(params[:transaction_id])
    @transaction = @entry.entryable

    if @transaction.nil?
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
      end
      return
    end

    # Validate this is an AI-categorized transaction
    unless @transaction.ai_categorized?
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
      end
      return
    end

    # Remove category and clear confidence
    @transaction.update_column(:category_id, nil)

    # Mark feedback as given and store rejection
    update_feedback_state(@transaction, "rejected")

    respond_to do |format|
      format.turbo_stream
    end
  end

  private

  def update_feedback_state(transaction, feedback_type)
    updated_extra = transaction.extra.merge(
      "ai_feedback_given" => true,
      "ai_feedback" => feedback_type
    )

    # Clear confidence if rejected
    updated_extra.delete("ai_categorization_confidence") if feedback_type == "rejected"

    transaction.update_column(:extra, updated_extra)
  end

  def handle_not_found
    respond_to do |format|
      format.turbo_stream { head :unprocessable_entity }
    end
  end
end
