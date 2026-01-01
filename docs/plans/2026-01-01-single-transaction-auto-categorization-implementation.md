# Single Transaction Auto-Categorization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable users to select specific transactions from the list, preview AI-suggested categories, and selectively apply categorizations.

**Architecture:** Adds preview modal with Stimulus controller for async predictions, new controller endpoints for preview/apply, and extends Family::AutoCategorizer with non-destructive preview method.

**Tech Stack:** Rails 7, Hotwire (Turbo + Stimulus), ViewComponents, Minitest

---

## Progress Tracker

- [x] Task 1: Add Routes
- [x] Task 2: Create Controller with Preview Action
- [x] Task 3: Add preview_categorizations Method to Family::AutoCategorizer
- [ ] Task 4: Add Create Action to Controller
- [ ] Task 5: Create Stimulus Controller
- [ ] Task 6: Create Preview Modal Partial
- [ ] Task 7: Add Auto-Categorize Button to Selection Bar
- [ ] Task 8: Include Modal in Transactions Index
- [ ] Task 9: Add Controller Tests for Edge Cases
- [ ] Task 10: Add Model Tests for preview_categorizations
- [ ] Task 11: Run Full Test Suite
- [ ] Task 12: Manual Testing (Optional)
- [ ] Task 13: Final Commit and Summary

---

## Task 1: Add Routes

**Files:**
- Modify: `config/routes.rb` (around line 125-128)

**Step 1: Add bulk auto-categorization routes**

Add the new resource inside the `namespace :transactions` block:

```ruby
namespace :transactions do
  resource :bulk_deletion, only: :create
  resource :bulk_update, only: %i[new create]
  resource :bulk_auto_categorization, only: [:create] do
    post :preview, on: :collection
  end
end
```

**Step 2: Verify routes**

Run: `bin/rails routes | grep bulk_auto_categorization`

Expected output:
```
preview_transactions_bulk_auto_categorization POST   /transactions/bulk_auto_categorization/preview(.:format)
        transactions_bulk_auto_categorization POST   /transactions/bulk_auto_categorization(.:format)
```

**Step 3: Commit**

```bash
git add config/routes.rb
git commit -m "feat: add routes for bulk auto-categorization"
```

---

## Task 2: Create Controller with Preview Action

**Files:**
- Create: `app/controllers/transactions/bulk_auto_categorizations_controller.rb`
- Create: `test/controllers/transactions/bulk_auto_categorizations_controller_test.rb`

**Step 1: Write failing controller test**

Create test file with preview endpoint test:

```ruby
require "test_helper"

class Transactions::BulkAutoCategorizationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
    @family = @user.family
    @account = @family.accounts.first
  end

  test "preview returns JSON error when no LLM provider configured" do
    transactions = [
      @family.entries.first.entryable
    ]

    Family::AutoCategorizer.any_instance
      .expects(:preview_categorizations)
      .raises(Family::AutoCategorizer::Error, "No LLM provider")

    post preview_transactions_bulk_auto_categorization_path,
         params: { entry_ids: transactions.map(&:entry_id).to_json },
         as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "No LLM provider", json["error"]
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/transactions/bulk_auto_categorizations_controller_test.rb`

Expected: FAIL with "uninitialized constant Transactions::BulkAutoCategorizationsController"

**Step 3: Create controller**

