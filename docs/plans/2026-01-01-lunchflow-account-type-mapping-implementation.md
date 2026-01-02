# Lunchflow Account Type Mapping Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable smart auto-detection and manual editing of account types for Lunchflow accounts

**Architecture:** TDD approach with services for detection and validation, controller updates for editing, and Stimulus for dynamic UI

**Tech Stack:** Ruby on Rails 7.2, Minitest, Stimulus, Turbo

---

## Task 1: Create AccountTypeDetector Service

**Files:**
- Create: `app/services/account_type_detector.rb`
- Create: `test/services/account_type_detector_test.rb`

**Step 1: Write the failing test for Investment detection by keyword**

```ruby
# test/services/account_type_detector_test.rb
require "test_helper"

class AccountTypeDetectorTest < ActiveSupport::TestCase
  test "detects Investment from 401k keyword" do
    detector = AccountTypeDetector.new(
      account_name: "Company 401k",
      institution_name: "Fidelity"
    )
    result = detector.detect
    assert_equal 'Investment', result[:accountable_type]
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rails test test/services/account_type_detector_test.rb:5`
Expected: `NameError: uninitialized constant AccountTypeDetectorTest::AccountTypeDetector`

**Step 3: Write minimal AccountTypeDetector service**

```ruby
# app/services/account_type_detector.rb
class AccountTypeDetector
  PATTERNS = {
    'Investment' => {
      keywords: ['401k', '403b', 'ira', 'roth', 'brokerage', 'investment', 'trading', 'stocks'],
      institutions: ['vanguard', 'fidelity', 'schwab', 'etrade', 'robinhood'],
      default_subtype: nil
    },
    'CreditCard' => {
      keywords: ['credit', 'visa', 'mastercard', 'amex', 'discover'],
      institutions: [],
      default_subtype: nil
    },
    'Depository' => {
      keywords: ['checking', 'savings', 'hsa', 'money market', 'cd'],
      institutions: [],
      default_subtype: 'checking'
    },
    'Loan' => {
      keywords: ['mortgage', 'loan', 'auto loan', 'student loan', 'heloc'],
      institutions: [],
      default_subtype: nil
    },
    'Crypto' => {
      keywords: ['crypto', 'bitcoin', 'ethereum', 'coinbase', 'blockchain'],
      institutions: ['coinbase', 'binance', 'kraken'],
      default_subtype: nil
    }
  }

  def initialize(account_name:, institution_name:)
    @account_name = account_name.downcase
    @institution_name = institution_name.downcase
  end

  def detect
    # Check institution patterns first (more reliable)
    PATTERNS.each do |type, config|
      if config[:institutions].any? { |inst| @institution_name.include?(inst) }
        return { accountable_type: type, subtype: config[:default_subtype] }
      end
    end

    # Check keyword patterns in account name
    PATTERNS.each do |type, config|
      if config[:keywords].any? { |keyword| @account_name.include?(keyword) }
        # For Depository, try to detect specific subtype
        subtype = detect_depository_subtype if type == 'Depository'
        return { accountable_type: type, subtype: subtype || config[:default_subtype] }
      end
    end

    # Default fallback
    { accountable_type: 'Depository', subtype: 'checking' }
  end

  private

  def detect_depository_subtype
    return 'savings' if @account_name.include?('savings')
    return 'checking' if @account_name.include?('checking')
    return 'hsa' if @account_name.include?('hsa')
    return 'cd' if @account_name.include?('cd') || @account_name.include?('certificate')
    return 'money_market' if @account_name.include?('money market')
    nil
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bin/rails test test/services/account_type_detector_test.rb:5`
Expected: `1 runs, 1 assertions, 0 failures, 0 errors, 0 skips`

**Step 5: Add more detector tests**

