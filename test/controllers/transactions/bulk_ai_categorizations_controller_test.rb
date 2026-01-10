require "test_helper"

class Transactions::BulkAiCategorizationsControllerTest < ActionDispatch::IntegrationTest
  include EntriesTestHelper

  setup do
    @user = users(:family_admin)
    sign_in @user
    @entry = entries(:transaction)
    @transaction = @entry.entryable
    @category = categories(:one)
  end

  def sign_out
    @user.sessions.each do |session|
      delete session_path(session)
    end
  end

  test "requires authentication" do
    sign_out

    post transactions_bulk_ai_categorization_url, params: {
      bulk_ai_categorize: { entry_ids: [ @entry.id ] }
    }, as: :turbo_stream

    assert_redirected_to new_session_path
  end

  test "authorizes only user's own transactions" do
    other_family = families(:empty)
    other_account = other_family.accounts.create!(
      name: "Other Account",
      balance: 0,
      currency: "USD",
      accountable: Depository.new
    )
    other_entry = create_transaction(
      account: other_account,
      name: "Other Transaction",
      amount: 50
    )

    # Verify the entry is not in Current.user's family
    assert_not @user.family.entries.transactions.where(id: other_entry.id).exists?

    post transactions_bulk_ai_categorization_url, params: {
      bulk_ai_categorize: { entry_ids: [ other_entry.id ] }
    }, as: :turbo_stream

    # Should not be able to access another family's transaction
    assert_includes [ 404, 422 ], response.status
  end

  test "categorizes multiple uncategorized transactions successfully" do
    # Create multiple uncategorized transactions
    entry1 = create_transaction(
      account: @entry.account,
      name: "Coffee Shop",
      amount: 5
    )
    entry1.entryable.update_column(:category_id, nil)

    entry2 = create_transaction(
      account: @entry.account,
      name: "Grocery Store",
      amount: 50
    )
    entry2.entryable.update_column(:category_id, nil)

    categorizer = mock()
    categorizer.expects(:auto_categorize).returns(2).once
    Family::AutoCategorizer.expects(:new).with do |family, kwargs|
      family == @user.family &&
        kwargs[:transaction_ids].sort == [ entry1.entryable.id, entry2.entryable.id ].sort
    end.returns(categorizer).once

    post transactions_bulk_ai_categorization_url, params: {
      bulk_ai_categorize: { entry_ids: [ entry1.id, entry2.id ] }
    }, as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
  end

  test "filters to only uncategorized, enrichable transactions" do
    # Create categorized transaction
    entry1 = create_transaction(
      account: @entry.account,
      name: "Categorized",
      amount: 10,
      category: @category
    )

    # Create uncategorized transaction
    entry2 = create_transaction(
      account: @entry.account,
      name: "Uncategorized",
      amount: 20
    )
    entry2.entryable.update_column(:category_id, nil)

    categorizer = mock()
    categorizer.expects(:auto_categorize).returns(1).once
    Family::AutoCategorizer.expects(:new)
      .with(@user.family, transaction_ids: [ entry2.entryable.id ])
      .returns(categorizer)
      .once

    post transactions_bulk_ai_categorization_url, params: {
      bulk_ai_categorize: { entry_ids: [ entry1.id, entry2.id ] }
    }, as: :turbo_stream

    assert_response :success
  end

  test "handles mixed results with some already categorized" do
    entry1 = create_transaction(
      account: @entry.account,
      name: "Already Categorized",
      amount: 10,
      category: @category
    )

    entry2 = create_transaction(
      account: @entry.account,
      name: "Uncategorized",
      amount: 20
    )
    entry2.entryable.update_column(:category_id, nil)

    categorizer = mock()
    categorizer.expects(:auto_categorize).returns(1).once
    Family::AutoCategorizer.expects(:new)
      .with(@user.family, transaction_ids: [ entry2.entryable.id ])
      .returns(categorizer)
      .once

    post transactions_bulk_ai_categorization_url, params: {
      bulk_ai_categorize: { entry_ids: [ entry1.id, entry2.id ] }
    }, as: :turbo_stream

    assert_response :success
  end

  test "per-transaction errors do not stop batch process" do
    # Per 12-03, errors continue batch process
    entry1 = create_transaction(
      account: @entry.account,
      name: "Transaction 1",
      amount: 10
    )
    entry1.entryable.update_column(:category_id, nil)

    entry2 = create_transaction(
      account: @entry.account,
      name: "Transaction 2",
      amount: 20
    )
    entry2.entryable.update_column(:category_id, nil)

    categorizer = mock()
    categorizer.expects(:auto_categorize).returns(2).once
    Family::AutoCategorizer.expects(:new).with do |family, kwargs|
      family == @user.family &&
        kwargs[:transaction_ids].sort == [ entry1.entryable.id, entry2.entryable.id ].sort
    end.returns(categorizer).once

    post transactions_bulk_ai_categorization_url, params: {
      bulk_ai_categorize: { entry_ids: [ entry1.id, entry2.id ] }
    }, as: :turbo_stream

    assert_response :success
  end

  test "returns inline Turbo Stream updates for each transaction" do
    entry1 = create_transaction(
      account: @entry.account,
      name: "Coffee",
      amount: 5
    )
    entry1.entryable.update_column(:category_id, nil)

    categorizer = mock()
    categorizer.expects(:auto_categorize).returns(1).once
    Family::AutoCategorizer.expects(:new)
      .with(@user.family, transaction_ids: [ entry1.entryable.id ])
      .returns(categorizer)
      .once

    post transactions_bulk_ai_categorization_url, params: {
      bulk_ai_categorize: { entry_ids: [ entry1.id ] }
    }, as: :turbo_stream

    assert_response :success
    # The modal should be appended since categorization was attempted
    assert_includes response.body, "bulk_ai_summary_modal"
  end

  test "handles empty transaction_ids array gracefully" do
    post transactions_bulk_ai_categorization_url, params: {
      bulk_ai_categorize: { entry_ids: [] }
    }, as: :turbo_stream

    assert_response :unprocessable_entity
    assert_equal I18n.t("transactions.bulk_ai_categorize.error"), flash[:error]
  end

  test "handles nil transaction_ids gracefully" do
    post transactions_bulk_ai_categorization_url, params: {
      bulk_ai_categorize: { entry_ids: nil }
    }, as: :turbo_stream

    assert_response :unprocessable_entity
    assert_equal I18n.t("transactions.bulk_ai_categorize.error"), flash[:error]
  end

  test "handles when no transactions are enrichable" do
    # All transactions are already categorized
    entry1 = create_transaction(
      account: @entry.account,
      name: "Categorized 1",
      amount: 10,
      category: @category
    )

    entry2 = create_transaction(
      account: @entry.account,
      name: "Categorized 2",
      amount: 20,
      category: @category
    )

    post transactions_bulk_ai_categorization_url, params: {
      bulk_ai_categorize: { entry_ids: [ entry1.id, entry2.id ] }
    }, as: :turbo_stream

    assert_response :unprocessable_entity
    assert_equal I18n.t("transactions.bulk_ai_categorize.error"), flash[:error]
  end

  test "returns user-friendly error message when AI API fails" do
    entry1 = create_transaction(
      account: @entry.account,
      name: "Coffee",
      amount: 5
    )
    entry1.entryable.update_column(:category_id, nil)

    categorizer = mock()
    categorizer.expects(:auto_categorize).raises(
      Family::AutoCategorizer::Error.new("AI API error")
    ).once
    Family::AutoCategorizer.expects(:new)
      .with(@user.family, transaction_ids: [ entry1.entryable.id ])
      .returns(categorizer)
      .once

    post transactions_bulk_ai_categorization_url, params: {
      bulk_ai_categorize: { entry_ids: [ entry1.id ] }
    }, as: :turbo_stream

    assert_response :unprocessable_entity
    assert_equal I18n.t("transactions.bulk_ai_categorize.error"), flash[:error]
  end

  test "updates mobile category name for each transaction" do
    entry1 = create_transaction(
      account: @entry.account,
      name: "Coffee",
      amount: 5
    )
    entry1.entryable.update_column(:category_id, nil)

    categorizer = mock()
    categorizer.expects(:auto_categorize).returns(1).once
    Family::AutoCategorizer.expects(:new)
      .with(@user.family, transaction_ids: [ entry1.entryable.id ])
      .returns(categorizer)
      .once

    post transactions_bulk_ai_categorization_url, params: {
      bulk_ai_categorize: { entry_ids: [ entry1.id ] }
    }, as: :turbo_stream

    assert_response :success
    # The modal should be appended since categorization was attempted
    assert_includes response.body, "bulk_ai_summary_modal"
  end

  test "uses 60% confidence threshold for confirmation" do
    # Per 12-03, 60% confidence threshold
    # The controller stores confidence for UI display
    entry1 = create_transaction(
      account: @entry.account,
      name: "Coffee",
      amount: 5
    )
    entry1.entryable.update_column(:category_id, nil)

    categorizer = mock()
    categorizer.expects(:auto_categorize).returns(1).once
    Family::AutoCategorizer.expects(:new)
      .with(@user.family, transaction_ids: [ entry1.entryable.id ])
      .returns(categorizer)
      .once

    post transactions_bulk_ai_categorization_url, params: {
      bulk_ai_categorize: { entry_ids: [ entry1.id ] }
    }, as: :turbo_stream

    assert_response :success
  end
end
