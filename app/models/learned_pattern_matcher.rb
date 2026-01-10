# Service for finding learned pattern matches for transactions.
# Uses substring matching to find fuzzy matches between merchant names.
class LearnedPatternMatcher
  attr_reader :family

  def initialize(family)
    @family = family
  end

  # Finds a matching learned pattern for the given transaction.
  # Returns the first matching pattern or nil if no match is found.
  def find_matching_pattern(transaction)
    return nil if transaction.merchant_name.blank?

    normalized_input = normalize(transaction.merchant_name)

    # Try exact match first
    pattern = family.learned_patterns.find_by(normalized_merchant: normalized_input)
    return pattern if pattern

    # Try substring matching (input contains pattern or pattern contains input)
    family.learned_patterns.find_each do |candidate|
      if substring_match?(normalized_input, candidate.normalized_merchant)
        return candidate
      end
    end

    nil
  end

  private

  # Normalize a string for pattern matching.
  # Downcases, removes special characters, and collapses whitespace.
  def normalize(str)
    str.to_s.downcase.gsub(/[^a-z0-9\s]/, "").squeeze(" ").strip
  end

  # Check if two strings match via substring relationship.
  # Returns true if one string contains the other.
  def substring_match?(input, pattern)
    input.include?(pattern) || pattern.include?(input)
  end
end
