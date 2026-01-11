# frozen_string_literal: true

require "test_helper"

# Test class that includes the FewShotExamples concern for testing
class FewShotExamplesTestClass
  include Provider::Concerns::FewShotExamples

  attr_accessor :user_categories, :family

  def initialize(user_categories:, family: nil)
    @user_categories = user_categories
    @family = family
  end

  # Expose private methods for testing
  def build_few_shot_examples_public
    build_few_shot_examples
  end

  def static_examples_public
    static_examples
  end

  def dynamic_examples_public
    dynamic_examples
  end

  def category_exists_public(name)
    category_exists?(name)
  end

  def format_few_shot_examples_public(examples)
    format_few_shot_examples(examples)
  end

  def build_few_shot_examples_text_public
    build_few_shot_examples_text
  end
end

class Provider::Concerns::FewShotExamplesTest < ActiveSupport::TestCase
  setup do
    @user_categories = [
      { id: "groceries_id", name: "Groceries", is_subcategory: false, parent_id: nil, classification: "expense" },
      { id: "gas_id", name: "Gas & Fuel", is_subcategory: false, parent_id: nil, classification: "expense" },
      { id: "coffee_id", name: "Coffee Shops", is_subcategory: false, parent_id: nil, classification: "expense" },
      { id: "streaming_id", name: "Streaming Services", is_subcategory: false, parent_id: nil, classification: "expense" },
      { id: "restaurants_id", name: "Restaurants", is_subcategory: false, parent_id: nil, classification: "expense" },
      { id: "income_id", name: "Income", is_subcategory: false, parent_id: nil, classification: "income" }
    ]
  end

  # Tests for static_examples

  test "static_examples returns all 5 examples when all categories exist" do
    instance = FewShotExamplesTestClass.new(user_categories: @user_categories)
    examples = instance.static_examples_public

    assert_equal 5, examples.size
    assert_equal "WHOLE FOODS MARKET", examples[0][:description]
    assert_equal "Groceries", examples[0][:category]
    assert_equal "SHELL SERVICE STATION", examples[1][:description]
    assert_equal "Gas & Fuel", examples[1][:category]
    assert_equal "STARBUCKS", examples[2][:description]
    assert_equal "Coffee Shops", examples[2][:category]
    assert_equal "NETFLIX", examples[3][:description]
    assert_equal "Streaming Services", examples[3][:category]
    assert_equal "CHIPOTLE", examples[4][:description]
    assert_equal "Restaurants", examples[4][:category]
  end

  test "static_examples filters to user's available categories" do
    limited_categories = [
      { id: "groceries_id", name: "Groceries", is_subcategory: false, parent_id: nil, classification: "expense" },
      { id: "restaurants_id", name: "Restaurants", is_subcategory: false, parent_id: nil, classification: "expense" }
    ]

    instance = FewShotExamplesTestClass.new(user_categories: limited_categories)
    examples = instance.static_examples_public

    assert_equal 2, examples.size
    assert_equal "WHOLE FOODS MARKET", examples[0][:description]
    assert_equal "Groceries", examples[0][:category]
    assert_equal "CHIPOTLE", examples[1][:description]
    assert_equal "Restaurants", examples[1][:category]
  end

  test "static_examples returns empty array when no matching categories" do
    unrelated_categories = [
      { id: "other_id", name: "Other", is_subcategory: false, parent_id: nil, classification: "expense" }
    ]

    instance = FewShotExamplesTestClass.new(user_categories: unrelated_categories)
    examples = instance.static_examples_public

    assert_equal [], examples
  end

  # Tests for category_exists?

  test "category_exists returns true when category name matches" do
    instance = FewShotExamplesTestClass.new(user_categories: @user_categories)

    assert instance.category_exists_public("Groceries")
    assert instance.category_exists_public("Gas & Fuel")
    assert instance.category_exists_public("Coffee Shops")
  end

  test "category_exists returns false when category name not found" do
    instance = FewShotExamplesTestClass.new(user_categories: @user_categories)

    assert_not instance.category_exists_public("Travel")
    assert_not instance.category_exists_public("Entertainment")
  end

  # Tests for dynamic_examples

  test "dynamic_examples returns empty array when family is nil" do
    instance = FewShotExamplesTestClass.new(user_categories: @user_categories, family: nil)
    examples = instance.dynamic_examples_public

    assert_equal [], examples
  end

  test "dynamic_examples returns empty array when family has no patterns" do
    family = families(:empty)
    instance = FewShotExamplesTestClass.new(user_categories: @user_categories, family: family)
    examples = instance.dynamic_examples_public

    assert_equal [], examples
  end

  test "dynamic_examples returns diverse examples from learned patterns" do
    family = families(:dylan_family)
    groceries = categories(:one) # Use existing fixture as groceries
    restaurants = categories(:subcategory)

    # Create learned patterns for testing
    pattern1 = LearnedPattern.create!(family: family, category: groceries, merchant_name: "WHOLE FOODS")
    pattern2 = LearnedPattern.create!(family: family, category: restaurants, merchant_name: "MCDONALDS")
    pattern3 = LearnedPattern.create!(family: family, category: groceries, merchant_name: "TRADER JOES") # Same category as pattern1

    instance = FewShotExamplesTestClass.new(user_categories: @user_categories, family: family)
    examples = instance.dynamic_examples_public

    # Should return at most 1 example per category (so 2 total: groceries and restaurants)
    assert examples.size <= 3
    assert examples.any? { |ex| ex[:category] == groceries.name }
    assert examples.any? { |ex| ex[:category] == restaurants.name }

    # Cleanup
    LearnedPattern.delete(pattern1.id)
    LearnedPattern.delete(pattern2.id)
    LearnedPattern.delete(pattern3.id)
  end

  # Tests for format_few_shot_examples

  test "format_few_shot_examples returns empty string for empty array" do
    instance = FewShotExamplesTestClass.new(user_categories: @user_categories)
    result = instance.format_few_shot_examples_public([])

    assert_equal "", result
  end

  test "format_few_shot_examples formats examples correctly" do
    instance = FewShotExamplesTestClass.new(user_categories: @user_categories)
    examples = [
      { description: "WHOLE FOODS", category: "Groceries" },
      { description: "SHELL", category: "Gas & Fuel" }
    ]
    result = instance.format_few_shot_examples_public(examples)

    expected = "Transaction: WHOLE FOODS \u2192 Category: Groceries\nTransaction: SHELL \u2192 Category: Gas & Fuel"
    assert_equal expected, result
  end

  # Tests for build_few_shot_examples

  test "build_few_shot_examples returns static examples when no family" do
    instance = FewShotExamplesTestClass.new(user_categories: @user_categories, family: nil)
    examples = instance.build_few_shot_examples_public

    assert_equal 5, examples.size
    assert examples.all? { |ex| ex.key?(:description) && ex.key?(:category) }
  end

  test "build_few_shot_examples combines static and dynamic examples" do
    family = families(:dylan_family)
    groceries = categories(:one)

    # Create a learned pattern for a category not in static examples
    pattern = LearnedPattern.create!(family: family, category: groceries, merchant_name: "CUSTOM MERCHANT")

    instance = FewShotExamplesTestClass.new(user_categories: @user_categories, family: family)
    examples = instance.build_few_shot_examples_public

    # Should have 5 static + 1 dynamic (at most)
    assert examples.size >= 5
    assert examples.any? { |ex| ex[:description] == "CUSTOM MERCHANT" }

    # Cleanup
    LearnedPattern.delete(pattern.id)
  end

  # Tests for build_few_shot_examples_text

  test "build_few_shot_examples_text returns empty string when no examples" do
    unrelated_categories = [
      { id: "other_id", name: "Other", is_subcategory: false, parent_id: nil, classification: "expense" }
    ]
    instance = FewShotExamplesTestClass.new(user_categories: unrelated_categories, family: nil)
    result = instance.build_few_shot_examples_text_public

    assert_equal "", result
  end

  test "build_few_shot_examples_text returns formatted text with EXAMPLES header" do
    instance = FewShotExamplesTestClass.new(user_categories: @user_categories, family: nil)
    result = instance.build_few_shot_examples_text_public

    assert_includes result, "EXAMPLES:"
    assert_includes result, "Transaction: WHOLE FOODS MARKET \u2192 Category: Groceries"
    assert_includes result, "Transaction: SHELL SERVICE STATION \u2192 Category: Gas & Fuel"
  end
end
