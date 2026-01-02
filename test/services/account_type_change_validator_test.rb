# test/services/account_type_change_validator_test.rb
require "test_helper"

class AccountTypeChangeValidatorTest < ActiveSupport::TestCase
  test "allows change from Depository to CreditCard with no holdings" do
    account = accounts(:depository)
    validator = AccountTypeChangeValidator.new(account, "Depository", "CreditCard")
    assert validator.valid?
  end

  test "allows change from Investment to Crypto with holdings" do
    account = accounts(:investment)
    assert account.holdings.exists?

    validator = AccountTypeChangeValidator.new(account, "Investment", "Crypto")
    assert validator.valid?
  end

  test "rejects change from Investment to Depository with holdings" do
    account = accounts(:investment)
    assert account.holdings.exists?

    validator = AccountTypeChangeValidator.new(account, "Investment", "Depository")
    assert_not validator.valid?
    assert_match /has investment holdings/, validator.error_message
  end
end
