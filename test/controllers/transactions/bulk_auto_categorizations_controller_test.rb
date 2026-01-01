require "test_helper"

class Transactions::BulkAutoCategorizationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
    @family = @user.family
    @account = @family.accounts.first
  end

  test "preview returns JSON error when no LLM provider configured" do
    transaction = entries(:transaction).entryable

    Family::AutoCategorizer.any_instance
      .expects(:preview_categorizations)
      .raises(Family::AutoCategorizer::Error, "No LLM provider")

    post preview_transactions_bulk_auto_categorization_path,
         params: { entry_ids: [transaction.entry.id].to_json },
         as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "No LLM provider", json["error"]
  end
end
