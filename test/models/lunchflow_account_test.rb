require "test_helper"

class LunchflowAccountTest < ActiveSupport::TestCase
  setup do
    @connection = lunchflow_connections(:dylan_lunchflow)
  end

  test "belongs to lunchflow_connection" do
    account = LunchflowAccount.new(
      lunchflow_connection: @connection,
      lunchflow_id: 123,
      name: "Checking",
      institution_name: "Chase",
      provider: "plaid",
      currency: "USD",
      status: "ACTIVE"
    )
    assert account.valid?
  end

  test "requires lunchflow_id to be unique" do
    LunchflowAccount.create!(
      lunchflow_connection: @connection,
      lunchflow_id: 123,
      name: "Checking",
      institution_name: "Chase",
      provider: "plaid",
      currency: "USD",
      status: "ACTIVE"
    )

    duplicate = LunchflowAccount.new(
      lunchflow_connection: @connection,
      lunchflow_id: 123,
      name: "Savings",
      institution_name: "Chase",
      provider: "plaid",
      currency: "USD",
      status: "ACTIVE"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:lunchflow_id], "has already been taken"
  end

  test "account association is optional" do
    account = LunchflowAccount.new(
      lunchflow_connection: @connection,
      lunchflow_id: 456,
      name: "Savings",
      institution_name: "Chase",
      provider: "plaid",
      currency: "USD",
      status: "ACTIVE",
      account: nil
    )
    assert account.valid?
  end

  test "ensure_account! detects Investment type from account name" do
    lunchflow_account = lunchflow_accounts(:investment_401k)

    account = lunchflow_account.ensure_account!

    assert_equal "Investment", account.accountable_type
    assert_instance_of Investment, account.accountable
  end

  test "ensure_account! detects Depository/checking from checking keyword" do
    lunchflow_account = lunchflow_accounts(:dylan_checking)

    account = lunchflow_account.ensure_account!

    assert_equal "Depository", account.accountable_type
    assert_equal "checking", account.subtype
  end
end
