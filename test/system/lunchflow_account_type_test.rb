require "application_system_test_case"

class LunchflowAccountTypeTest < ApplicationSystemTestCase
  setup do
    @user = users(:family_admin)
    sign_in @user
    @account = accounts(:lunchflow_checking_account)
  end

  test "changing account type via edit form" do
    visit edit_account_path(@account)

    assert_selector "h3", text: "Lunchflow Account Type"

    find("#account_accountable_type").select("Credit Cards")
    click_on "Update Account"

    assert_text "Account type updated successfully"
    assert_equal "CreditCard", @account.reload.accountable_type
  end

  test "changing account subtype" do
    visit edit_account_path(@account)

    select "Cash", from: "Account Type"
    # Use all().first to handle ambiguity
    all("#account_subtype").first.select("Savings")
    click_on "Update Account"

    assert_text "updated successfully"
    assert_equal "savings", @account.reload.subtype
  end
end
