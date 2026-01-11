class Transaction < ApplicationRecord
  include Entryable, Transferable, Ruleable

  belongs_to :category, optional: true
  belongs_to :merchant, optional: true

  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggings
  has_many :data_enrichments, as: :enrichable, dependent: :destroy

  accepts_nested_attributes_for :taggings, allow_destroy: true

  after_save :clear_merchant_unlinked_association, if: :merchant_id_previously_changed?

  enum :kind, {
    standard: "standard", # A regular transaction, included in budget analytics
    funds_movement: "funds_movement", # Movement of funds between accounts, excluded from budget analytics
    cc_payment: "cc_payment", # A CC payment, excluded from budget analytics (CC payments offset the sum of expense transactions)
    loan_payment: "loan_payment", # A payment to a Loan account, treated as an expense in budgets
    one_time: "one_time" # A one-time expense/income, excluded from budget analytics
  }

  # Scope to find transactions categorized by AI within the specified time window
  scope :recent_ai, ->(family, since: 7.days.ago) {
    joins(:entry, :data_enrichments)
      .where(
        data_enrichments: {
          source: "ai",
          attribute_name: "category_id",
          created_at: since..
        },
        entries: { family_id: family.id }
      )
      .distinct
  }

  # Overarching grouping method for all transfer-type transactions
  def transfer?
    funds_movement? || cc_payment? || loan_payment?
  end

  def set_category!(category)
    if category.is_a?(String)
      category = entry.account.family.categories.find_or_create_by!(
        name: category
      )
    end

    update!(category: category)
  end

  def pending?
    extra_data = extra.is_a?(Hash) ? extra : {}
    ActiveModel::Type::Boolean.new.cast(extra_data.dig("simplefin", "pending")) ||
      ActiveModel::Type::Boolean.new.cast(extra_data.dig("plaid", "pending"))
  rescue
    false
  end

  # Returns the merchant name for pattern matching.
  # Prefers the associated merchant name, falls back to entry name.
  def merchant_name
    merchant&.name || entry&.name
  end

  # Check if this transaction was categorized by AI
  def ai_categorized?
    extra&.dig("ai_categorization_confidence").present?
  end

  # Check if user has given feedback on this AI categorization
  def ai_feedback_given?
    extra&.dig("ai_feedback_given").present?
  end

  private
    def clear_merchant_unlinked_association
      return unless merchant_id.present? && merchant.is_a?(ProviderMerchant)

      family = entry&.account&.family
      return unless family

      FamilyMerchantAssociation.where(family: family, merchant: merchant).delete_all
    end
end
