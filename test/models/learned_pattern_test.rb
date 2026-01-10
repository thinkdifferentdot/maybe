require "test_helper"

class LearnedPatternTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @category = categories(:food_and_drink)
  end

  # Validations

  test "requires presence of family" do
    pattern = LearnedPattern.new(merchant_name: "McDonalds", category: @category, family: nil)
    assert_not pattern.valid?
    assert_includes pattern.errors[:family], "must exist"
  end

  test "requires presence of category" do
    pattern = LearnedPattern.new(merchant_name: "McDonalds", family: @family, category: nil)
    assert_not pattern.valid?
    assert_includes pattern.errors[:category], "must exist"
  end

  test "requires presence of merchant_name" do
    pattern = LearnedPattern.new(merchant_name: nil, family: @family, category: @category)
    assert_not pattern.valid?
    assert_includes pattern.errors[:merchant_name], "can't be blank"
  end

  test "normalized_merchant is set from merchant_name before validation" do
    pattern = LearnedPattern.new(merchant_name: "McDonalds", family: @family, category: @category)
    pattern.valid?
    assert_equal "mcdonalds", pattern.normalized_merchant
  end

  test "enforces uniqueness of normalized_merchant scoped to family" do
    pattern1 = LearnedPattern.create!(merchant_name: "McDonalds", family: @family, category: @category)
    pattern2 = LearnedPattern.new(merchant_name: "mcdonalds!", family: @family, category: @category)

    assert_not pattern2.valid?
    assert_includes pattern2.errors[:normalized_merchant], "has already been taken"
  end

  test "allows same normalized_merchant for different families" do
    other_family = Family.create!(name: "Other Family")
    other_category = other_family.categories.create!(name: "Other Category")

    pattern1 = LearnedPattern.create!(merchant_name: "McDonalds", family: @family, category: @category)
    pattern2 = LearnedPattern.new(merchant_name: "McDonalds", family: other_family, category: other_category)

    assert pattern2.valid?
  end

  # Normalization

  test "normalizes merchant_name by downcasing" do
    pattern = LearnedPattern.new(merchant_name: "McDONALDs", family: @family, category: @category)
    pattern.valid?
    assert_equal "mcdonalds", pattern.normalized_merchant
  end

  test "normalizes merchant_name by stripping special characters" do
    pattern = LearnedPattern.new(merchant_name: "McDonald's!!!", family: @family, category: @category)
    pattern.valid?
    assert_equal "mcdonalds", pattern.normalized_merchant
  end

  test "normalizes merchant_name by collapsing extra whitespace" do
    pattern = LearnedPattern.new(merchant_name: "Mc   Donald's   Restaurant", family: @family, category: @category)
    pattern.valid?
    assert_equal "mc donalds restaurant", pattern.normalized_merchant
  end

  test "normalizes merchant_name by stripping leading and trailing whitespace" do
    pattern = LearnedPattern.new(merchant_name: "  McDonalds  ", family: @family, category: @category)
    pattern.valid?
    assert_equal "mcdonalds", pattern.normalized_merchant
  end

  test "normalizes merchant_name with all transformations combined" do
    pattern = LearnedPattern.new(merchant_name: "  MC   DONALD's!!!  ", family: @family, category: @category)
    pattern.valid?
    assert_equal "mc donalds", pattern.normalized_merchant
  end

  test "keeps alphanumeric characters and spaces during normalization" do
    pattern = LearnedPattern.new(merchant_name: "Starbucks Coffee 123", family: @family, category: @category)
    pattern.valid?
    assert_equal "starbucks coffee 123", pattern.normalized_merchant
  end

  # Associations

  test "belongs to family" do
    pattern = LearnedPattern.create!(merchant_name: "McDonalds", family: @family, category: @category)
    assert_equal @family, pattern.family
  end

  test "belongs to category" do
    pattern = LearnedPattern.create!(merchant_name: "McDonalds", family: @family, category: @category)
    assert_equal @category, pattern.category
  end

  # Edge cases

  test "handles empty string merchant_name gracefully" do
    pattern = LearnedPattern.new(merchant_name: "", family: @family, category: @category)
    pattern.valid?
    assert_nil pattern.normalized_merchant
    assert_not pattern.save
  end

  test "handles nil merchant_name gracefully" do
    pattern = LearnedPattern.new(merchant_name: nil, family: @family, category: @category)
    pattern.valid?
    assert_nil pattern.normalized_merchant
    assert_not pattern.save
  end

  test "handles very long merchant names" do
    long_name = "A" * 500
    pattern = LearnedPattern.new(merchant_name: long_name, family: @family, category: @category)
    assert pattern.valid?
    assert pattern.save
    assert_equal "a" * 500, pattern.normalized_merchant
  end

  test "handles unicode characters in merchant names" do
    pattern = LearnedPattern.new(merchant_name: "Café Müller", family: @family, category: @category)
    pattern.valid?
    # Unicode characters with accents are stripped, leaving only alphanumeric
    assert_equal "caf mller", pattern.normalized_merchant
  end

  test "handles merchant names with only special characters" do
    pattern = LearnedPattern.new(merchant_name: "!!!@@@###", family: @family, category: @category)
    pattern.valid?
    assert_equal "", pattern.normalized_merchant
  end

  test "handles merchant names with numbers" do
    pattern = LearnedPattern.new(merchant_name: "7-Eleven Store #1234", family: @family, category: @category)
    pattern.valid?
    assert_equal "7eleven store 1234", pattern.normalized_merchant
  end

  test "handles merchant names with mixed case and special characters" do
    pattern = LearnedPattern.new(merchant_name: "Amazon.com Services, Inc.", family: @family, category: @category)
    pattern.valid?
    assert_equal "amazoncom services inc", pattern.normalized_merchant
  end

  test "handles merchant names with punctuation" do
    pattern = LearnedPattern.new(merchant_name: "Trader Joe's - San Francisco", family: @family, category: @category)
    pattern.valid?
    assert_equal "trader joes san francisco", pattern.normalized_merchant
  end

  test "handles merchant names with multiple consecutive special characters" do
    pattern = LearnedPattern.new(merchant_name: "Store @@@ $$$", family: @family, category: @category)
    pattern.valid?
    assert_equal "store", pattern.normalized_merchant
  end
end
