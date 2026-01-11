# frozen_string_literal: true

# Shared few-shot examples concern for LLM categorization
# Builds examples from two sources: static baseline examples + optional LearnedPattern examples
# Follows OpenAI Cookbook recommendations for transaction categorization
module Provider::Concerns::FewShotExamples
  extend ActiveSupport::Concern

  private

    # Build few-shot examples following the two-tier pattern:
    # 1. Static baseline examples (3-5 hardcoded examples covering common categories)
    # 2. User-specific LearnedPattern examples (0-3, if family has patterns)
    #
    # Returns an array of hashes with :description and :category keys
    def build_few_shot_examples
      examples = static_examples

      # Add user-specific examples if family has LearnedPattern records
      examples.concat(dynamic_examples) if family && family.learned_patterns.exists?

      examples
    end

    # Static baseline examples covering common transaction types
    # Uses recognizable real-world brands (OpenAI Cookbook pattern)
    # Only includes examples if the category exists in user's available categories
    def static_examples
      [
        { description: "WHOLE FOODS MARKET", category: "Groceries" },
        { description: "SHELL SERVICE STATION", category: "Gas & Fuel" },
        { description: "STARBUCKS", category: "Coffee Shops" },
        { description: "NETFLIX", category: "Streaming Services" },
        { description: "CHIPOTLE", category: "Restaurants" }
      ].select { |ex| category_exists?(ex[:category]) }
    end

    # Dynamic examples from user's LearnedPattern records
    # Selects diverse examples (one per category max) to avoid clustering
    # Samples up to 3 categories for variety
    def dynamic_examples
      patterns_by_category = family.learned_patterns.includes(:category).group_by(&:category)

      # Sample up to 3 categories, take first pattern from each
      patterns_by_category.values.sample(3).map(&:first).map do |pattern|
        {
          description: pattern.merchant_name,
          category: pattern.category.name
        }
      end
    rescue ArgumentError => e
      # Handle case where sample(3) is called on empty array
      Rails.logger.debug("Could not sample dynamic examples: #{e.message}")
      []
    end

    # Check if a category name exists in the user's available categories
    def category_exists?(name)
      user_categories.any? { |c| c[:name] == name }
    end

    # Format few-shot examples for inclusion in prompts
    # Returns an empty string if no examples are available
    def format_few_shot_examples(examples)
      return "" if examples.empty?

      examples.map do |ex|
        "Transaction: #{ex[:description]} \u2192 Category: #{ex[:category]}"
      end.join("\n")
    end

    # Build the few-shot examples text section for prompts
    # Returns formatted text with EXAMPLES header or empty string
    def build_few_shot_examples_text
      examples = build_few_shot_examples
      return "" if examples.empty?

      <<~EXAMPLES
        EXAMPLES:
        #{format_few_shot_examples(examples)}

      EXAMPLES
    end
end