```ruby
class Transactions::BulkAutoCategorizationsController < ApplicationController
  before_action :set_transactions, only: [:preview]
  before_action :validate_batch_size, only: [:preview]

  def preview
    categorizer = Family::AutoCategorizer.new(
      Current.family,
      transaction_ids: @transactions.pluck(:id)
    )

    predictions = categorizer.preview_categorizations

    render json: {
      predictions: predictions.map do |prediction|
        {
          entry_id: prediction[:transaction].entry.id,
          transaction_name: prediction[:transaction].entry.name,
          account_name: prediction[:transaction].entry.account.name,
          amount: helpers.format_money(-prediction[:transaction].entry.amount_money),
          category_id: prediction[:category]&.id,
          category_name: prediction[:category]&.name,
          confidence: prediction[:confidence]
        }
      end
    }
  rescue Family::AutoCategorizer::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_transactions
    entry_ids = JSON.parse(params[:entry_ids] || "[]")
    @transactions = Current.family.transactions
                                  .joins(:entry)
                                  .where(entries: { id: entry_ids })
  end

  def validate_batch_size
    max_size = Setting.categorization_batch_size

    if @transactions.count > max_size
      render json: {
        error: "Cannot categorize more than #{max_size} transactions at once. Please adjust your selection or increase batch size in settings."
      }, status: :unprocessable_entity
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bin/rails test test/controllers/transactions/bulk_auto_categorizations_controller_test.rb`

Expected: Still fails because `preview_categorizations` doesn't exist yet - that's expected

**Step 5: Commit**

```bash
git add app/controllers/transactions/bulk_auto_categorizations_controller.rb test/controllers/transactions/bulk_auto_categorizations_controller_test.rb
git commit -m "feat: add bulk auto-categorizations controller with preview action"
```

---

## Task 3: Add preview_categorizations Method to Family::AutoCategorizer

**Files:**
- Modify: `app/models/family/auto_categorizer.rb`
- Modify: `test/models/family/auto_categorizer_test.rb`

**Step 1: Write failing model test**

Add test to existing test file:

```ruby
test "preview_categorizations raises error when no provider" do
  Provider::Registry.expects(:for_concept).with(:llm).returns(OpenStruct.new(providers: []))

  categorizer = Family::AutoCategorizer.new(@family, transaction_ids: [1])

  assert_raises(Family::AutoCategorizer::Error, "No LLM provider for auto-categorization") do
    categorizer.preview_categorizations
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/family/auto_categorizer_test.rb -n test_preview_categorizations_raises_error_when_no_provider`

Expected: FAIL with "undefined method `preview_categorizations`"

**Step 3: Add preview_categorizations method**

Add this method after the `initialize` method and before `auto_categorize`:

```ruby
# Get predictions without applying them
def preview_categorizations
  raise Error, "No LLM provider for auto-categorization" unless llm_provider

  if scope.none?
    Rails.logger.info("No transactions to auto-categorize for family #{family.id}")
    return []
  end

  batch_size = Setting.categorization_batch_size

  # For preview, we only process up to one batch
  batch = scope.limit(batch_size)

  result = llm_provider.auto_categorize(
    transactions: build_transactions_input(batch),
    user_categories: user_categories_input,
    options: categorization_options
  )

  unless result.success?
    raise Error, result.error.message
  end

  # Build prediction objects without saving
  batch.map do |transaction|
    auto_categorization = result.data.find { |c| c.transaction_id == transaction.id }
    category = user_categories_input.find { |c| c[:name] == auto_categorization&.category_name }

    {
      transaction: transaction,
      category: category ? Current.family.categories.find(category[:id]) : nil,
      confidence: auto_categorization&.confidence || 0
    }
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bin/rails test test/models/family/auto_categorizer_test.rb -n test_preview_categorizations_raises_error_when_no_provider`

Expected: PASS

**Step 5: Commit**

```bash
git add app/models/family/auto_categorizer.rb test/models/family/auto_categorizer_test.rb
git commit -m "feat: add preview_categorizations to Family::AutoCategorizer"
```

---

## Task 4: Add Create Action to Controller

**Files:**
- Modify: `app/controllers/transactions/bulk_auto_categorizations_controller.rb`
- Modify: `test/controllers/transactions/bulk_auto_categorizations_controller_test.rb`

**Step 1: Write failing test for create action**

Add to controller test file:

```ruby
test "create applies selected predictions" do
  transaction1 = @family.entries.first.entryable
  transaction1.update!(category: nil)

  groceries_category = @family.categories.find_or_create_by!(name: "Groceries")

  predictions = [
    { entry_id: transaction1.entry_id, category_id: groceries_category.id }.to_json
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
```

**Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/transactions/bulk_auto_categorizations_controller_test.rb -n "/create/"`

Expected: FAIL with "The action 'create' could not be found"

**Step 3: Add create action to controller**

Add this method after the `preview` method:

```ruby
def create
  predictions = JSON.parse(params[:predictions] || "[]")

  if predictions.empty?
    redirect_to transactions_path, alert: "No categorizations selected"
    return
  end

  applied_count = 0
  predictions.each do |prediction_json|
    prediction = JSON.parse(prediction_json)
    entry = Current.family.entries.find(prediction["entry_id"])
    transaction = entry.entryable

    if prediction["category_id"].present?
      transaction.enrich_attribute(:category_id, prediction["category_id"], source: "ai")
      transaction.lock_attr!(:category_id)
      applied_count += 1
    end
  end

  redirect_to transactions_path,
              notice: "Successfully categorized #{applied_count} transaction#{'s' unless applied_count == 1}"
end
```

**Step 4: Run tests to verify they pass**

Run: `bin/rails test test/controllers/transactions/bulk_auto_categorizations_controller_test.rb`

Expected: PASS (all controller tests)

**Step 5: Commit**

```bash
git add app/controllers/transactions/bulk_auto_categorizations_controller.rb test/controllers/transactions/bulk_auto_categorizations_controller_test.rb
git commit -m "feat: add create action to apply selected categorizations"
```

---

## Task 5: Create Stimulus Controller

**Files:**
- Create: `app/javascript/controllers/bulk_auto_categorize_controller.js`

**Step 1: Create Stimulus controller file**

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "loadingState",
    "previewContent",
    "errorState",
    "previewTemplate",
    "checkbox",
    "selectedCount",
    "form"
  ]

  connect() {
    this.predictions = []
  }

  async openPreview(event) {
    event.preventDefault()

    // Get selected entry IDs from bulk-select controller
    const bulkSelectElement = document.querySelector('[data-controller*="bulk-select"]')
    const bulkSelectController = this.application.getControllerForElementAndIdentifier(
      bulkSelectElement,
      "bulk-select"
    )

    const selectedEntryIds = bulkSelectController.selectedIdsValue

    if (selectedEntryIds.length === 0) {
      alert("Please select at least one transaction")
      return
    }

    // Open modal and show loading state
    this.showLoading()
    this.openModal()

    // Fetch predictions
    try {
      const response = await fetch('/transactions/bulk_auto_categorization/preview', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ entry_ids: selectedEntryIds })
      })

      const data = await response.json()

      if (response.ok) {
        this.predictions = data.predictions
        this.renderPreview(data.predictions)
      } else {
        this.showError(data.error || "Failed to categorize transactions")
      }
    } catch (error) {
      console.error("Auto-categorization error:", error)
      this.showError("Network error. Please try again.")
    }
  }

  renderPreview(predictions) {
    const container = this.previewContentTarget.querySelector('[data-bulk-auto-categorize-target="previewTemplate"]').parentElement

    // Clear existing previews (except template)
    container.querySelectorAll(':not(template)').forEach(el => el.remove())

    predictions.forEach((prediction) => {
      const template = this.previewTemplateTarget.content.cloneNode(true)
      const div = template.querySelector('div')

      // Set data
      div.querySelector('[data-field="name"]').textContent = prediction.transaction_name
      div.querySelector('[data-field="account"]').textContent = prediction.account_name
      div.querySelector('[data-field="category"]').textContent = prediction.category_name || "Uncategorized"
      div.querySelector('[data-field="amount"]').textContent = prediction.amount

      // Set checkbox value
      const checkbox = div.querySelector('input[type="checkbox"]')
      checkbox.value = JSON.stringify({
        entry_id: prediction.entry_id,
        category_id: prediction.category_id
      })
      checkbox.checked = prediction.category_id !== null
      checkbox.disabled = prediction.category_id === null

      // Add gray styling for uncategorized
      if (prediction.category_id === null) {
        div.classList.add('opacity-50')
      }

      container.appendChild(template)
    })

    this.updateSelectedCount()
    this.showPreview()
  }

  updateSelectedCount() {
    const checkedCount = this.checkboxTargets.filter(cb => cb.checked && !cb.disabled).length
    const totalCount = this.checkboxTargets.filter(cb => !cb.disabled).length
    this.selectedCountTarget.textContent = `${checkedCount} of ${totalCount}`
  }

  showLoading() {
    this.loadingStateTarget.classList.remove('hidden')
    this.previewContentTarget.classList.add('hidden')
    this.errorStateTarget.classList.add('hidden')
  }

  showPreview() {
    this.loadingStateTarget.classList.add('hidden')
    this.previewContentTarget.classList.remove('hidden')
    this.errorStateTarget.classList.add('hidden')
  }

  showError(message) {
    this.errorStateTarget.querySelector('[data-field="errorMessage"]').textContent = message
    this.loadingStateTarget.classList.add('hidden')
    this.previewContentTarget.classList.add('hidden')
    this.errorStateTarget.classList.remove('hidden')
  }

  openModal() {
    const dialog = this.element.closest('dialog')
    if (dialog && typeof dialog.showModal === 'function') {
      dialog.showModal()
    }
  }

  closeModal(event) {
    if (event) event.preventDefault()

    const dialog = this.element.closest('dialog')
    if (dialog && typeof dialog.close === 'function') {
      dialog.close()
    }
  }

  applyCategories(event) {
    event.preventDefault()

    // Form will submit with checked predictions via Turbo
    this.formTarget.requestSubmit()
  }
}
```

