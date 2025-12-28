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
end
