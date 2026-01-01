# Single Transaction Auto-Categorization Design

**Date:** 2026-01-01
**Status:** Design
**Author:** Andrew Bewernick

## Overview

This feature extends the existing bulk selection system in the transactions list to allow on-demand auto-categorization of selected transactions with preview functionality. Users can select specific transactions from the list, preview AI-suggested categories, and selectively apply the suggestions they approve.

## Goals

1. Enable auto-categorization of user-selected transactions (not just all uncategorized transactions)
2. Provide instant preview of categorization suggestions before applying
3. Allow users to selectively accept/reject suggestions via checkboxes
4. Integrate seamlessly with existing bulk selection UI pattern
5. Respect existing auto-categorization settings (batch size, confidence threshold, model selection, etc.)
6. Process synchronously for immediate feedback

## Non-Goals

- Cross-page bulk selection (only current page selections supported)
- Background job processing (kept synchronous for immediate feedback)
- Per-transaction confidence scores in UI (though confidence is available in backend)
- Undo functionality for applied categorizations
- Custom per-request categorization settings (uses global settings)

## User Flow

1. **Selection**: User navigates to transactions list and uses checkboxes to select 1-N transactions
2. **Initiate**: Clicks "Auto-categorize" button (sparkles icon) in selection bar
3. **Modal Opens**: Preview modal opens immediately with loading state
4. **Fetch Predictions**: AJAX request calls LLM API to get category predictions
5. **Preview Display**: Modal populates with transaction list showing:
   - Transaction name and account
   - Current category → Suggested category
   - Checkbox for each suggestion (all checked by default)
   - Selected count (e.g., "5 of 8 selected")
6. **Review & Adjust**: User reviews suggestions and unchecks any they don't want to apply
7. **Apply**: User clicks "Apply" button to save only checked categorizations
8. **Result**: Modal closes, page updates via Turbo, toast notification shows success count

## UI Implementation

### Selection Bar Addition

**File:** `app/views/transactions/_selection_bar.html.erb`

Add new "Auto-categorize" button alongside existing "Edit" and "Delete" buttons:

```erb
<div class="flex items-center gap-1 text-secondary">
  <%= turbo_frame_tag "bulk_transaction_edit_drawer" %>

  <!-- Existing Edit button -->
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
              data: {
                controller: "bulk-auto-categorize",
                action: "click->bulk-auto-categorize#openPreview"
              } do %>
    <%= icon "sparkles", class: "group-hover:text-inverse" %>
  <% end %>

  <!-- Existing Delete button -->
  <%= form_with url: transactions_bulk_deletion_path,
                data: { turbo_confirm: true, turbo_frame: "_top" } do %>
    <button type="button"
            data-bulk-select-scope-param="bulk_delete"
            data-action="bulk-select#submitBulkRequest"
            class="p-1.5 group hover:bg-inverse flex items-center justify-center rounded-md"
            title="Delete">
      <%= icon "trash-2", class: "group-hover:text-inverse" %>
    </button>
  <% end %>
</div>
```

### Preview Modal

**File:** `app/views/transactions/bulk_auto_categorizations/_preview_modal.html.erb`

```erb
<%= turbo_frame_tag "auto_categorize_preview_modal" do %>
  <%= render DS::Modal.new(id: "auto-categorize-preview") do |modal| %>
    <% modal.with_header do %>
      <h2 class="text-xl font-semibold">Auto-Categorization Preview</h2>
    <% end %>

    <% modal.with_body do %>
      <!-- Loading State -->
      <div data-bulk-auto-categorize-target="loadingState"
           class="flex items-center justify-center py-12">
        <%= icon "loader-2", class: "animate-spin text-secondary" %>
        <p class="ml-2 text-secondary">Categorizing transactions...</p>
      </div>

      <!-- Preview Content -->
      <div data-bulk-auto-categorize-target="previewContent" class="hidden">
        <p class="text-sm text-secondary mb-4">
          Review the suggested categories below. Uncheck any you don't want to apply.
        </p>

        <%= form_with url: transactions_bulk_auto_categorization_path,
                      method: :post,
                      data: {
                        bulk_auto_categorize_target: "form",
                        action: "submit->bulk-auto-categorize#applyCategories"
                      } do |f| %>

          <div class="space-y-2 max-h-96 overflow-y-auto">
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

                <p class="text-sm font-medium" data-field="amount"></p>
              </div>
            </template>
          </div>

          <div class="mt-4 flex items-center justify-between">
            <p class="text-sm text-secondary">
              <span data-bulk-auto-categorize-target="selectedCount"></span> selected
            </p>

            <div class="flex gap-2">
              <%= render DS::Button.new(text: "Cancel", variant: "outline",
                                       data: { action: "click->bulk-auto-categorize#closeModal" }) %>
              <%= render DS::Button.new(text: "Apply", variant: "primary", type: "submit") %>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Error State -->
      <div data-bulk-auto-categorize-target="errorState" class="hidden py-12 text-center">
        <p class="text-red-600 mb-4" data-field="errorMessage"></p>
        <%= render DS::Button.new(text: "Close", variant: "outline",
                                 data: { action: "click->bulk-auto-categorize#closeModal" }) %>
      </div>
    <% end %>
  <% end %>
<% end %>
```

