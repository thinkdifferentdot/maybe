# Lunchflow Account Type Mapping Design

**Date:** 2026-01-01
**Status:** Design Approved
**Author:** Claude Code (with user input)

## Overview

This document describes the design for allowing users to assign and change Maybe account types for Lunchflow accounts. Currently, all Lunchflow accounts are auto-created as Depository accounts. This design enables smart auto-detection during initial sync and manual override via the account edit UI.

## Goals

1. Automatically detect appropriate account type during initial Lunchflow account sync
2. Allow users to manually change account type and subtype via the account edit UI
3. Validate type changes to prevent data incompatibilities
4. Safely manage the polymorphic accountable relationship during type changes
5. Preserve existing transactions and balances when changing types

## User Flow

### Initial Sync
1. User connects Lunchflow accounts
2. System auto-detects account type based on name/institution patterns
3. Creates Maybe account with detected type (e.g., Investment, CreditCard, etc.)

### Manual Override
1. User navigates to account edit page for a Lunchflow-connected account
2. Sees "Lunchflow Account Type" section with type and subtype dropdowns
3. Changes type (e.g., Depository → Investment) and/or subtype (e.g., checking → savings)
4. System validates the change
5. If valid, updates the account type; if invalid, shows error message

## Design Components

### 1. Smart Default Account Type Detection

When a Lunchflow account first syncs, auto-detect the account type based on patterns in the account name and institution name.

#### Detection Service

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

#### Integration with LunchflowAccount

```ruby
# app/models/lunchflow_account.rb
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
  klass.create!(subtype: subtype)
end
```

### 2. Account Edit UI for Type/Subtype Selection

Add type and subtype selection to the account edit page, visible only for Lunchflow-connected accounts.

#### Form Structure

```erb
<!-- app/views/accounts/_form.html.erb -->
<%= form_with model: account do |f| %>

  <!-- Existing fields (name, currency, etc.) -->

  <% if account.lunchflow_account.present? %>
    <div class="space-y-4 border-t border-primary mt-6 pt-6">
      <h3 class="text-lg font-semibold">Lunchflow Account Type</h3>

      <!-- Account Type Selection -->
      <div>
        <%= f.label :accountable_type, "Account Type" %>
        <%= f.select :accountable_type,
                      accountable_type_options,
                      {},
                      class: "form-select",
                      data: {
                        controller: "account-type-selector",
                        action: "change->account-type-selector#updateSubtypes",
                        account_type_selector_target: "typeSelect",
                        current_subtype: account.subtype
                      } %>
      </div>

      <!-- Subtype Selection (conditional) -->
      <div data-account-type-selector-target="subtypeContainer">
        <%= f.label :subtype, "Account Subtype" %>
        <%= f.select :subtype,
                      subtype_options_for(account.accountable_type),
                      { include_blank: "None" },
                      class: "form-select",
                      data: { account_type_selector_target: "subtypeSelect" } %>
      </div>

      <div class="text-sm text-gray-600">
        <p>Changing the account type will preserve your existing transactions and balances.
           If the account has data incompatible with the new type (e.g., holdings on a non-Investment account),
           the change will be blocked.</p>
      </div>
    </div>
  <% end %>

  <%= f.submit "Save", class: "btn btn-primary" %>
<% end %>
```

#### Helper Methods

```ruby
# app/helpers/accounts_helper.rb
module AccountsHelper
  def accountable_type_options
    Accountable::TYPES.map do |type|
      [type.constantize.display_name, type]
    end
  end

  def subtype_options_for(accountable_type)
    return [] unless accountable_type.present?

    klass = accountable_type.constantize
    return [] unless klass.const_defined?(:SUBTYPES)

    klass::SUBTYPES.map { |key, labels| [labels[:long], key] }
  end
end
```

#### Stimulus Controller

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

#### Controller Endpoint for Subtypes

```ruby
# app/controllers/accounts_controller.rb
class AccountsController < ApplicationController
  # ... existing actions ...

  def subtypes
    type = params[:type]
    return render json: [] unless type.present? && Accountable::TYPES.include?(type)

    klass = type.constantize
    return render json: [] unless klass.const_defined?(:SUBTYPES)

    subtypes = klass::SUBTYPES.map { |key, labels| [labels[:long], key] }
    render json: subtypes
  end
end
```

### 3. Validation Logic for Type Changes