```ruby
# test/services/account_type_detector_test.rb
# Add to existing file

test "detects Investment from institution name" do
  detector = AccountTypeDetector.new(
    account_name: "Brokerage Account",
    institution_name: "Vanguard"
  )
  result = detector.detect
  assert_equal 'Investment', result[:accountable_type]
end

test "detects CreditCard from credit keyword" do
  detector = AccountTypeDetector.new(
    account_name: "Credit Card",
    institution_name: "Chase"
  )
  result = detector.detect
  assert_equal 'CreditCard', result[:accountable_type]
end

test "detects Depository checking from checking keyword" do
  detector = AccountTypeDetector.new(
    account_name: "Checking Account",
    institution_name: "Wells Fargo"
  )
  result = detector.detect
  assert_equal 'Depository', result[:accountable_type]
  assert_equal 'checking', result[:subtype]
end

test "detects Depository savings from savings keyword" do
  detector = AccountTypeDetector.new(
    account_name: "Savings Account",
    institution_name: "Ally Bank"
  )
  result = detector.detect
  assert_equal 'Depository', result[:accountable_type]
  assert_equal 'savings', result[:subtype]
end

test "defaults to Depository checking when no patterns match" do
  detector = AccountTypeDetector.new(
    account_name: "Account 12345",
    institution_name: "Unknown Bank"
  )
  result = detector.detect
  assert_equal 'Depository', result[:accountable_type]
  assert_equal 'checking', result[:subtype]
end

test "detects Loan from mortgage keyword" do
  detector = AccountTypeDetector.new(
    account_name: "Home Mortgage",
    institution_name: "Quicken Loans"
  )
  result = detector.detect
  assert_equal 'Loan', result[:accountable_type]
end
```

**Step 6: Run all detector tests**

Run: `bin/rails test test/services/account_type_detector_test.rb`
Expected: `7 runs, 9 assertions, 0 failures, 0 errors, 0 skips`

**Step 7: Commit**

```bash
git add app/services/account_type_detector.rb test/services/account_type_detector_test.rb
git commit -m "feat: add AccountTypeDetector service for auto-detection

- Detects account type from account name keywords
- Detects account type from institution name patterns
- Detects Depository subtypes (checking, savings, hsa, cd, money_market)
- Defaults to Depository/checking when no patterns match"
```

---

## Task 2: Update LunchflowAccount to use AccountTypeDetector