**Modal must be included in the transactions index page:**

```erb
<!-- app/views/transactions/index.html.erb -->
<!-- Add after the transactions container -->
<%= render "transactions/bulk_auto_categorizations/preview_modal" %>
```

## Stimulus Controller

**File:** `app/javascript/controllers/bulk_auto_categorize_controller.js`

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
    const bulkSelectController = this.application.getControllerForElementAndIdentifier(
      document.querySelector('[data-controller="bulk-select"]'),
      "bulk-select"
    )

    const selectedEntryIds = bulkSelectController.getSelectedIds()

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

    predictions.forEach((prediction, index) => {
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
    // Trigger modal open (depends on your DS::Modal implementation)
    const modal = document.getElementById('auto-categorize-preview')
    if (modal && typeof modal.showModal === 'function') {
      modal.showModal()
    }
  }

  closeModal(event) {
    if (event) event.preventDefault()

    const modal = document.getElementById('auto-categorize-preview')
    if (modal && typeof modal.close === 'function') {
      modal.close()
    }
  }

  applyCategories(event) {
    event.preventDefault()

    // Form will submit with checked predictions via Turbo
    this.formTarget.requestSubmit()
  }
}
```

## Backend Implementation

### Routing

**File:** `config/routes.rb`

```ruby
namespace :transactions do
  resource :bulk_auto_categorization, only: [:create] do
    post :preview, on: :collection
  end
end
```

**Routes created:**
- `POST /transactions/bulk_auto_categorization/preview` - Get predictions (returns JSON)
- `POST /transactions/bulk_auto_categorization` - Apply selected predictions (redirects)

### Controller

**File:** `app/controllers/transactions/bulk_auto_categorizations_controller.rb`

```ruby
class Transactions::BulkAutoCategorizationsController < ApplicationController
  before_action :set_transactions, only: [:preview]
  before_action :validate_batch_size, only: [:preview]

  # GET predictions without applying
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

  # Apply selected predictions
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

## Model Changes

### Family::AutoCategorizer Enhancement

**File:** `app/models/family/auto_categorizer.rb`

Add new `preview_categorizations` method that returns predictions without applying them:

```ruby
class Family::AutoCategorizer
  Error = Class.new(StandardError)

  def initialize(family, transaction_ids: [])
    @family = family
    @transaction_ids = transaction_ids
  end

  # NEW: Get predictions without applying them
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

  # EXISTING: Apply categorizations (unchanged)
  def auto_categorize
    raise Error, "No LLM provider for auto-categorization" unless llm_provider

    if scope.none?
      Rails.logger.info("No transactions to auto-categorize for family #{family.id}")
      return
    end

    batch_size = Setting.categorization_batch_size
    total_batches = (scope.count.to_f / batch_size).ceil
    current_batch = 0

    scope.in_batches(of: batch_size) do |batch|
      current_batch += 1
      Rails.logger.info("Processing batch #{current_batch} of #{total_batches} (#{batch.count} transactions)")

      result = llm_provider.auto_categorize(
        transactions: build_transactions_input(batch),
        user_categories: user_categories_input,
        options: categorization_options
      )

      process_batch_result(batch, result)
    end
  end

  private
    attr_reader :family, :transaction_ids

    def categorization_options
      {
        confidence_threshold: Setting.categorization_confidence_threshold,
        prefer_subcategories: Setting.categorization_prefer_subcategories,
        enforce_classification: Setting.categorization_enforce_classification_match,
        null_tolerance: Setting.categorization_null_tolerance
      }
    end

    def process_batch_result(batch, result)
      unless result.success?
        Rails.logger.error("Failed to auto-categorize batch for family #{family.id}: #{result.error.message}")
        return
      end

      batch.each do |transaction|
        auto_categorization = result.data.find { |c| c.transaction_id == transaction.id }
        category_id = user_categories_input.find { |c| c[:name] == auto_categorization&.category_name }&.dig(:id)

        if category_id.present?
          transaction.enrich_attribute(:category_id, category_id, source: "ai")
        end

        transaction.lock_attr!(:category_id)
      end
    end

    def llm_provider
      Provider::Registry.for_concept(:llm).providers.first
    end

    def user_categories_input
      family.categories.map do |category|
        {
          id: category.id,
          name: category.name,
          is_subcategory: category.subcategory?,
          parent_id: category.parent_id,
          classification: category.classification
        }
      end
    end

    def build_transactions_input(batch)
      batch.map do |transaction|
        {
          id: transaction.id,
          amount: transaction.entry.amount.abs,
          classification: transaction.entry.classification,
          description: transaction.entry.name,
          merchant: transaction.merchant&.name
        }
      end
    end

    def scope
      family.transactions.where(id: transaction_ids, category_id: nil)
                         .enrichable(:category_id)
                         .includes(:category, :merchant, :entry)
    end
end
```

