require "test_helper"

class FamilyTest < ActiveSupport::TestCase
  include SyncableInterfaceTest, EntriesTestHelper

  def setup
    @syncable = families(:dylan_family)
    @family = families(:dylan_family)
    @category = categories(:food_and_drink)
    @account = @family.accounts.create!(name: "Test", balance: 100, currency: "USD", accountable: Depository.new)
  end

  # Learned pattern methods

  test "learned_pattern_for returns matching pattern" do
    LearnedPattern.create!(merchant_name: "McDonalds", family: @family, category: @category)
    transaction = create_transaction(name: "McDonalds").transaction

    pattern = @family.learned_pattern_for(transaction)

    assert_not_nil pattern
    assert_equal @category, pattern.category
  end

  test "learned_pattern_for returns nil when no pattern matches" do
    transaction = create_transaction(name: "Walmart").transaction

    pattern = @family.learned_pattern_for(transaction)

    assert_nil pattern
  end

  test "learned_pattern_for returns nil for transaction with blank merchant name" do
    transaction = create_transaction(name: "Test").transaction
    transaction.stubs(:merchant_name).returns("")

    pattern = @family.learned_pattern_for(transaction)

    assert_nil pattern
  end

  test "learn_pattern_from creates pattern from transaction" do
    transaction = create_transaction(name: "Starbucks", category: @category).transaction

    assert_difference "@family.learned_patterns.count", 1 do
      pattern = @family.learn_pattern_from!(transaction)
      assert_not_nil pattern
      assert_equal "Starbucks", pattern.merchant_name
      assert_equal @category, pattern.category
    end
  end

  test "learn_pattern_from returns nil for transaction without merchant name" do
    transaction = create_transaction(name: "Test", category: @category).transaction
    transaction.stubs(:merchant_name).returns(nil)

    assert_no_difference "@family.learned_patterns.count" do
      result = @family.learn_pattern_from!(transaction)
      assert_nil result
    end
  end

  test "learn_pattern_from returns nil for transaction without category" do
    transaction = create_transaction(name: "Starbucks").transaction

    assert_no_difference "@family.learned_patterns.count" do
      result = @family.learn_pattern_from!(transaction)
      assert_nil result
    end
  end

  test "learn_pattern_from uses find_or_create_by to avoid duplicates" do
    transaction1 = create_transaction(name: "McDonalds", category: @category).transaction
    transaction2 = create_transaction(name: "MCDONALDS!!!", category: @category).transaction

    assert_difference "@family.learned_patterns.count", 1 do
      @family.learn_pattern_from!(transaction1)
    end

    assert_no_difference "@family.learned_patterns.count" do
      @family.learn_pattern_from!(transaction2)
    end
  end

  test "integration: learning a pattern then finding it" do
    transaction = create_transaction(name: "Target", category: @category).transaction

    # Learn from transaction
    pattern = @family.learn_pattern_from!(transaction)
    assert_not_nil pattern

    # Find the learned pattern
    found_pattern = @family.learned_pattern_for(transaction)
    assert_equal pattern, found_pattern
  end

  test "integration: learned pattern matches similar merchant names" do
    transaction1 = create_transaction(name: "Amazon", category: @category).transaction
    transaction2 = create_transaction(name: "Amazon Web Services").transaction

    # Learn from first transaction
    @family.learn_pattern_from!(transaction1)

    # Should match second transaction with similar name
    pattern = @family.learned_pattern_for(transaction2)
    assert_not_nil pattern
    assert_equal @category, pattern.category
  end

  test "learned patterns are isolated by family" do
    other_family = Family.create!(name: "Other Family")
    other_category = other_family.categories.create!(name: "Other Category")

    # Create pattern in other family
    transaction1 = create_transaction(name: "Walmart", category: other_category).transaction
    transaction1.entry.update!(account: other_family.accounts.create!(name: "Test", balance: 100, currency: "USD", accountable: Depository.new))

    assert_difference "other_family.learned_patterns.count", 1 do
      other_family.learn_pattern_from!(transaction1)
    end

    # The same merchant name in the first family should create a new pattern
    @category2 = @family.categories.create!(name: "Another Category")
    transaction2 = create_transaction(name: "Walmart", category: @category2).transaction

    assert_difference "@family.learned_patterns.count", 1 do
      @family.learn_pattern_from!(transaction2)
    end

    # Verify each family has its own pattern
    assert_equal 1, other_family.learned_patterns.count
    assert_equal 1, @family.learned_patterns.count
    assert_not_equal other_family.learned_patterns.first, @family.learned_patterns.first
  end
end
