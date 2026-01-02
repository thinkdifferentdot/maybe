require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
    @account = accounts(:depository)
  end

  test "should get index" do
    get accounts_url
    assert_response :success
  end

  test "should get show" do
    get account_url(@account)
    assert_response :success
  end

  test "should sync account" do
    post sync_account_url(@account)
    assert_redirected_to account_url(@account)
  end

  test "should get sparkline" do
    get sparkline_account_url(@account)
    assert_response :success
  end

  test "destroys account" do
    delete account_url(@account)
    assert_redirected_to accounts_path
    assert_enqueued_with job: DestroyJob
    assert_equal "Account scheduled for deletion", flash[:notice]
  end

  test "subtypes returns JSON for Depository" do
    get subtypes_accounts_path, params: { type: "Depository" }

    assert_response :success
    json = JSON.parse(response.body)
    assert json.is_a?(Array)
    assert json.any? { |subtype| subtype[0] == "Checking" && subtype[1] == "checking" }
  end

  test "subtypes returns empty array for types without subtypes" do
    get subtypes_accounts_path, params: { type: "Crypto" }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal [], json
  end

  test "subtypes returns empty array for invalid type" do
    get subtypes_accounts_path, params: { type: "InvalidType" }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal [], json
  end
end