**Key points:**
- `preview_categorizations`: Non-destructive, returns predictions without saving
- `auto_categorize`: Existing method unchanged, applies categorizations
- Both methods use same settings, provider, and validation logic
- Preview only processes one batch (respects batch size limit)

## Testing Strategy

### Controller Tests

**File:** `test/controllers/transactions/bulk_auto_categorizations_controller_test.rb`

```ruby
require "test_helper"

class Transactions::BulkAutoCategorizationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
    @family = @user.family
    @account = @family.accounts.first
  end

  test "preview returns categorization predictions as JSON" do
    transactions = [
      Transaction.create!(account: @account, category: nil, entry: Entry.create!(name: "Whole Foods", amount: -50, account: @account, date: Date.today)),
      Transaction.create!(account: @account, category: nil, entry: Entry.create!(name: "Chipotle", amount: -15, account: @account, date: Date.today)),
      Transaction.create!(account: @account, category: nil, entry: Entry.create!(name: "Unknown Store", amount: -25, account: @account, date: Date.today))
    ]

    Family::AutoCategorizer.any_instance.expects(:preview_categorizations).returns([
      { transaction: transactions[0], category: categories(:groceries), confidence: 85 },
      { transaction: transactions[1], category: categories(:dining), confidence: 92 },
      { transaction: transactions[2], category: nil, confidence: 0 }
    ])

    post preview_transactions_bulk_auto_categorization_path,
         params: { entry_ids: transactions.map(&:entry_id).to_json },
         as: :json

    assert_response :success

    json = JSON.parse(response.body)
    assert_equal 3, json["predictions"].length
    assert_equal "Groceries", json["predictions"][0]["category_name"]
    assert_equal 85, json["predictions"][0]["confidence"]
    assert_nil json["predictions"][2]["category_id"]
  end

  test "preview rejects selection exceeding batch size" do
    Setting.categorization_batch_size = 5
    transactions = 10.times.map do |i|
      Transaction.create!(
        account: @account,
        category: nil,
        entry: Entry.create!(name: "Transaction #{i}", amount: -10, account: @account, date: Date.today)
      )
    end

    post preview_transactions_bulk_auto_categorization_path,
         params: { entry_ids: transactions.map(&:entry_id).to_json },
         as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_match /Cannot categorize more than 5/, json["error"]
  end

  test "preview handles auto-categorization errors" do
    transactions = [
      Transaction.create!(account: @account, category: nil, entry: Entry.create!(name: "Test", amount: -10, account: @account, date: Date.today))
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

  test "create applies selected predictions" do
    transaction1 = Transaction.create!(account: @account, category: nil, entry: Entry.create!(name: "Test 1", amount: -10, account: @account, date: Date.today))
    transaction2 = Transaction.create!(account: @account, category: nil, entry: Entry.create!(name: "Test 2", amount: -15, account: @account, date: Date.today))

    predictions = [
      { entry_id: transaction1.entry_id, category_id: categories(:groceries).id }.to_json,
      { entry_id: transaction2.entry_id, category_id: categories(:dining).id }.to_json
    ]

    post transactions_bulk_auto_categorization_path, params: { predictions: predictions }

    assert_redirected_to transactions_path
    assert_match /Successfully categorized 2/, flash[:notice]

    assert_equal categories(:groceries).id, transaction1.reload.category_id
    assert_equal categories(:dining).id, transaction2.reload.category_id
  end

  test "create handles empty predictions array" do
    post transactions_bulk_auto_categorization_path, params: { predictions: [] }

    assert_redirected_to transactions_path
    assert_match /No categorizations selected/, flash[:alert]
  end

  test "create only applies checked predictions" do
    transaction1 = Transaction.create!(account: @account, category: nil, entry: Entry.create!(name: "Test 1", amount: -10, account: @account, date: Date.today))
    transaction2 = Transaction.create!(account: @account, category: nil, entry: Entry.create!(name: "Test 2", amount: -15, account: @account, date: Date.today))

    # Only include transaction1 in predictions (user unchecked transaction2)
    predictions = [
      { entry_id: transaction1.entry_id, category_id: categories(:groceries).id }.to_json
    ]

    post transactions_bulk_auto_categorization_path, params: { predictions: predictions }

    assert_equal categories(:groceries).id, transaction1.reload.category_id
    assert_nil transaction2.reload.category_id
  end
end
```

