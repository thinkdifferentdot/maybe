class Family::AutoCategorizer
  Error = Class.new(StandardError)

  def initialize(family, transaction_ids: [])
    @family = family
    @transaction_ids = transaction_ids
  end

  def auto_categorize
    raise Error, "No LLM provider for auto-categorization" unless llm_provider

    if scope.none?
      Rails.logger.info("No transactions to auto-categorize for family #{family.id}")
      return
    end

    batch_size = Setting.categorization_batch_size
    total_batches = (scope.count.to_f / batch_size).ceil
    current_batch = 0

    scope.in_batches(of: batch_size) do |batch|
      current_batch += 1
      Rails.logger.info("Processing batch #{current_batch} of #{total_batches} (#{batch.count} transactions)")

      result = llm_provider.auto_categorize(
        transactions: build_transactions_input(batch),
        user_categories: user_categories_input,
        options: categorization_options
      )

      process_batch_result(batch, result)
    end
  end

  private
    attr_reader :family, :transaction_ids

    def categorization_options
      {
        confidence_threshold: Setting.categorization_confidence_threshold,
        prefer_subcategories: Setting.categorization_prefer_subcategories,
        enforce_classification: Setting.categorization_enforce_classification_match,
        null_tolerance: Setting.categorization_null_tolerance
      }
    end

    def process_batch_result(batch, result)
      unless result.success?
        Rails.logger.error("Failed to auto-categorize batch for family #{family.id}: #{result.error.message}")
        return
      end

      batch.each do |transaction|
        auto_categorization = result.data.find { |c| c.transaction_id == transaction.id }
        category_id = user_categories_input.find { |c| c[:name] == auto_categorization&.category_name }&.dig(:id)

        if category_id.present?
          transaction.enrich_attribute(:category_id, category_id, source: "ai")
        end

        transaction.lock_attr!(:category_id)
      end
    end

    # Returns the first available/configured LLM provider, respecting preference order
    def llm_provider
      Provider::Registry.for_concept(:llm).providers.first
    end

    def user_categories_input
      family.categories.map do |category|
        {
          id: category.id,
          name: category.name,
          is_subcategory: category.subcategory?,
          parent_id: category.parent_id,
          classification: category.classification
        }
      end
    end

    def build_transactions_input(batch)
      batch.map do |transaction|
        {
          id: transaction.id,
          amount: transaction.entry.amount.abs,
          classification: transaction.entry.classification,
          description: transaction.entry.name,
          merchant: transaction.merchant&.name
        }
      end
    end


    def scope
      family.transactions.where(id: transaction_ids, category_id: nil)
                         .enrichable(:category_id)
                         .includes(:category, :merchant, :entry)
    end
end