**Files:**
- Modify: `app/models/lunchflow_account.rb:8-21`
- Create: `test/models/lunchflow_account_test.rb` (if doesn't exist) or modify existing

**Step 1: Write failing test for auto-detection**

```ruby
# test/models/lunchflow_account_test.rb
require "test_helper"

class LunchflowAccountTest < ActiveSupport::TestCase
  test "ensure_account! detects Investment type from account name" do
    lunchflow_account = lunchflow_accounts(:investment_401k)

    account = lunchflow_account.ensure_account!

    assert_equal 'Investment', account.accountable_type
    assert_instance_of Investment, account.accountable
  end
end
```

**Step 2: Add test fixture**

```yaml
# test/fixtures/lunchflow_accounts.yml
# Add to existing file or create new

investment_401k:
  lunchflow_connection: one
  lunchflow_id: 9999
  name: "401k Retirement"
  institution_name: "Fidelity"
  provider: "plaid"
  currency: "USD"
  status: "ACTIVE"
```

**Step 3: Run test to verify it fails**

Run: `bin/rails test test/models/lunchflow_account_test.rb -n test_ensure_account!_detects_Investment_type_from_account_name`
Expected: Test fails because ensure_account! currently creates Depository

**Step 4: Update LunchflowAccount#ensure_account!**

```ruby
# app/models/lunchflow_account.rb
# Replace the ensure_account! method

def ensure_account!
  return account if account.present?

  detected = AccountTypeDetector.new(
    account_name: name,
    institution_name: institution_name
  ).detect

  accountable = create_accountable_for_type(
    detected[:accountable_type],
    detected[:subtype]
  )

  new_account = Account.create!(
    family: lunchflow_connection.family,
    name: "#{institution_name} - #{name}",
    currency: currency || lunchflow_connection.family.currency || "USD",
    balance: 0,
    accountable: accountable
  )

  update!(account: new_account)
  new_account
end

private

def create_accountable_for_type(type, subtype)
  klass = type.constantize
  if subtype.present?
    klass.create!(subtype: subtype)
  else
    klass.create!
  end
end
```

**Step 5: Run test to verify it passes**

Run: `bin/rails test test/models/lunchflow_account_test.rb -n test_ensure_account!_detects_Investment_type_from_account_name`
Expected: PASS

**Step 6: Run all LunchflowAccount tests**

Run: `bin/rails test test/models/lunchflow_account_test.rb`
Expected: All tests pass

**Step 7: Commit**

```bash
git add app/models/lunchflow_account.rb test/models/lunchflow_account_test.rb test/fixtures/lunchflow_accounts.yml
git commit -m "feat: integrate AccountTypeDetector with LunchflowAccount

- ensure_account! now auto-detects account type
- Creates appropriate accountable type based on detection
- Supports subtype detection for Depository accounts"
```

---

## Task 3: Create AccountTypeChangeValidator Service

**Files:**
- Create: `app/services/account_type_change_validator.rb`
- Create: `test/services/account_type_change_validator_test.rb`

**Step 1: Write failing test for validation**

```ruby
# test/services/account_type_change_validator_test.rb
require "test_helper"

class AccountTypeChangeValidatorTest < ActiveSupport::TestCase
  test "allows change from Depository to CreditCard with no holdings" do
    account = accounts(:checking)
    validator = AccountTypeChangeValidator.new(account, 'Depository', 'CreditCard')
    assert validator.valid?
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rails test test/services/account_type_change_validator_test.rb:5`
Expected: `NameError: uninitialized constant`

**Step 3: Create AccountTypeChangeValidator**

```ruby
# app/services/account_type_change_validator.rb
class AccountTypeChangeValidator
  attr_reader :error_message

  def initialize(account, old_type, new_type)
    @account = account
    @old_type = old_type
    @new_type = new_type
    @error_message = nil
  end

  def valid?
    # Allow same type (e.g., just changing subtype)
    return true if @old_type == @new_type

    # Check for holdings
    if @account.holdings.exists? && !investment_type?(@new_type)
      @error_message = "Cannot change to #{display_name(@new_type)} because this account has investment holdings. Only Investment and Crypto accounts can have holdings."
      return false
    end

    # Check for trades
    if @account.trades.exists? && !investment_type?(@new_type)
      @error_message = "Cannot change to #{display_name(@new_type)} because this account has trades. Only Investment and Crypto accounts can have trades."
      return false
    end

    # All checks passed
    true
  end

  private

  def investment_type?(type)
    ['Investment', 'Crypto'].include?(type)
  end

  def display_name(type)
    type.constantize.display_name
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bin/rails test test/services/account_type_change_validator_test.rb:5`
Expected: PASS

**Step 5: Add more validation tests**

```ruby
# test/services/account_type_change_validator_test.rb
# Add to existing file

test "allows change from Investment to Crypto with holdings" do
  account = accounts(:investment)
  # Create a holding
  account.holdings.create!(
    security: securities(:aapl),
    qty: 1,
    amount: 100,
    currency: "USD",
    date: Date.current
  )

  validator = AccountTypeChangeValidator.new(account, 'Investment', 'Crypto')
  assert validator.valid?
end
```

**Step 6: Run all validator tests**

Run: `bin/rails test test/services/account_type_change_validator_test.rb`
Expected: All tests pass

**Step 7: Commit**

```bash
git add app/services/account_type_change_validator.rb test/services/account_type_change_validator_test.rb
git commit -m "feat: add AccountTypeChangeValidator service

- Validates account type changes for data compatibility
- Blocks changes from Investment/Crypto to other types when holdings exist
- Blocks changes when trades exist on non-investment accounts
- Allows same-type changes (subtype only)"
```

---

## Task 4: Add Account#change_accountable_type! method

**Files:**
- Modify: `app/models/account.rb` (add new method)
- Modify: `test/models/account_test.rb` (add tests)

**Step 1: Write failing test**

```ruby
# test/models/account_test.rb
# Add to existing file

test "change_accountable_type! successfully changes type" do
  account = accounts(:checking)
  original_accountable_id = account.accountable_id

  assert_equal 'Depository', account.accountable_type

  assert account.change_accountable_type!('CreditCard')

  account.reload
  assert_equal 'CreditCard', account.accountable_type
  assert_instance_of CreditCard, account.accountable
  assert_not_equal original_accountable_id, account.accountable_id
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/account_test.rb -n test_change_accountable_type!_successfully_changes_type`
Expected: `NoMethodError: undefined method 'change_accountable_type!'`

**Step 3: Add change_accountable_type! method to Account**

```ruby
# app/models/account.rb
# Add after existing methods

# Change the accountable type safely
def change_accountable_type!(new_type, new_subtype = nil)
  # Validate the change first
  validator = AccountTypeChangeValidator.new(self, accountable_type, new_type)
  unless validator.valid?
    errors.add(:accountable_type, validator.error_message)
    return false
  end

  transaction do
    # Destroy old accountable record
    accountable&.destroy!

    # Create new accountable record
    new_accountable_class = new_type.constantize
    new_accountable = if new_subtype.present?
      new_accountable_class.create!(subtype: new_subtype)
    else
      new_accountable_class.create!
    end

    # Update account to point to new accountable
    update!(accountable: new_accountable)
  end

  true
rescue ActiveRecord::RecordInvalid => e
  errors.add(:base, "Failed to change account type: #{e.message}")
  false
end
```

**Step 4: Run test to verify it passes**

Run: `bin/rails test test/models/account_test.rb -n test_change_accountable_type!_successfully_changes_type`
Expected: PASS

**Step 5: Add more Account tests**

```ruby
# test/models/account_test.rb
# Add to existing file

test "change_accountable_type! preserves transactions" do
  account = accounts(:checking)
  # Create a transaction
  account.entries.create!(
    date: Date.current,
    amount: 100,
    currency: "USD",
    entryable: Transaction.create!(
      name: "Test",
      amount: 100,
      currency: "USD",
      date: Date.current
    )
  )

  transaction_count = account.transactions.count

  account.change_accountable_type!('CreditCard')

  assert_equal transaction_count, account.reload.transactions.count
end

test "change_accountable_type! allows subtype change for same type" do
  account = accounts(:checking)
  account.accountable.update!(subtype: 'checking')

  assert account.change_accountable_type!('Depository', 'savings')
  assert_equal 'Depository', account.accountable_type
  assert_equal 'savings', account.accountable.subtype
end
```

**Step 6: Run all Account tests**

Run: `bin/rails test test/models/account_test.rb`
Expected: All tests pass (may need to adjust existing tests if they break)

**Step 7: Commit**

```bash
git add app/models/account.rb test/models/account_test.rb
git commit -m "feat: add Account#change_accountable_type! method

- Safely changes account type with validation
- Destroys old accountable and creates new one in transaction
- Preserves existing transactions and balances
- Supports subtype changes"
```

---

## Task 5: Add Routes for Account Edit/Update and Subtypes

**Files:**
- Modify: `config/routes.rb:163`

**Step 1: Add edit and update routes**

```ruby
# config/routes.rb
# Modify the accounts resource line

resources :accounts, only: %i[index new show edit update destroy], shallow: true do
  member do
    post :sync
    get :sparkline
    patch :toggle_active
  end

  collection do
    get :subtypes
    post :sync_all
  end
end
```

**Step 2: Verify routes**

Run: `bin/rails routes | grep account`
Expected: Should include edit_account and update routes, plus subtypes

**Step 3: Commit**

```bash
git add config/routes.rb
git commit -m "feat: add edit, update, and subtypes routes for accounts"
```

---

## Task 6: Add AccountsController#edit, #update, and #subtypes actions

**Files:**
- Modify: `app/controllers/accounts_controller.rb`

**Step 1: Add edit action**

```ruby
# app/controllers/accounts_controller.rb
# Add before the private methods

def edit
  @account = family.accounts.find(params[:id])
end
```

**Step 2: Add update action**

```ruby
# app/controllers/accounts_controller.rb
# Add before the private methods

def update
  @account = family.accounts.find(params[:id])

  # Check if accountable_type is being changed
  if params[:account][:accountable_type].present? &&
     params[:account][:accountable_type] != @account.accountable_type

    new_type = params[:account][:accountable_type]
    new_subtype = params[:account][:subtype]

    if @account.change_accountable_type!(new_type, new_subtype)
      # Update other account attributes
      @account.update(account_params.except(:accountable_type, :subtype))
      redirect_to @account, notice: "Account type updated successfully"
    else
      @error_message = @account.errors.full_messages.join(", ")
      render :edit, status: :unprocessable_entity
    end
  else
    # Normal update flow (no type change)
    if @account.update(account_params)
      redirect_to @account, notice: "Account updated successfully"
    else
      @error_message = @account.errors.full_messages.join(", ")
      render :edit, status: :unprocessable_entity
    end
  end
end
```

**Step 3: Add subtypes action**

```ruby
# app/controllers/accounts_controller.rb
# Add before the private methods

def subtypes
  type = params[:type]
  return render json: [] unless type.present? && Accountable::TYPES.include?(type)

  klass = type.constantize
  return render json: [] unless klass.const_defined?(:SUBTYPES)

  subtypes = klass::SUBTYPES.map { |key, labels| [labels[:long], key] }
  render json: subtypes
end
```

**Step 4: Update account_params (add to private section)**

```ruby
# app/controllers/accounts_controller.rb
# Add to private section

def account_params
  params.require(:account).permit(
    :name, :balance, :currency, :accountable_type, :subtype
  )
end
```

**Step 5: Update set_account to include edit and update**

```ruby
# app/controllers/accounts_controller.rb
# Modify the before_action at the top

before_action :set_account, only: %i[sync sparkline toggle_active show edit update destroy]
```

**Step 6: Test controller actions manually**

Run: `bin/rails server`
Navigate to `/accounts` and verify you can access edit pages

**Step 7: Commit**

```bash
git add app/controllers/accounts_controller.rb
git commit -m "feat: add edit, update, and subtypes actions to AccountsController

- edit: renders account edit form
- update: handles account updates with type change validation
- subtypes: returns JSON list of subtypes for a given account type"
```

---

## Task 7: Add Helper Methods for Account Type Options

**Files:**
- Modify: `app/helpers/accounts_helper.rb`

**Step 1: Add accountable_type_options helper**

```ruby
# app/helpers/accounts_helper.rb
# Add to existing module

def accountable_type_options
  Accountable::TYPES.map do |type|
    [type.constantize.display_name, type]
  end
end
```

**Step 2: Add subtype_options_for helper**

```ruby
# app/helpers/accounts_helper.rb
# Add to existing module

def subtype_options_for(accountable_type)
  return [] unless accountable_type.present?

  klass = accountable_type.constantize
  return [] unless klass.const_defined?(:SUBTYPES)

  klass::SUBTYPES.map { |key, labels| [labels[:long], key] }
end
```

**Step 3: Test helpers in Rails console**

Run: `bin/rails console`
```ruby
include AccountsHelper
accountable_type_options
# => [["Cash", "Depository"], ["Investments", "Investment"], ...]
subtype_options_for("Depository")
# => [["Checking", "checking"], ["Savings", "savings"], ...]
```

**Step 4: Commit**

```bash
git add app/helpers/accounts_helper.rb
git commit -m "feat: add helper methods for account type and subtype options"
```

---

## Task 8: Create Account Edit View

**Files:**
- Create: `app/views/accounts/edit.html.erb`

**Step 1: Create edit view**

```erb
<%# app/views/accounts/edit.html.erb %>
<div class="max-w-2xl mx-auto py-8">
  <h1 class="text-2xl font-semibold mb-6">Edit Account</h1>

  <%= render "form", account: @account, url: account_path(@account) %>
</div>
```

**Step 2: Update form partial to support Lunchflow account type editing**

```erb
<%# app/views/accounts/_form.html.erb %>
<%# Replace existing file content %>
<%# locals: (account:, url:) %>

<% if @error_message.present? %>
  <%= render DS::Alert.new(message: @error_message, variant: :error) %>
<% end %>

<%= styled_form_with model: account, url: url, scope: :account, data: { turbo: false }, class: "flex flex-col gap-4 justify-between grow text-primary" do |form| %>
  <div class="grow space-y-2">
    <%= form.hidden_field :return_to, value: params[:return_to] %>

    <%= form.text_field :name, placeholder: "Account name", required: "required", label: "Name" %>

    <% unless account.linked? %>
      <%= form.money_field :balance, label: "Balance", required: true, default_currency: Current.family.currency %>
    <% end %>

    <%# Lunchflow Account Type Section - only show for Lunchflow accounts %>
    <% if account.persisted? && account.respond_to?(:lunchflow_account) && account.lunchflow_account.present? %>
      <div class="space-y-4 border-t border-primary mt-6 pt-6">
        <h3 class="text-lg font-semibold">Lunchflow Account Type</h3>

        <%# Account Type Selection %>
        <div>
          <%= form.label :accountable_type, "Account Type" %>
          <%= form.select :accountable_type,
                          accountable_type_options,
                          {},
                          class: "form-select w-full px-3 py-2 border border-primary rounded-md",
                          data: {
                            controller: "account-type-selector",
                            action: "change->account-type-selector#updateSubtypes",
                            account_type_selector_target: "typeSelect"
                          } %>
        </div>

        <%# Subtype Selection (conditional) %>
        <div data-account-type-selector-target="subtypeContainer">
          <%= form.label :subtype, "Account Subtype" %>
          <%= form.select :subtype,
                          subtype_options_for(account.accountable_type),
                          { include_blank: "None" },
                          class: "form-select w-full px-3 py-2 border border-primary rounded-md",
                          data: { account_type_selector_target: "subtypeSelect" } %>
        </div>

        <div class="text-sm text-gray-600">
          <p>Changing the account type will preserve your existing transactions and balances.
             If the account has data incompatible with the new type (e.g., holdings on a non-Investment account),
             the change will be blocked.</p>
        </div>
      </div>
    <% else %>
      <%= form.hidden_field :accountable_type %>
    <% end %>

    <%= yield form if block_given? %>
  </div>

  <%= form.submit %>
<% end %>
```

**Step 3: Test manually**

Run: `bin/rails server`
Navigate to an account edit page and verify the form renders

**Step 4: Commit**

```bash
git add app/views/accounts/edit.html.erb app/views/accounts/_form.html.erb
git commit -m "feat: add account edit view with Lunchflow type selection

- Create edit.html.erb view
- Update form partial to show type/subtype fields for Lunchflow accounts
- Hide type selector for non-Lunchflow accounts"
```

---

## Task 9: Create Stimulus Controller for Dynamic Subtype Dropdown

**Files:**
- Create: `app/javascript/controllers/account_type_selector_controller.js`

**Step 1: Create Stimulus controller**

```javascript
// app/javascript/controllers/account_type_selector_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["typeSelect", "subtypeSelect", "subtypeContainer"]

  connect() {
    this.updateSubtypes()
  }

  async updateSubtypes() {
    const selectedType = this.typeSelectTarget.value

    if (!selectedType) {
      this.hideSubtypes()
      return
    }

    try {
      const response = await fetch(`/accounts/subtypes?type=${selectedType}`)
      const subtypes = await response.json()

      if (subtypes.length > 0) {
        this.updateSubtypeDropdown(subtypes)
        this.showSubtypes()
      } else {
        this.hideSubtypes()
      }
    } catch (error) {
      console.error("Failed to fetch subtypes:", error)
      this.hideSubtypes()
    }
  }

  updateSubtypeDropdown(subtypes) {
    const select = this.subtypeSelectTarget
    const currentValue = select.value

    // Clear existing options
    select.innerHTML = '<option value="">None</option>'

    // Add new options
    subtypes.forEach(([label, value]) => {
      const option = document.createElement('option')
      option.value = value
      option.textContent = label
      select.appendChild(option)
    })

    // Restore previous selection if still valid
    if (currentValue && subtypes.some(([_, value]) => value === currentValue)) {
      select.value = currentValue
    }
  }

  showSubtypes() {
    this.subtypeContainerTarget.classList.remove('hidden')
  }

  hideSubtypes() {
    this.subtypeContainerTarget.classList.add('hidden')
    this.subtypeSelectTarget.value = ''
  }
}
```

**Step 2: Test in browser**

Run: `bin/rails server`
Navigate to account edit page, change account type dropdown, verify subtype updates

**Step 3: Commit**

```bash
git add app/javascript/controllers/account_type_selector_controller.js
git commit -m "feat: add Stimulus controller for dynamic subtype selection

- Fetches subtypes from server when account type changes
- Updates subtype dropdown dynamically
- Shows/hides subtype field based on availability"
```

---

## Task 10: Add Test Fixtures for Lunchflow Accounts

**Files:**
- Modify: `test/fixtures/lunchflow_accounts.yml`
- Modify: `test/fixtures/accounts.yml`
- Modify: `test/fixtures/depositories.yml`
- Modify: `test/fixtures/lunchflow_connections.yml` (if needed)

**Step 1: Add Lunchflow account fixtures**

```yaml
# test/fixtures/lunchflow_accounts.yml
lunchflow_checking:
  lunchflow_connection: one
  account: lunchflow_checking_account
  lunchflow_id: 12345
  name: "Checking"
  institution_name: "Chase"
  provider: "plaid"
  currency: "USD"
  status: "ACTIVE"
```

**Step 2: Add corresponding account fixtures**

```yaml
# test/fixtures/accounts.yml
# Add to existing file

lunchflow_checking_account:
  family: one
  name: "Chase - Checking"
  balance: 1000
  currency: "USD"
  accountable: lunchflow_checking_depository (Depository)
```

**Step 3: Add depository fixture**

```yaml
# test/fixtures/depositories.yml
# Add to existing file

lunchflow_checking_depository:
  subtype: "checking"
```

**Step 4: Verify fixtures load**

Run: `bin/rails test:db`
Expected: All tests pass with new fixtures

**Step 5: Commit**

```bash
git add test/fixtures/lunchflow_accounts.yml test/fixtures/accounts.yml test/fixtures/depositories.yml
git commit -m "test: add fixtures for Lunchflow account testing"
```

---

## Task 11: Add Controller Tests for Subtypes Endpoint

**Files:**
- Create: `test/controllers/accounts_controller_test.rb` or modify existing

**Step 1: Write test for subtypes endpoint**

```ruby
# test/controllers/accounts_controller_test.rb
require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
  end

  test "subtypes returns JSON for Depository" do
    get subtypes_accounts_path, params: { type: "Depository" }

    assert_response :success
    json = JSON.parse(response.body)
    assert json.is_a?(Array)
    assert json.any? { |subtype| subtype[0] == "Checking" && subtype[1] == "checking" }
  end

  test "subtypes returns empty array for types without subtypes" do
    get subtypes_accounts_path, params: { type: "Investment" }

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
```

**Step 2: Run controller tests**

Run: `bin/rails test test/controllers/accounts_controller_test.rb`
Expected: All tests pass

**Step 3: Commit**

```bash
git add test/controllers/accounts_controller_test.rb
git commit -m "test: add tests for subtypes endpoint"
```

---

## Task 12: Add System Test for Account Type Changing UI

**Files:**
- Create: `test/system/lunchflow_account_type_test.rb`

**Step 1: Write system test for changing account type**

```ruby
# test/system/lunchflow_account_type_test.rb
require "application_system_test_case"

class LunchflowAccountTypeTest < ApplicationSystemTestCase
  setup do
    sign_in users(:family_admin)
    @account = accounts(:lunchflow_checking_account)
  end

  test "changing account type via edit form" do
    visit edit_account_path(@account)

    assert_selector "h3", text: "Lunchflow Account Type"

    select "Credit Cards", from: "Account Type"
    click_button "Submit"

    assert_text "Account type updated successfully"
    assert_equal 'CreditCard', @account.reload.accountable_type
  end

  test "changing account subtype" do
    visit edit_account_path(@account)

    select "Cash", from: "Account Type"
    select "Savings", from: "Account Subtype"
    click_button "Submit"

    assert_text "updated successfully"
    assert_equal 'savings', @account.reload.accountable.subtype
  end
end
```

**Step 2: Run system tests**

Run: `bin/rails test:system test/system/lunchflow_account_type_test.rb`
Expected: Tests pass (may need adjustments based on actual form structure)

**Step 3: Commit**

```bash
git add test/system/lunchflow_account_type_test.rb
git commit -m "test: add system tests for Lunchflow account type editing"
```

---

## Task 13: Run Full Test Suite and Fix Any Issues

**Step 1: Run all tests**

Run: `bin/rails test`
Expected: Review any failures

**Step 2: Fix any broken tests**

- Update fixtures if needed
- Adjust tests that assumed Depository-only accounts
- Fix any integration issues

**Step 3: Run linter**

Run: `bin/rubocop -a`
Expected: Fix any style issues automatically

**Step 4: Commit fixes**

```bash
git add .
git commit -m "fix: resolve test failures and linting issues"
```

---

## Task 14: Manual Testing and Documentation

**Step 1: Manual testing checklist**

- [ ] Create a new Lunchflow account with 401k in name, verify it becomes Investment
- [ ] Edit a Lunchflow account and change type from Depository to CreditCard
- [ ] Try to change an Investment account with holdings to Depository, verify error
- [ ] Change a Depository subtype from checking to savings
- [ ] Verify non-Lunchflow accounts don't show type selector

**Step 2: Update CHANGELOG or docs if needed**

**Step 3: Final commit**

```bash
git add .
git commit -m "docs: add manual testing notes for Lunchflow account type mapping"
```

---

## Completion Checklist

- [ ] AccountTypeDetector service created and tested
- [ ] LunchflowAccount updated to use detector
- [ ] AccountTypeChangeValidator created and tested
- [ ] Account#change_accountable_type! method added
- [ ] Routes updated for edit, update, subtypes
- [ ] AccountsController actions added
- [ ] Helper methods created
- [ ] Views created/updated
- [ ] Stimulus controller created
- [ ] Test fixtures added
- [ ] All tests passing
- [ ] Linting clean
- [ ] Manual testing complete