### Model Tests

**File:** `test/models/family/auto_categorizer_test.rb`

Add tests for the new `preview_categorizations` method:

```ruby
test "preview_categorizations returns predictions without saving" do
  transactions = 3.times.map do |i|
    Transaction.create!(
      family: @family,
      account: @family.accounts.first,
      category: nil,
      entry: Entry.create!(name: "Transaction #{i}", amount: -10, account: @family.accounts.first, date: Date.today)
    )
  end

  # Mock provider response
  mock_result = OpenStruct.new(
    success?: true,
    data: [
      OpenStruct.new(transaction_id: transactions[0].id, category_name: "Groceries", confidence: 85),
      OpenStruct.new(transaction_id: transactions[1].id, category_name: "Dining", confidence: 90),
      OpenStruct.new(transaction_id: transactions[2].id, category_name: nil, confidence: 0)
    ]
  )

  Provider::Registry.for_concept(:llm).providers.first
    .expects(:auto_categorize)
    .returns(mock_result)

  categorizer = Family::AutoCategorizer.new(@family, transaction_ids: transactions.map(&:id))
  predictions = categorizer.preview_categorizations

  assert_equal 3, predictions.length
  assert_equal transactions[0], predictions[0][:transaction]
  assert_equal "Groceries", predictions[0][:category].name
  assert_equal 85, predictions[0][:confidence]
  assert_nil predictions[2][:category]

  # Verify transactions were NOT actually categorized
  assert_nil transactions[0].reload.category_id
  assert_nil transactions[1].reload.category_id
  assert_nil transactions[2].reload.category_id
end

test "preview_categorizations raises error when no provider" do
  Provider::Registry.expects(:for_concept).with(:llm).returns(OpenStruct.new(providers: []))

  categorizer = Family::AutoCategorizer.new(@family, transaction_ids: [1])

  assert_raises(Family::AutoCategorizer::Error, "No LLM provider for auto-categorization") do
    categorizer.preview_categorizations
  end
end

test "preview_categorizations respects batch size limit" do
  Setting.categorization_batch_size = 5

  transactions = 10.times.map do |i|
    Transaction.create!(
      family: @family,
      account: @family.accounts.first,
      category: nil,
      entry: Entry.create!(name: "Transaction #{i}", amount: -10, account: @family.accounts.first, date: Date.today)
    )
  end

  # Mock provider - should only be called once with 5 transactions
  Provider::Registry.for_concept(:llm).providers.first
    .expects(:auto_categorize)
    .with(has_entries(transactions: has_exactly(5).items))
    .returns(OpenStruct.new(success?: true, data: []))

  categorizer = Family::AutoCategorizer.new(@family, transaction_ids: transactions.map(&:id))
  predictions = categorizer.preview_categorizations

  # Should only return 5 predictions (one batch)
  assert_equal 5, predictions.length
end
```

### System Tests (Optional)

**File:** `test/system/transactions/bulk_auto_categorization_test.rb`

```ruby
require "application_system_test_case"

class Transactions::BulkAutoCategorizationTest < ApplicationSystemTestCase
  setup do
    @user = users(:family_admin)
    @family = @user.family
    sign_in @user
  end

  test "auto-categorizes selected transactions with preview" do
    # Create test transactions
    transactions = 3.times.map do |i|
      Transaction.create!(
        account: @family.accounts.first,
        category: nil,
        entry: Entry.create!(
          name: "Transaction #{i}",
          amount: -10,
          account: @family.accounts.first,
          date: Date.today
        )
      )
    end

    visit transactions_path

    # Select transactions
    transactions.each do |t|
      check "entry_selection_#{t.entry_id}"
    end

    # Click auto-categorize button
    within "[data-bulk-select-target='selectionBar']" do
      click_button title: "Auto-categorize"
    end

    # Wait for modal to appear
    assert_selector "#auto-categorize-preview"

    # Wait for predictions to load
    assert_selector "[data-bulk-auto-categorize-target='previewContent']", visible: true

    # Verify predictions are shown
    assert_text "Review the suggested categories"

    # Uncheck one prediction
    first("[data-bulk-auto-categorize-target='checkbox']").uncheck

    # Apply categorizations
    click_button "Apply"

    # Verify success message
    assert_text "Successfully categorized"
  end
end
```

