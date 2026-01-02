require "test_helper"

class AccountTest < ActiveSupport::TestCase
  include SyncableInterfaceTest, EntriesTestHelper

  setup do
    @account = @syncable = accounts(:depository)
    @family = families(:dylan_family)
  end

  test "can destroy" do
    assert_difference "Account.count", -1 do
      @account.destroy
    end
  end

  test "gets short/long subtype label" do
    account = @family.accounts.create!(
      name: "Test Investment",
      balance: 1000,
      currency: "USD",
      subtype: "hsa",
      accountable: Investment.new
    )

    assert_equal "HSA", account.short_subtype_label
    assert_equal "Health Savings Account", account.long_subtype_label

    # Test with nil subtype
    account.update!(subtype: nil)
    assert_equal "Investments", account.short_subtype_label
    assert_equal "Investments", account.long_subtype_label
  end

  test "change_accountable_type! successfully changes type" do
    account = accounts(:depository)
    original_accountable_id = account.accountable_id

    assert_equal "Depository", account.accountable_type

    assert account.change_accountable_type!("CreditCard")

    account.reload
    assert_equal "CreditCard", account.accountable_type
    assert_instance_of CreditCard, account.accountable
    assert_not_equal original_accountable_id, account.accountable_id
  end

  test "change_accountable_type! preserves transactions" do
    account = accounts(:depository)
    # Create a transaction
    account.entries.create!(
      date: Date.current,
      amount: 100,
      currency: "USD",
      name: "Test Entry",
      entryable: Transaction.create!
    )

    transaction_count = account.transactions.count

    account.change_accountable_type!("CreditCard")

    assert_equal transaction_count, account.reload.transactions.count
  end

  test "change_accountable_type! allows subtype change for same type" do
    account = accounts(:depository)
    account.update!(subtype: "checking")

    assert account.change_accountable_type!("Depository", "savings")
    assert_equal "Depository", account.accountable_type
    assert_equal "savings", account.subtype
  end
end
