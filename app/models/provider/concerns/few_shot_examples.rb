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
    # Uses relevance-based merchant matching instead of random sampling.
    # Finds patterns matching the merchants in the current transaction batch.
    def dynamic_examples
      return [] unless family

      # Get merchant names from transactions if available
      merchant_names = extract_merchant_names_from_transactions

      # Collect relevant patterns for each merchant, up to 3 total
      relevant_pattern_set = Set.new
      merchant_names.each do |merchant|
        patterns = relevant_patterns(merchant)
        patterns.each { |p| relevant_pattern_set << p }
        break if relevant_pattern_set.size >= 3
      end

      # Convert patterns to example format
      relevant_pattern_set.first(3).map do |pattern|
        {
          description: pattern.merchant_name,
          category: pattern.category.name
        }
      end
    rescue => e
      Rails.logger.debug("Could not build dynamic examples: #{e.message}")
      []
    end

    # Extract merchant names from transactions array.
    # Returns array of merchant name strings.
    def extract_merchant_names_from_transactions
      return [] unless respond_to?(:transactions)

      transactions.map do |transaction|
        transaction[:description] || transaction["description"]
      end.compact.uniq
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
    # Returns formatted text with EXAMPLES header and optional USER'S PATTERNS section
    def build_few_shot_examples_text
      static = static_examples
      dynamic = dynamic_examples

      return "" if static.empty? && dynamic.empty?

      text = +""

      # Add static examples section
      if static.any?
        text << "EXAMPLES:\n"
        text << format_few_shot_examples(static)
        text << "\n\n"
      end

      # Add user patterns section if any exist
      if dynamic.any?
        text << "USER'S PATTERNS (how this user categorizes):\n"
        text << format_few_shot_examples(dynamic)
        text << "\n"
      end

      text
    end

    # Find relevant learned patterns for a given merchant name.
    # Uses fuzzy matching with relevance sorting (exact matches first, then substring similarity).
    # Returns up to 3 most relevant LearnedPattern records.
    #
    # @param merchant_name [String] the merchant name to find patterns for
    # @return [Array<LearnedPattern>] array of relevant patterns, sorted by relevance
    def relevant_patterns(merchant_name)
      return [] unless merchant_name.present? && family

      normalized_input = normalize_merchant(merchant_name)

      # Try exact match first
      exact_match = family.learned_patterns.includes(:category).find_by(normalized_merchant: normalized_input)
      return [exact_match] if exact_match

      # Find all substring matches and sort by relevance
      all_matches = family.learned_patterns.includes(:category).select do |pattern|
        substring_match?(normalized_input, pattern.normalized_merchant)
      end

      # Sort by relevance (longer matching substring = higher relevance)
      sorted_matches = all_matches.sort_by do |pattern|
        # Calculate match score: negative length so longer matches come first
        -calculate_match_score(normalized_input, pattern.normalized_merchant)
      end

      sorted_matches.first(3)
    rescue => e
      Rails.logger.debug("Error finding relevant patterns: #{e.message}")
      []
    end

    # Normalize a merchant name for pattern matching.
    # Downcases, removes special characters, and collapses whitespace.
    # @param str [String] the string to normalize
    # @return [String] the normalized string
    def normalize_merchant(str)
      str.to_s.downcase.gsub(/[^a-z0-9\s]/, "").squeeze(" ").strip
    end

    # Check if two strings match via substring relationship.
    # @param input [String] the normalized input string
    # @param pattern [String] the normalized pattern string
    # @return [Boolean] true if one string contains the other
    def substring_match?(input, pattern)
      return false if input.blank? || pattern.blank?

      # Quality threshold: only match if substring is at least 3 characters
      (input.include?(pattern) || pattern.include?(input)) && [input.length, pattern.length].min >= 3
    end

    # Calculate a relevance score for a substring match.
    # Longer matching substrings get higher scores.
    # @param input [String] the normalized input string
    # @param pattern [String] the normalized pattern string
    # @return [Integer] the match score (higher = more relevant)
    def calculate_match_score(input, pattern)
      if input.include?(pattern)
        pattern.length
      elsif pattern.include?(input)
        input.length
      else
        0
      end
    end
end
