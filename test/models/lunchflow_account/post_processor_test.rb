require "test_helper"

class LunchflowAccount::PostProcessorTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @family = families(:dylan_family)
    @account = accounts(:depository)

    @lunchflow_account = LunchflowAccount.create!(
      lunchflow_item: lunchflow_items(:one),
      account_id: "test-account",
      name: "Test Account",
      currency: "USD"
    )

    # Create account_provider to link lunchflow_account to account
    @account_provider = AccountProvider.create!(
      account: @account,
      provider: @lunchflow_account
    )

    # Reload to ensure associations are loaded
    @lunchflow_account.reload

    # Clear any enqueued jobs before each test
    clear_enqueued_jobs
    clear_performed_jobs
  end

  test "triggers AI categorization when ai_categorize_on_sync is enabled" do
    Setting.ai_categorize_on_sync = true

    # Create an uncategorized transaction
    transaction = Transaction.create!
    @account.entries.create!(
      date: Date.current,
      amount: -10,
      currency: "USD",
      name: "Test",
      entryable: transaction
    )

    assert_enqueued_jobs(1, only: AutoCategorizeJob) do
      LunchflowAccount::PostProcessor.new(@lunchflow_account).process([ transaction.id ])
    end
  end

  test "does not trigger AI categorization when ai_categorize_on_sync is disabled" do
    Setting.ai_categorize_on_sync = false

    transaction = Transaction.create!
    @account.entries.create!(
      date: Date.current,
      amount: -10,
      currency: "USD",
      name: "Test",
      entryable: transaction
    )

    assert_no_enqueued_jobs(only: AutoCategorizeJob) do
      LunchflowAccount::PostProcessor.new(@lunchflow_account).process([ transaction.id ])
    end
  end

  test "does not categorize transactions that already have categories" do
    Setting.ai_categorize_on_sync = true

    category = categories(:one)
    transaction = Transaction.create!(category: category)
    @account.entries.create!(
      date: Date.current,
      amount: -10,
      currency: "USD",
      name: "Test",
      entryable: transaction
    )

    assert_no_enqueued_jobs(only: AutoCategorizeJob) do
      LunchflowAccount::PostProcessor.new(@lunchflow_account).process([ transaction.id ])
    end
  end

  test "skips transactions with locked category_id" do
    Setting.ai_categorize_on_sync = true

    transaction = Transaction.create!
    @account.entries.create!(
      date: Date.current,
      amount: -10,
      currency: "USD",
      name: "Test",
      entryable: transaction
    )

    # Lock the category_id
    transaction.lock_attr!(:category_id)

    assert_no_enqueued_jobs(only: AutoCategorizeJob) do
      LunchflowAccount::PostProcessor.new(@lunchflow_account).process([ transaction.id ])
    end
  end

  test "returns early when no linked account" do
    Setting.ai_categorize_on_sync = true

    # Create a lunchflow_account without a linked account
    unlinked_account = LunchflowAccount.create!(
      lunchflow_item: lunchflow_items(:one),
      account_id: "unlinked-account",
      name: "Unlinked Account",
      currency: "USD"
    )

    assert_no_enqueued_jobs(only: AutoCategorizeJob) do
      LunchflowAccount::PostProcessor.new(unlinked_account).process([ 1 ])
    end
  end

  test "handles empty transaction IDs array" do
    Setting.ai_categorize_on_sync = true

    assert_no_enqueued_jobs(only: AutoCategorizeJob) do
      LunchflowAccount::PostProcessor.new(@lunchflow_account).process([])
    end
  end

  test "handles mix of categorized and uncategorized transactions" do
    Setting.ai_categorize_on_sync = true

    category = categories(:one)

    categorized_transaction = Transaction.create!(category: category)
    @account.entries.create!(
      date: Date.current,
      amount: -10,
      currency: "USD",
      name: "Categorized",
      entryable: categorized_transaction
    )

    uncategorized_transaction = Transaction.create!
    @account.entries.create!(
      date: Date.current,
      amount: -10,
      currency: "USD",
      name: "Uncategorized",
      entryable: uncategorized_transaction
    )

    # Should only trigger for the uncategorized one
    assert_enqueued_jobs(1, only: AutoCategorizeJob) do
      LunchflowAccount::PostProcessor.new(@lunchflow_account).process([ categorized_transaction.id, uncategorized_transaction.id ])
    end
  end
end
