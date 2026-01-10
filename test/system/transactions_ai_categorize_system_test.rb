require "application_system_test_case"

class TransactionsAiCategorizeSystemTest < ApplicationSystemTestCase
  include EntriesTestHelper

  setup do
    sign_in @user = users(:family_admin)

    # Create test account
    @account = @user.family.accounts.create!(
      name: "Test Account",
      balance: 0,
      currency: "USD",
      accountable: Depository.new
    )

    # Create uncategorized transaction
    @entry = create_transaction(
      account: @account,
      name: "Coffee Shop",
      amount: 5.50,
      date: Date.current
    )
    @entry.entryable.update_column(:category_id, nil)

    visit transactions_url
  end

  test "individual AI categorize button visible and has correct attributes" do
    transaction = @entry.entryable

    # Find the AI categorize button for the uncategorized transaction
    within "##{dom_id(@entry)}" do
      find_button = find("button[data-controller='ai-categorize'][data-ai-categorize-transaction-id-value='#{transaction.id}']")
      assert find_button, "AI categorize button should be visible"

      # Verify button has correct data attributes for Stimulus controller
      assert_equal "ai-categorize", find_button[:'data-controller']
      assert_equal transaction.id.to_s, find_button[:'data-ai-categorize-transaction-id-value']
      assert find_button[:'data-action']&.include?("click->ai-categorize#categorize")

      # Verify button has the sparkles icon
      assert_selector "button[data-controller='ai-categorize'] svg"
    end
  end

  test "AI categorize button is visible for uncategorized transactions" do
    transaction = @entry.entryable

    # Verify AI categorize button exists for uncategorized transaction
    within "##{dom_id(@entry)}" do
      assert_selector "button[data-controller='ai-categorize'][data-ai-categorize-transaction-id-value='#{transaction.id}']",
                     count: 1
    end
  end

  test "AI categorize button remains visible for already categorized transactions" do
    # Per 12-02, button is always visible to allow re-categorization
    category = @user.family.categories.first || @user.family.categories.create!(
      name: "Coffee",
      color: "#8B4513",
      classification: "expense"
    )

    categorized_entry = create_transaction(
      account: @account,
      name: "Categorized Transaction",
      amount: 10,
      category: category
    )

    visit transactions_url

    # Verify AI categorize button exists even for categorized transaction
    within "##{dom_id(categorized_entry)}" do
      assert_selector "button[data-controller='ai-categorize']"
    end
  end

  test "approve and reject buttons appear for AI-categorized transactions" do
    category = @user.family.categories.first || @user.family.categories.create!(
      name: "Coffee",
      color: "#8B4513",
      classification: "expense"
    )

    # Simulate an AI-categorized transaction
    entry = create_transaction(
      account: @account,
      name: "AI Categorized",
      amount: 10,
      category: category
    )

    transaction = entry.entryable
    transaction.data_enrichments.create!(
      source: "ai",
      attribute_name: "category_id",
      value: category.id.to_s
    )

    visit transactions_url

    # Verify approve button exists for AI-categorized transaction
    # Note: button_to creates a form with an input, so we check for the form/action
    within "##{dom_id(entry)}" do
      # Check for the approve form/action
      assert_selector "form[action='#{approve_ai_transaction_path(entry.id)}']"
      # Check for the reject form/action
      assert_selector "form[action='#{reject_ai_transaction_path(entry.id)}']"
    end
  end

  test "bulk AI categorize selection works" do
    # The bulk selection UI should be available
    # Checkboxes should be present for each transaction
    assert_selector "input[type='checkbox'][data-bulk-select-target='row']"
  end

  test "uncategorized transactions show correctly in UI" do
    # Verify the uncategorized transaction is visible
    assert_selector "##{dom_id(@entry)}"

    # The uncategorized transaction should show "Uncategorized" badge
    within "##{dom_id(@entry)}" do
      assert_text "Uncategorized"
    end
  end
end