**Step 2: Verify controller is loaded**

Check that Stimulus can find the controller (this will be verified when we test the UI):

Run: `npm run build` (or relevant build command)

Expected: No errors

**Step 3: Commit**

```bash
git add app/javascript/controllers/bulk_auto_categorize_controller.js
git commit -m "feat: add Stimulus controller for bulk auto-categorization preview"
```

---

## Task 6: Create Preview Modal Partial

**Files:**
- Create: `app/views/transactions/bulk_auto_categorizations/_preview_modal.html.erb`

**Step 1: Create modal partial**

```erb
<div data-controller="bulk-auto-categorize">
  <%= render DS::Dialog.new(variant: "modal", auto_open: false, width: :lg) do |dialog| %>
    <% dialog.with_header(title: "Auto-Categorization Preview") %>

    <% dialog.with_body do %>
      <!-- Loading State -->
      <div data-bulk-auto-categorize-target="loadingState"
           class="flex flex-col items-center justify-center py-12 gap-3">
        <%= icon "loader-2", class: "animate-spin text-secondary", size: "lg" %>
        <p class="text-secondary">Categorizing transactions...</p>
      </div>

      <!-- Preview Content -->
      <div data-bulk-auto-categorize-target="previewContent" class="hidden">
        <p class="text-sm text-secondary mb-4 px-4">
          Review the suggested categories below. Uncheck any you don't want to apply.
        </p>

        <%= form_with url: transactions_bulk_auto_categorization_path,
                      method: :post,
                      data: {
                        bulk_auto_categorize_target: "form",
                        action: "submit->bulk-auto-categorize#applyCategories",
                        turbo_frame: "_top"
                      } do |f| %>

          <div class="space-y-2 max-h-96 overflow-y-auto px-4">
            <!-- Container for dynamically rendered predictions -->
            <template data-bulk-auto-categorize-target="previewTemplate">
              <div class="flex items-center gap-3 p-3 rounded-lg bg-container-inset">
                <%= check_box_tag "predictions[]", "", true,
                                  class: "checkbox checkbox--light",
                                  data: {
                                    bulk_auto_categorize_target: "checkbox",
                                    action: "change->bulk-auto-categorize#updateSelectedCount"
                                  } %>

                <div class="flex-1 min-w-0">
                  <p class="font-medium truncate" data-field="name"></p>
                  <p class="text-xs text-secondary" data-field="account"></p>
                </div>

                <div class="flex items-center gap-2">
                  <%= icon "arrow-right", class: "text-secondary", size: "sm" %>
                  <span class="px-2 py-1 rounded bg-gray-100 text-sm font-medium"
                        data-field="category"></span>
                </div>

                <p class="text-sm font-medium whitespace-nowrap" data-field="amount"></p>
              </div>
            </template>
          </div>

          <div class="mt-4 flex items-center justify-between px-4 pb-4">
            <p class="text-sm text-secondary">
              <span data-bulk-auto-categorize-target="selectedCount"></span> selected
            </p>

            <div class="flex gap-2">
              <%= render DS::Button.new(text: "Cancel", variant: "outline",
                                       type: "button",
                                       data: { action: "click->bulk-auto-categorize#closeModal" }) %>
              <%= render DS::Button.new(text: "Apply", variant: "primary", type: "submit") %>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Error State -->
      <div data-bulk-auto-categorize-target="errorState" class="hidden py-12 text-center px-4">
        <p class="text-red-600 mb-4" data-field="errorMessage"></p>
        <%= render DS::Button.new(text: "Close", variant: "outline",
                                 type: "button",
                                 data: { action: "click->bulk-auto-categorize#closeModal" }) %>
      </div>
    <% end %>
  <% end %>
</div>
```

