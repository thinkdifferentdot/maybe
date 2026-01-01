require "test_helper"

class Transactions::BulkAutoCategorizationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
    @family = @user.family
    @account = @family.accounts.first
  end

  test "preview returns JSON error when no LLM provider configured" do
    transactions = [
      @family.entries.where(entryable_type: "Transaction").first.entryable
    ]

    Family::AutoCategorizer.any_instance
      .expects(:preview_categorizations)
      .raises(Family::AutoCategorizer::Error, "No LLM provider")

    post preview_transactions_bulk_auto_categorization_path,
         params: { entry_ids: transactions.map { |t| t.entry.id }.to_json },
         as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "No LLM provider", json["error"]
  end

  test "create applies selected predictions" do
    transaction1 = @family.entries.where(entryable_type: "Transaction").first.entryable
    transaction1.update!(category: nil)

    groceries_category = @family.categories.find_or_create_by!(name: "Groceries")

    predictions = [
      { entry_id: transaction1.entry.id, category_id: groceries_category.id }.to_json
    ]

    post transactions_bulk_auto_categorization_path, params: { predictions: predictions }

    assert_redirected_to transactions_path
    assert_match /Successfully categorized 1 transaction/, flash[:notice]

    assert_equal groceries_category.id, transaction1.reload.category_id
  end

  test "create handles empty predictions array" do
    post transactions_bulk_auto_categorization_path, params: { predictions: [] }

    assert_redirected_to transactions_path
    assert_match /No categorizations selected/, flash[:alert]
  end

  test "preview rejects selection exceeding batch size" do
    original_batch_size = Setting.categorization_batch_size
    Setting.categorization_batch_size = 10

    # Create 11 transactions
    11.times do |i|
      Entry.create!(
        name: "Txn #{i}",
        amount: -10,
        currency: "USD",
        date: Date.today,
        account: @account,
        entryable: Transaction.new(category: nil)
      )
    end
    
    transactions = @family.entries.where(entryable_type: "Transaction").limit(11).map(&:entryable)

    post preview_transactions_bulk_auto_categorization_path,
         params: { entry_ids: transactions.map { |t| t.entry.id }.to_json },
         as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_match /Cannot categorize more than 10/, json["error"]
  ensure
    Setting.categorization_batch_size = original_batch_size
  end

  test "create only applies checked predictions" do
    transaction1 = @family.entries.where(entryable_type: "Transaction").first.entryable
    transaction2 = @family.entries.where(entryable_type: "Transaction").second.entryable
    transaction1.update!(category: nil)
    transaction2.update!(category: nil)

    groceries_category = @family.categories.find_or_create_by!(name: "Groceries")

    # Only include transaction1 in predictions (user unchecked transaction2)
    predictions = [
      { entry_id: transaction1.entry.id, category_id: groceries_category.id }.to_json
    ]

    post transactions_bulk_auto_categorization_path, params: { predictions: predictions }

    assert_equal groceries_category.id, transaction1.reload.category_id
    assert_nil transaction2.reload.category_id
  end
end
