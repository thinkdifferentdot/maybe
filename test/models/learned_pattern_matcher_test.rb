require "test_helper"

class LearnedPatternMatcherTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @family = families(:dylan_family)
    @category = categories(:food_and_drink)
    @matcher = LearnedPatternMatcher.new(@family)
    @account = @family.accounts.create!(name: "Test", balance: 100, currency: "USD", accountable: Depository.new)
  end

  # Matching logic

  test "finds exact match for normalized merchant name" do
    LearnedPattern.create!(merchant_name: "McDonalds", family: @family, category: @category)
    transaction = create_transaction(name: "McDonalds").transaction

    pattern = @matcher.find_matching_pattern(transaction)

    assert_not_nil pattern
    assert_equal @category, pattern.category
  end

  test "finds match case-insensitively" do
    LearnedPattern.create!(merchant_name: "mcdonalds", family: @family, category: @category)
    transaction = create_transaction(name: "MCDONALDS").transaction

    pattern = @matcher.find_matching_pattern(transaction)

    assert_not_nil pattern
    assert_equal @category, pattern.category
  end

  test "finds match with special characters difference" do
    LearnedPattern.create!(merchant_name: "McDonalds", family: @family, category: @category)
    transaction = create_transaction(name: "McDonald's!!!").transaction

    pattern = @matcher.find_matching_pattern(transaction)

    assert_not_nil pattern
    assert_equal @category, pattern.category
  end

  test "finds substring match where input contains pattern" do
    LearnedPattern.create!(merchant_name: "Amazon", family: @family, category: @category)
    transaction = create_transaction(name: "Amazon Web Services").transaction

    pattern = @matcher.find_matching_pattern(transaction)

    assert_not_nil pattern
    assert_equal @category, pattern.category
  end

  test "finds substring match where pattern contains input" do
    LearnedPattern.create!(merchant_name: "Starbucks Coffee", family: @family, category: @category)
    transaction = create_transaction(name: "Starbucks").transaction

    pattern = @matcher.find_matching_pattern(transaction)

    assert_not_nil pattern
    assert_equal @category, pattern.category
  end

  test "finds substring match with whitespace differences" do
    LearnedPattern.create!(merchant_name: "Trader Joe's", family: @family, category: @category)
    transaction = create_transaction(name: "Trader    Joes").transaction

    pattern = @matcher.find_matching_pattern(transaction)

    assert_not_nil pattern
    assert_equal @category, pattern.category
  end

  # No match scenarios

  test "returns nil when no patterns exist" do
    transaction = create_transaction(name: "Walmart").transaction

    pattern = @matcher.find_matching_pattern(transaction)

    assert_nil pattern
  end

  test "returns nil when transaction has no merchant name" do
    transaction = create_transaction(name: "Test").transaction
    transaction.stubs(:merchant_name).returns("")

    pattern = @matcher.find_matching_pattern(transaction)

    assert_nil pattern
  end

  test "returns nil when transaction merchant_name is nil" do
    transaction = create_transaction(name: "Test").transaction
    transaction.stubs(:merchant_name).returns(nil)

    pattern = @matcher.find_matching_pattern(transaction)

    assert_nil pattern
  end

  test "returns nil when no pattern matches" do
    LearnedPattern.create!(merchant_name: "McDonalds", family: @family, category: @category)
    transaction = create_transaction(name: "Walmart").transaction

    pattern = @matcher.find_matching_pattern(transaction)

    assert_nil pattern
  end

  # Multiple patterns

  test "returns first matching pattern when multiple patterns exist" do
    category2 = @family.categories.create!(name: "Other Category")
    LearnedPattern.create!(merchant_name: "Store", family: @family, category: @category)
    LearnedPattern.create!(merchant_name: "Store Plus", family: @family, category: category2)

    transaction = create_transaction(name: "General Store").transaction

    pattern = @matcher.find_matching_pattern(transaction)

    assert_not_nil pattern
    assert_equal @category, pattern.category
  end

  test "returns exact match over substring match" do
    category2 = @family.categories.create!(name: "Other Category")
    LearnedPattern.create!(merchant_name: "Amazon", family: @family, category: @category)
    LearnedPattern.create!(merchant_name: "Amazon Web Services", family: @family, category: category2)

    transaction = create_transaction(name: "Amazon").transaction

    pattern = @matcher.find_matching_pattern(transaction)

    assert_not_nil pattern
    assert_equal @category, pattern.category
  end

  # Edge cases

  test "handles patterns with special characters" do
    LearnedPattern.create!(merchant_name: "Trader Joe's", family: @family, category: @category)
    transaction = create_transaction(name: "Trader Joes").transaction

    pattern = @matcher.find_matching_pattern(transaction)

    assert_not_nil pattern
    assert_equal @category, pattern.category
  end

  test "handles unicode characters in merchant names" do
    # Unicode characters get normalized by stripping non-alphanumeric chars
    # "Café" normalizes to "caf" (accent stripped)
    LearnedPattern.create!(merchant_name: "Café", family: @family, category: @category)
    transaction = create_transaction(name: "Café").transaction

    pattern = @matcher.find_matching_pattern(transaction)

    assert_not_nil pattern
    assert_equal @category, pattern.category
  end

  test "handles numeric merchant names" do
    LearnedPattern.create!(merchant_name: "7-Eleven", family: @family, category: @category)
    transaction = create_transaction(name: "7-Eleven Store 123").transaction

    pattern = @matcher.find_matching_pattern(transaction)

    assert_not_nil pattern
    assert_equal @category, pattern.category
  end

  test "handles merchant names with only numbers" do
    LearnedPattern.create!(merchant_name: "12345", family: @family, category: @category)
    transaction = create_transaction(name: "12345").transaction

    pattern = @matcher.find_matching_pattern(transaction)

    assert_not_nil pattern
    assert_equal @category, pattern.category
  end

  test "handles patterns from other families (isolated matching)" do
    other_family = Family.create!(name: "Other Family")
    other_category = other_family.categories.create!(name: "Other Category")

    LearnedPattern.create!(merchant_name: "McDonalds", family: other_family, category: other_category)
    transaction = create_transaction(name: "McDonalds").transaction

    pattern = @matcher.find_matching_pattern(transaction)

    assert_nil pattern
  end

  test "finds pattern with punctuation differences" do
    LearnedPattern.create!(merchant_name: "Amazon.com", family: @family, category: @category)
    transaction = create_transaction(name: "Amazoncom Services").transaction

    pattern = @matcher.find_matching_pattern(transaction)

    assert_not_nil pattern
    assert_equal @category, pattern.category
  end

  test "handles empty merchant list gracefully" do
    # Family with no learned patterns
    empty_family = families(:empty)
    matcher = LearnedPatternMatcher.new(empty_family)

    account = empty_family.accounts.create!(name: "Test", balance: 100, currency: "USD", accountable: Depository.new)
    transaction = create_transaction(account: account, name: "Some Store").transaction

    pattern = matcher.find_matching_pattern(transaction)

    assert_nil pattern
  end

  test "finds match when merchant name contains pattern" do
    LearnedPattern.create!(merchant_name: "Target", family: @family, category: @category)
    transaction = create_transaction(name: "Target Store San Francisco").transaction

    pattern = @matcher.find_matching_pattern(transaction)

    assert_not_nil pattern
    assert_equal @category, pattern.category
  end

  test "finds match when pattern contains merchant name" do
    LearnedPattern.create!(merchant_name: "Whole Foods Market", family: @family, category: @category)
    transaction = create_transaction(name: "Whole Foods").transaction

    pattern = @matcher.find_matching_pattern(transaction)

    assert_not_nil pattern
    assert_equal @category, pattern.category
  end

  test "handles very long merchant names" do
    long_name = "A" * 200
    LearnedPattern.create!(merchant_name: long_name, family: @family, category: @category)
    transaction = create_transaction(name: long_name).transaction

    pattern = @matcher.find_matching_pattern(transaction)

    assert_not_nil pattern
    assert_equal @category, pattern.category
  end
end