**Step 2: Commit**

```bash
git add app/views/transactions/bulk_auto_categorizations/_preview_modal.html.erb
git commit -m "feat: create preview modal partial for auto-categorization"
```

---

## Task 7: Add Auto-Categorize Button to Selection Bar

**Files:**
- Modify: `app/views/transactions/_selection_bar.html.erb`

**Step 1: Add button to selection bar**

Insert the auto-categorize button after the edit button and before the delete button:

```erb
<div class="fixed bottom-30 md:bottom-6 z-10 flex items-center justify-between rounded-xl bg-gray-900 px-4 text-sm text-white md:w-[420px] w-[90%] py-1.5">
  <div class="flex items-center gap-2">
    <%= check_box_tag "entry_selection", 1, true, class: "checkbox checkbox--dark", data: { action: "bulk-select#deselectAll" } %>

    <p data-bulk-select-target="selectionBarText"></p>
  </div>

  <div class="flex items-center gap-1 text-secondary">
    <%= turbo_frame_tag "bulk_transaction_edit_drawer" %>
    <%= link_to new_transactions_bulk_update_path,
                class: "p-1.5 group hover:bg-inverse flex items-center justify-center rounded-md",
                title: "Edit",
                data: { turbo_frame: "bulk_transaction_edit_drawer" } do %>
      <%= icon "pencil-line", class: "group-hover:text-inverse" %>
    <% end %>

    <!-- NEW: Auto-categorize button -->
    <%= link_to "#",
                class: "p-1.5 group hover:bg-inverse flex items-center justify-center rounded-md",
                title: "Auto-categorize",
                data: { action: "click->bulk-auto-categorize#openPreview" } do %>
      <%= icon "sparkles", class: "group-hover:text-inverse" %>
    <% end %>

    <%= form_with url: transactions_bulk_deletion_path, data: { turbo_confirm: true, turbo_frame: "_top" } do %>
      <button type="button" data-bulk-select-scope-param="bulk_delete" data-action="bulk-select#submitBulkRequest" class="p-1.5 group hover:bg-inverse flex items-center justify-center rounded-md" title="Delete">
        <%= icon "trash-2", class: "group-hover:text-inverse" %>
      </button>
    <% end %>
  </div>
</div>
```