## Edge Cases & Considerations

### 1. Transfer Transactions
- **Current behavior**: Selection bar already disables checkboxes for transfers (`_transaction.html.erb:11`)
- **Action**: No change needed - transfers can't be selected, won't be auto-categorized

### 2. Pagination
- **Scenario**: User selects transactions across multiple pages
- **Current behavior**: Bulk select likely only tracks current page selections
- **Action**: Document limitation - only current page selections supported (consistent with bulk edit/delete)

### 3. No Transactions Selected
- **Current behavior**: Selection bar only appears when transactions are selected
- **Action**: No change needed - button won't be visible if nothing selected

### 4. API Rate Limiting
- **Scenario**: User repeatedly categorizes transactions, hitting API limits
- **Action**: Let provider API return rate limit error, show in flash/modal error state
- **Future enhancement**: Could add client-side throttling

### 5. Concurrent Categorization
- **Scenario**: Background job running while user manually categorizes
- **Action**: No locking needed - both use same `enrich_attribute` and `lock_attr!` methods which handle concurrent updates

### 6. Settings Changes Mid-Request
- **Scenario**: Admin changes settings while categorization preview is loading
- **Action**: Uses settings at request time (settings loaded when controller runs)

### 7. Already Categorized Transactions
- **Scenario**: User selects mix of categorized and uncategorized transactions
- **Behavior**: Preview shows suggested categories for all selected transactions
- **Action**: User can see both new categorizations and re-categorizations in preview
- **Note**: The `scope` in `Family::AutoCategorizer` filters to only uncategorized transactions, so we need to modify this for preview mode

### 8. Modal Dismissal During Loading
- **Scenario**: User closes modal while predictions are loading
- **Action**: Fetch request completes but doesn't update UI (safe - no state changes)

### 9. Network Timeout
- **Scenario**: LLM API takes too long to respond
- **Action**: Browser/Rails timeout kicks in, error state shown in modal

### 10. Partial LLM Failures
- **Scenario**: LLM returns predictions for only some transactions
- **Action**: Show predictions for successful ones, mark others as "Uncategorized" with disabled checkbox

## Implementation Checklist

### Backend
- [ ] Add routes for `preview` and `create` actions
- [ ] Create `Transactions::BulkAutoCategorizationsController`
- [ ] Add `preview_categorizations` method to `Family::AutoCategorizer`
- [ ] Update `Family::AutoCategorizer#scope` to allow already-categorized transactions in preview mode (or create separate scope)

### Frontend
- [ ] Update `_selection_bar.html.erb` with auto-categorize button
- [ ] Create `_preview_modal.html.erb` partial
- [ ] Include modal in `transactions/index.html.erb`
- [ ] Create `bulk_auto_categorize_controller.js` Stimulus controller
- [ ] Verify integration with existing `bulk-select` controller

### Testing
- [ ] Controller tests for preview endpoint
- [ ] Controller tests for create endpoint
- [ ] Model tests for `preview_categorizations`
- [ ] System tests for full user flow (optional)

### Documentation
- [ ] Update CLAUDE.md if needed (probably not necessary)
- [ ] Add comments to complex Stimulus controller methods

## Future Enhancements

Out of scope for initial implementation:

1. **Confidence score display**: Show confidence percentage in preview UI
2. **Edit predictions**: Allow editing category suggestions before applying
3. **Undo functionality**: Ability to revert applied categorizations
4. **Cross-page selection**: Select transactions across multiple pages
5. **Categorization history**: Track which suggestions were accepted/rejected
6. **Batch suggestion improvement**: Learn from user's accept/reject patterns
7. **Keyboard shortcuts**: Quick accept/reject via keyboard
8. **Export predictions**: Download categorization suggestions as CSV
9. **Preview settings**: Temporarily adjust confidence threshold for preview only

## Open Questions

1. Should we track which predictions users accept vs reject for future model improvement?
2. Should there be a limit on how many times a user can preview (API cost consideration)?
3. Should we cache preview results for a short time (e.g., 5 minutes) to avoid redundant API calls?
4. Should already-categorized transactions be included in preview or filtered out?

## Conclusion

This feature provides a user-friendly, preview-based workflow for auto-categorizing selected transactions. It integrates seamlessly with existing bulk selection patterns, respects all auto-categorization settings, and gives users full control over which suggestions to accept. The synchronous processing with immediate modal feedback creates a responsive, intuitive experience.
