class Family::AutoCategorizer
  Error = Class.new(StandardError)

  # Result struct for AI categorization with confidence score
  # Confidence is a float between 0.0 and 1.0 (default 1.0 for now)
  # Until providers return actual confidence scores, we default to 100%
  Result = Data.define(:transaction_id, :category_name, :confidence) do
    def initialize(transaction_id:, category_name:, confidence: 1.0)
      super
    end
  end

  def initialize(family, transaction_ids: [])
    @family = family
    @transaction_ids = transaction_ids
  end

  def auto_categorize
    raise Error, "No LLM provider for auto-categorization" unless llm_provider

    if scope.none?
      Rails.logger.info("No transactions to auto-categorize for family #{family.id}")
      return 0
    else
      Rails.logger.info("Auto-categorizing #{scope.count} transactions for family #{family.id}")
    end

    categories_input = user_categories_input

    if categories_input.empty?
      Rails.logger.error("Cannot auto-categorize transactions for family #{family.id}: no categories available")
      return 0
    end

    # First, apply any learned patterns (bypasses AI)
    modified_count = apply_learned_patterns(scope)

    # Reload scope to get remaining uncategorized transactions
    remaining_scope = scope.where(category_id: nil)

    if remaining_scope.none?
      Rails.logger.info("All transactions categorized via learned patterns for family #{family.id}")
      return modified_count
    end

    Rails.logger.info("Running AI categorization for #{remaining_scope.count} remaining transactions for family #{family.id}")

    result = llm_provider.auto_categorize(
      transactions: transactions_input(remaining_scope),
      user_categories: categories_input,
      family: family
    )

    unless result.success?
      Rails.logger.error("Failed to auto-categorize transactions for family #{family.id}: #{result.error.message}")
      return modified_count
    end

    remaining_scope.each do |transaction|
      auto_categorization = result.data.find { |c| c.transaction_id == transaction.id }

      category_id = categories_input.find { |c| c[:name] == auto_categorization&.category_name }&.dig(:id)

      if category_id.present?
        # Get confidence score from auto_categorization if available, otherwise default to 1.0
        # (until providers return actual confidence scores)
        confidence = auto_categorization.respond_to?(:confidence) ? auto_categorization.confidence : 1.0

        was_modified = transaction.enrich_attribute(
          :category_id,
          category_id,
          source: "ai"
        )

        # Store confidence in extra metadata for UI display
        if was_modified
          transaction.update_column(:extra, transaction.extra.merge("ai_categorization_confidence" => confidence))
        end

        transaction.lock_attr!(:category_id)
        # enrich_attribute returns true if the transaction was actually modified
        modified_count += 1 if was_modified
      end
    end

    modified_count
  end

  private
    attr_reader :family, :transaction_ids

    # Apply learned patterns before AI categorization
    # Returns count of transactions modified
    def apply_learned_patterns(transactions_scope)
      modified_count = 0

      transactions_scope.each do |transaction|
        pattern = family.learned_pattern_for(transaction)
        next unless pattern

        was_modified = transaction.enrich_attribute(
          :category_id,
          pattern.category_id,
          source: "learned_pattern"
        )
        transaction.lock_attr!(:category_id)
        modified_count += 1 if was_modified
      end

      Rails.logger.info("Applied #{modified_count} learned patterns for family #{family.id}") if modified_count > 0
      modified_count
    end

    # Use the family's configured LLM provider (openai or anthropic)
    def llm_provider
      provider_name = Setting.llm_provider.presence || "openai"
      Provider::Registry.for_concept(:llm).get_provider(provider_name)
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

    def transactions_input(scope_to_use = scope)
      scope_to_use.map do |transaction|
        {
          id: transaction.id,
          amount: transaction.entry.amount.abs,
          classification: transaction.entry.classification,
          description: [ transaction.entry.name, transaction.entry.notes ].compact.reject(&:empty?).join(" "),
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