**Step 2: Commit**

```bash
git add app/views/transactions/_selection_bar.html.erb
git commit -m "feat: add auto-categorize button to selection bar"
```

---

## Task 8: Include Modal in Transactions Index

**Files:**
- Modify: `app/views/transactions/index.html.erb`

**Step 1: Add modal render at end of file**

Add this at the very end of the file, after the closing `</div>` for the main container:

```erb
<%= render "transactions/bulk_auto_categorizations/preview_modal" %>
```

**Step 2: Commit**

```bash
git add app/views/transactions/index.html.erb
git commit -m "feat: include auto-categorization modal in transactions index"
```

---

## Task 9: Add Controller Tests for Edge Cases

**Files:**
- Modify: `test/controllers/transactions/bulk_auto_categorizations_controller_test.rb`

**Step 1: Add batch size validation test**

```ruby
test "preview rejects selection exceeding batch size" do
  original_batch_size = Setting.categorization_batch_size
  Setting.categorization_batch_size = 2

  # Get 3 transactions
  transactions = @family.entries.limit(3).map(&:entryable)

  post preview_transactions_bulk_auto_categorization_path,
       params: { entry_ids: transactions.map(&:entry_id).to_json },
       as: :json

  assert_response :unprocessable_entity
  json = JSON.parse(response.body)
  assert_match /Cannot categorize more than 2/, json["error"]
ensure
  Setting.categorization_batch_size = original_batch_size
end
```

**Step 2: Run test**

Run: `bin/rails test test/controllers/transactions/bulk_auto_categorizations_controller_test.rb -n test_preview_rejects_selection_exceeding_batch_size`

Expected: PASS

**Step 3: Add test for selective application**

```ruby
test "create only applies checked predictions" do
  transaction1 = @family.entries.first.entryable
  transaction2 = @family.entries.second.entryable
  transaction1.update!(category: nil)
  transaction2.update!(category: nil)

  groceries_category = @family.categories.find_or_create_by!(name: "Groceries")

  # Only include transaction1 in predictions (user unchecked transaction2)
  predictions = [
    { entry_id: transaction1.entry_id, category_id: groceries_category.id }.to_json
  ]

  post transactions_bulk_auto_categorization_path, params: { predictions: predictions }

  assert_equal groceries_category.id, transaction1.reload.category_id
  assert_nil transaction2.reload.category_id
end
```

**Step 4: Run test**

Run: `bin/rails test test/controllers/transactions/bulk_auto_categorizations_controller_test.rb -n test_create_only_applies_checked_predictions`

Expected: PASS

**Step 5: Run all controller tests**

Run: `bin/rails test test/controllers/transactions/bulk_auto_categorizations_controller_test.rb`

Expected: PASS (all tests)

**Step 6: Commit**

```bash
git add test/controllers/transactions/bulk_auto_categorizations_controller_test.rb
git commit -m "test: add edge case tests for bulk auto-categorization"
```

---

## Task 10: Add Model Tests for preview_categorizations

**Files:**
- Modify: `test/models/family/auto_categorizer_test.rb`

**Step 1: Add test for batch size limit**

```ruby
test "preview_categorizations respects batch size limit" do
  original_batch_size = Setting.categorization_batch_size
  Setting.categorization_batch_size = 2

  # Create 5 uncategorized transactions
  transactions = 5.times.map do |i|
    account = @family.accounts.first
    entry = Entry.create!(
      name: "Transaction #{i}",
      amount: -10,
      account: account,
      date: Date.today
    )
    Transaction.create!(account: account, category: nil, entry: entry)
  end

  # Mock provider - should only be called with 2 transactions
  mock_result = OpenStruct.new(
    success?: true,
    data: [
      OpenStruct.new(transaction_id: transactions[0].id, category_name: "Groceries", confidence: 85),
      OpenStruct.new(transaction_id: transactions[1].id, category_name: "Dining", confidence: 90)
    ]
  )

  Provider::Registry.for_concept(:llm).providers.first
    .expects(:auto_categorize)
    .returns(mock_result)

  categorizer = Family::AutoCategorizer.new(@family, transaction_ids: transactions.map(&:id))
  predictions = categorizer.preview_categorizations

  # Should only return 2 predictions (one batch)
  assert_equal 2, predictions.length
ensure
  Setting.categorization_batch_size = original_batch_size
end
```