Validate that existing data is compatible with the new account type before allowing the change.

#### Validator Service

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

### 4. Accountable Record Management

When account type changes, destroy the old accountable record and create a new one.

#### Account Model Method

```ruby
# app/models/account.rb
class Account < ApplicationRecord
  # ... existing code ...

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
      new_accountable = new_accountable_class.create!(subtype: new_subtype)

      # Update account to point to new accountable
      update!(
        accountable: new_accountable
      )
    end

    true
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, "Failed to change account type: #{e.message}")
    false
  end
end
```

#### Controller Logic

```ruby
# app/controllers/accounts_controller.rb
def update
  @account = Current.family.accounts.find(params[:id])

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
      render :edit, status: :unprocessable_entity
    end
  else
    # Normal update flow (no type change)
    if @account.update(account_params)
      redirect_to @account, notice: "Account updated successfully"
    else
      render :edit, status: :unprocessable_entity
    end
  end
end

private

def account_params
  params.require(:account).permit(
    :name, :balance, :currency, :accountable_type, :subtype,
    accountable_attributes: [:id, :subtype]
  )
end
```

### 5. Routes

```ruby
# config/routes.rb
resources :accounts do
  collection do
    get :subtypes
  end
end
```

## Testing Strategy

### 1. AccountTypeDetector Service Tests

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
end
```

### 2. AccountTypeChangeValidator Tests

```ruby
# test/services/account_type_change_validator_test.rb
require "test_helper"

class AccountTypeChangeValidatorTest < ActiveSupport::TestCase
  test "allows change from Depository to CreditCard with no holdings" do
    account = accounts(:checking)
    validator = AccountTypeChangeValidator.new(account, 'Depository', 'CreditCard')
    assert validator.valid?
  end

  test "blocks change from Investment to Depository when holdings exist" do
    account = accounts(:investment)
    account.holdings.create!(
      security: securities(:aapl),
      qty: 10,
      amount: 1000,
      currency: "USD",
      date: Date.current
    )

    validator = AccountTypeChangeValidator.new(account, 'Investment', 'Depository')
    assert_not validator.valid?
    assert_includes validator.error_message, "holdings"
  end

  test "blocks change from Investment to CreditCard when trades exist" do
    account = accounts(:investment)
    account.entries.create!(
      date: Date.current,
      amount: 1000,
      currency: "USD",
      entryable: Trade.create!(
        security: securities(:aapl),
        qty: 10,
        price: 100
      )
    )

    validator = AccountTypeChangeValidator.new(account, 'Investment', 'CreditCard')
    assert_not validator.valid?
    assert_includes validator.error_message, "trades"
  end

  test "allows change from Investment to Crypto with holdings" do
    account = accounts(:investment)
    account.holdings.create!(
      security: securities(:btc),
      qty: 1,
      amount: 50000,
      currency: "USD",
      date: Date.current
    )

    validator = AccountTypeChangeValidator.new(account, 'Investment', 'Crypto')
    assert validator.valid?
  end
end
```

### 3. Account Model Tests

```ruby
# test/models/account_test.rb
class AccountTest < ActiveSupport::TestCase
  test "change_accountable_type! successfully changes type" do
    account = accounts(:lunchflow_checking)
    assert_equal 'Depository', account.accountable_type

    assert account.change_accountable_type!('CreditCard')
    assert_equal 'CreditCard', account.accountable_type
    assert_instance_of CreditCard, account.accountable
  end

  test "change_accountable_type! preserves transactions" do
    account = accounts(:lunchflow_checking)
    transaction_count = account.transactions.count

    account.change_accountable_type!('CreditCard')

    assert_equal transaction_count, account.reload.transactions.count
  end

  test "change_accountable_type! fails when validation fails" do
    account = accounts(:investment)
    account.holdings.create!(
      security: securities(:aapl),
      qty: 10,
      amount: 1000,
      currency: "USD",
      date: Date.current
    )

    assert_not account.change_accountable_type!('Depository')
    assert account.errors[:accountable_type].present?
    assert_equal 'Investment', account.reload.accountable_type
  end

  test "change_accountable_type! allows subtype change for same type" do
    account = accounts(:lunchflow_checking)
    account.accountable.update!(subtype: 'checking')

    assert account.change_accountable_type!('Depository', 'savings')
    assert_equal 'Depository', account.accountable_type
    assert_equal 'savings', account.accountable.subtype
  end
