require "test_helper"

class Family::AutoCategorizerTest < ActiveSupport::TestCase
  include EntriesTestHelper, ProviderTestHelper

  setup do
    @family = families(:dylan_family)
    @account = @family.accounts.create!(name: "Rule test", balance: 100, currency: "USD", accountable: Depository.new)
    @llm_provider = mock
  end

  test "auto-categorizes transactions" do
    setup_provider_mock("openai")

    txn1 = create_transaction(account: @account, name: "McDonalds").transaction
    txn2 = create_transaction(account: @account, name: "Amazon purchase").transaction
    txn3 = create_transaction(account: @account, name: "Netflix subscription").transaction

    test_category = @family.categories.create!(name: "Test category")

    provider_response = provider_success_response([
      AutoCategorization.new(transaction_id: txn1.id, category_name: test_category.name),
      AutoCategorization.new(transaction_id: txn2.id, category_name: test_category.name),
      AutoCategorization.new(transaction_id: txn3.id, category_name: nil)
    ])

    @llm_provider.expects(:auto_categorize).returns(provider_response).once

    assert_difference "DataEnrichment.count", 2 do
      Family::AutoCategorizer.new(@family, transaction_ids: [ txn1.id, txn2.id, txn3.id ]).auto_categorize
    end

    assert_equal test_category, txn1.reload.category
    assert_equal test_category, txn2.reload.category
    assert_nil txn3.reload.category

    # After auto-categorization, only successfully categorized transactions are locked
    # txn3 remains enrichable since it didn't get a category (allows retry)
    assert_equal 1, @account.transactions.reload.enrichable(:category_id).count
  end

  test "stores confidence score in transaction extra metadata" do
    setup_provider_mock("openai")

    txn1 = create_transaction(account: @account, name: "McDonalds").transaction
    test_category = @family.categories.create!(name: "Test category")

    # Create a mock categorization result with confidence
    categorization_with_confidence = Struct.new(:transaction_id, :category_name, :confidence).new(
      txn1.id, test_category.name, 0.85
    )

    provider_response = provider_success_response([
      categorization_with_confidence
    ])

    @llm_provider.expects(:auto_categorize).returns(provider_response).once

    Family::AutoCategorizer.new(@family, transaction_ids: [ txn1.id ]).auto_categorize

    # Confidence should be stored in transaction's extra metadata
    assert_equal 0.85, txn1.reload.extra["ai_categorization_confidence"]
  end

  test "stores default confidence when provider does not return confidence" do
    setup_provider_mock("openai")

    txn1 = create_transaction(account: @account, name: "McDonalds").transaction
    test_category = @family.categories.create!(name: "Test category")

    # Standard AutoCategorization without confidence attribute
    provider_response = provider_success_response([
      AutoCategorization.new(transaction_id: txn1.id, category_name: test_category.name)
    ])

    @llm_provider.expects(:auto_categorize).returns(provider_response).once

    Family::AutoCategorizer.new(@family, transaction_ids: [ txn1.id ]).auto_categorize

    # Default confidence of 1.0 should be stored
    assert_equal 1.0, txn1.reload.extra["ai_categorization_confidence"]
  end

  test "uses configured provider from Setting.llm_provider" do
    anthropic_provider = mock
    Setting.stubs(:llm_provider).returns("anthropic")

    registry = mock("llm_registry")
    registry.stubs(:get_provider).with("anthropic").returns(anthropic_provider)

    Provider::Registry.stubs(:for_concept).with(:llm).returns(registry)

    txn1 = create_transaction(account: @account, name: "McDonalds").transaction
    test_category = @family.categories.create!(name: "Test category")

    provider_response = provider_success_response([
      AutoCategorization.new(transaction_id: txn1.id, category_name: test_category.name)
    ])

    anthropic_provider.expects(:auto_categorize).returns(provider_response).once

    Family::AutoCategorizer.new(@family, transaction_ids: [ txn1.id ]).auto_categorize

    assert_equal test_category, txn1.reload.category
  end

  test "defaults to openai provider when Setting.llm_provider is nil" do
    Setting.stubs(:llm_provider).returns(nil)

    registry = mock("llm_registry")
    registry.stubs(:get_provider).with("openai").returns(@llm_provider)

    Provider::Registry.stubs(:for_concept).with(:llm).returns(registry)

    txn1 = create_transaction(account: @account, name: "McDonalds").transaction
    test_category = @family.categories.create!(name: "Test category")

    provider_response = provider_success_response([
      AutoCategorization.new(transaction_id: txn1.id, category_name: test_category.name)
    ])

    @llm_provider.expects(:auto_categorize).returns(provider_response).once

    Family::AutoCategorizer.new(@family, transaction_ids: [ txn1.id ]).auto_categorize

    assert_equal test_category, txn1.reload.category
  end

  test "Result struct has confidence attribute" do
    result = Family::AutoCategorizer::Result.new(
      transaction_id: 123,
      category_name: "Test",
      confidence: 0.92
    )

    assert_equal 123, result.transaction_id
    assert_equal "Test", result.category_name
    assert_equal 0.92, result.confidence
  end

  test "Result struct defaults confidence to 1.0" do
    result = Family::AutoCategorizer::Result.new(
      transaction_id: 123,
      category_name: "Test"
    )

    assert_equal 1.0, result.confidence
  end

  private
    AutoCategorization = Provider::LlmConcept::AutoCategorization

    def setup_provider_mock(provider_name)
      registry = mock("llm_registry")
      registry.stubs(:get_provider).with(provider_name).returns(@llm_provider)

      Provider::Registry.stubs(:for_concept).with(:llm).returns(registry)
      Setting.stubs(:llm_provider).returns(provider_name)
    end
end