**Step 2: Run test**

Run: `bin/rails test test/models/family/auto_categorizer_test.rb -n test_preview_categorizations_respects_batch_size_limit`

Expected: PASS

**Step 3: Run all model tests**

Run: `bin/rails test test/models/family/auto_categorizer_test.rb`

Expected: PASS (all auto_categorizer tests)

**Step 4: Commit**

```bash
git add test/models/family/auto_categorizer_test.rb
git commit -m "test: add preview_categorizations batch size test"
```

---

## Task 11: Run Full Test Suite

**Step 1: Run all tests**

Run: `bin/rails test`

Expected: All tests pass (except pre-existing Plaid errors)

**Step 2: Check for any new failures**

If there are failures:
- Review error messages
- Fix issues
- Re-run tests
- Commit fixes

**Step 3: Run linting**

Run: `bin/rubocop -f github -a`

Expected: No offenses or auto-corrected offenses

**Step 4: Commit any lint fixes**

```bash
git add -A
git commit -m "style: fix rubocop offenses"
```

---

## Task 12: Manual Testing (Optional)

**Step 1: Start development server**

Run: `bin/dev`

**Step 2: Test the feature manually**

1. Navigate to transactions page
2. Select 1-3 transactions via checkboxes
3. Click sparkles icon (auto-categorize button)
4. Verify modal opens with loading state
5. Verify predictions appear (requires LLM provider configured)
6. Uncheck one prediction
7. Click "Apply"
8. Verify modal closes and transactions are categorized
9. Verify flash message shows success count

**Step 3: Test error scenarios**

1. Select more transactions than batch size allows
2. Verify error message appears in modal
3. Click "Cancel" to verify modal closes

---

## Task 13: Final Commit and Summary

**Step 1: Review all changes**

Run: `git log --oneline -15`

Verify all commits are present and descriptive

**Step 2: Run final test suite**

Run: `bin/rails test`

Expected: All tests pass

**Step 3: Create summary**

Document what was implemented:
- ✅ Routes for preview and create actions
- ✅ Controller with preview and apply logic
- ✅ preview_categorizations method in Family::AutoCategorizer
- ✅ Stimulus controller for async preview
- ✅ Preview modal UI
- ✅ Auto-categorize button in selection bar
- ✅ Comprehensive test coverage
- ✅ Integration with existing bulk selection

---

## Verification Checklist

- [ ] Routes added and verified
- [ ] Controller created with preview and create actions
- [ ] preview_categorizations method added to Family::AutoCategorizer
- [ ] Stimulus controller created
- [ ] Preview modal partial created
- [ ] Auto-categorize button added to selection bar
- [ ] Modal included in transactions index
- [ ] Controller tests pass
- [ ] Model tests pass
- [ ] Full test suite passes
- [ ] Rubocop passes
- [ ] Manual testing completed (if LLM provider available)

## Notes

- The preview modal uses DS::Dialog component with `auto_open: false`
- Stimulus controller accesses bulk-select controller via `selectedIdsValue`
- Only uncategorized transactions are processed (handled by existing scope)
- Batch size validation prevents overwhelming the LLM API
- Error handling covers: no provider, batch size exceeded, network errors
- Success message uses singular/plural based on count

## Future Enhancements (Out of Scope)

- Confidence score display in UI
- Edit predictions before applying
- Undo functionality
- Cross-page selection
- Categorization history tracking