end
```

### 4. System Tests for UI

```ruby
# test/system/lunchflow_account_type_test.rb
require "application_system_test_case"

class LunchflowAccountTypeTest < ApplicationSystemTestCase
  setup do
    sign_in users(:family_admin)
    @account = accounts(:lunchflow_checking)
  end

  test "changing account type via edit form" do
    visit edit_account_path(@account)

    assert_selector "h3", text: "Lunchflow Account Type"

    select "Credit Cards", from: "Account Type"
    click_button "Save"

    assert_text "Account type updated successfully"
    assert_equal 'CreditCard', @account.reload.accountable_type
  end

  test "changing account subtype" do
    visit edit_account_path(@account)

    select "Cash", from: "Account Type"
    select "Savings", from: "Account Subtype"
    click_button "Save"

    assert_text "Account type updated successfully"
    assert_equal 'savings', @account.reload.accountable.subtype
  end

  test "shows error when change is blocked due to holdings" do
    @account.update!(accountable: Investment.create!)
    @account.holdings.create!(
      security: securities(:aapl),
      qty: 10,
      amount: 1000,
      currency: "USD",
      date: Date.current
    )

    visit edit_account_path(@account)

    select "Cash", from: "Account Type"
    click_button "Save"

    assert_text "Cannot change to Cash because this account has investment holdings"
    assert_equal 'Investment', @account.reload.accountable_type
  end

  test "subtype dropdown updates when account type changes" do
    visit edit_account_path(@account)

    # Initially shows Depository subtypes
    assert_selector "select#account_subtype option", text: "Checking"
    assert_selector "select#account_subtype option", text: "Savings"

    # Change to CreditCard (no subtypes)
    select "Credit Cards", from: "Account Type"

    # Subtype dropdown should be hidden
    assert_selector "[data-account-type-selector-target='subtypeContainer'].hidden"
  end
end
```

### 5. Fixtures

```yml
# test/fixtures/lunchflow_accounts.yml
lunchflow_checking:
  lunchflow_connection: chase
  account: lunchflow_checking_account
  lunchflow_id: 12345
  name: "Checking"
  institution_name: "Chase"
  provider: "plaid"
  currency: "USD"
  status: "ACTIVE"

# test/fixtures/accounts.yml
lunchflow_checking_account:
  family: primary
  name: "Chase - Checking"
  balance: 1000
  currency: "USD"
  accountable: checking_depository (Depository)

# test/fixtures/depositories.yml
checking_depository:
  subtype: "checking"
```

## Implementation Checklist

- [ ] Create `AccountTypeDetector` service
- [ ] Update `LunchflowAccount#ensure_account!` to use detector
- [ ] Create `AccountTypeChangeValidator` service
- [ ] Add `Account#change_accountable_type!` method
- [ ] Update account edit form to show type/subtype fields for Lunchflow accounts
- [ ] Create helper methods for type/subtype options
- [ ] Create Stimulus controller for dynamic subtype dropdown
- [ ] Add `/accounts/subtypes` endpoint
- [ ] Update `AccountsController#update` to handle type changes
- [ ] Add routes for subtypes endpoint
- [ ] Write tests for `AccountTypeDetector`
- [ ] Write tests for `AccountTypeChangeValidator`
- [ ] Write tests for `Account#change_accountable_type!`
- [ ] Write system tests for UI
- [ ] Create test fixtures

## Security Considerations

1. **Authorization**: Only allow account owners to change account types
2. **Validation**: Always validate type changes server-side, never trust client input
3. **Data Integrity**: Use database transactions to ensure accountable record changes are atomic

## Future Enhancements

1. **Bulk Type Changes**: Allow changing multiple Lunchflow account types at once
2. **Auto-Suggestions**: Show suggested account type based on transaction patterns
3. **Type Change History**: Track when account types were changed and by whom
4. **Smart Migration**: When changing to Investment, offer to convert certain transactions to trades
5. **Lunchflow Account Type Sync**: If Lunchflow API provides account type metadata, use it for detection

## Conclusion

This design provides a robust system for managing account types for Lunchflow accounts. The smart auto-detection reduces manual work during initial sync, while the manual override UI gives users full control. The validation system ensures data integrity, and the testing strategy provides comprehensive coverage.
