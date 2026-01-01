# Auto-Categorization Settings Feature Design

**Date:** 2026-01-01
**Status:** Design
**Author:** Andrew Bewernick

## Overview

This design document outlines the expansion of the auto-categorization feature to provide granular control over LLM model selection and categorization behavior through a dedicated settings page.

## Goals

1. Allow per-provider model selection (choose specific models for OpenAI, Anthropic, Gemini)
2. Provide tunable categorization behavior controls (confidence threshold, batch size, matching preferences)
3. Store settings globally in the Settings model
4. Create a dedicated auto-categorization settings page separate from hosting settings
5. Dynamically fetch available models from provider APIs to stay current
6. Only show settings for providers with configured API keys

## Non-Goals

- Per-family or per-user settings (all settings are global)
- Per-concept model selection (all AI features use the same provider/model)
- Custom model training or fine-tuning
- Real-time categorization preview

## Data Model & Settings

New fields will be added to the `Setting` model:

### Model Selection (Per Provider)
```ruby
field :openai_categorization_model, type: :string, default: "gpt-4o-mini"
field :anthropic_categorization_model, type: :string, default: "claude-3-5-sonnet-20241022"
field :gemini_categorization_model, type: :string, default: "gemini-2.0-flash-exp"
```

Each field will support ENV variable fallback:
- `ENV["OPENAI_CATEGORIZATION_MODEL"]`
- `ENV["ANTHROPIC_CATEGORIZATION_MODEL"]`
- `ENV["GEMINI_CATEGORIZATION_MODEL"]`

### Categorization Behavior
```ruby
field :categorization_confidence_threshold, type: :integer, default: 60
field :categorization_batch_size, type: :integer, default: 50
field :categorization_prefer_subcategories, type: :boolean, default: true
field :categorization_enforce_classification_match, type: :boolean, default: true
field :categorization_null_tolerance, type: :string, default: "pessimistic"
```

### Validations
```ruby
validates :categorization_confidence_threshold,
          numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
validates :categorization_batch_size,
          numericality: { only_integer: true, greater_than_or_equal_to: 10, less_than_or_equal_to: 200 }
validates :categorization_null_tolerance,
          inclusion: { in: %w[pessimistic balanced optimistic] }
validates :openai_categorization_model,
          presence: true, if: -> { Setting.openai_access_token.present? }
validates :anthropic_categorization_model,
          presence: true, if: -> { Setting.anthropic_api_key.present? }
validates :gemini_categorization_model,
          presence: true, if: -> { Setting.gemini_api_key.present? }
```

## Settings Integration into Auto-Categorizers

### Family::AutoCategorizer Changes

The main orchestrator will pass settings to provider auto-categorizers:

```ruby
def auto_categorize
  raise Error, "No LLM provider for auto-categorization" unless llm_provider

  scope.in_batches(of: Setting.categorization_batch_size) do |batch|
    result = llm_provider.auto_categorize(
      transactions: build_transactions_input(batch),
      user_categories: user_categories_input,
      options: categorization_options
    )

    process_batch_result(batch, result)
  end
end

private

def categorization_options
  {
    confidence_threshold: Setting.categorization_confidence_threshold,
    prefer_subcategories: Setting.categorization_prefer_subcategories,
    enforce_classification: Setting.categorization_enforce_classification_match,
    null_tolerance: Setting.categorization_null_tolerance
  }
end
```

### Provider Auto-Categorizer Changes

Each provider class (`Provider::Openai::AutoCategorizer`, `Provider::Anthropic::AutoCategorizer`, `Provider::Gemini::AutoCategorizer`) will:

1. **Use configured models:**
```ruby
# In Provider::Openai::AutoCategorizer
def auto_categorize
  response = client.responses.create(parameters: {
    model: Setting.openai_categorization_model, # Instead of hardcoded "gpt-4.1-mini"
    # ... rest of parameters
  })
end
```

2. **Accept options parameter:**
```ruby
def initialize(client, transactions: [], user_categories: [], options: {})
  @client = client
  @transactions = transactions
  @user_categories = user_categories
  @options = options
end
```

3. **Generate dynamic prompts:**
```ruby
def instructions
  threshold = @options[:confidence_threshold] || 60
  null_tolerance_text = null_tolerance_instruction(@options[:null_tolerance] || "pessimistic")
  subcategory_text = subcategory_instruction(@options[:prefer_subcategories])
  classification_text = classification_instruction(@options[:enforce_classification])

  <<~INSTRUCTIONS.strip_heredoc
    You are an assistant to a consumer personal finance app. You will be provided a list
    of the user's transactions and a list of the user's categories. Your job is to auto-categorize
    each transaction.

    Closely follow ALL the rules below while auto-categorizing:

    - Return 1 result per transaction
    - Correlate each transaction by ID (transaction_id)
    #{subcategory_text}
    #{classification_text}
    - If you don't know the category, return "null"
      #{null_tolerance_text}
      - Only match a category if you're #{threshold}%+ confident it is the correct one.
    - Each transaction has varying metadata that can be used to determine the category
  INSTRUCTIONS
end

def subcategory_instruction(prefer_subcategories)
  if prefer_subcategories
    "- Attempt to match the most specific category possible (i.e. subcategory over parent category)"
  else
    "- Match to parent categories when appropriate. Only use subcategories when you're confident about the specific use case."
  end
end

def classification_instruction(enforce)
  if enforce
    "- Category and transaction classifications MUST match (i.e. if transaction is an 'expense', the category must have classification of 'expense')"
  else
    "- Category and transaction classifications should generally match, but use your best judgment."
  end
end

def null_tolerance_instruction(tolerance)
  case tolerance
  when "pessimistic"
    "- You should always favor 'null' over false positives. Be slightly pessimistic."
  when "balanced"
    "- Favor accuracy over completeness. Return 'null' when uncertain."
  when "optimistic"
    "- Attempt to match categories whenever plausible. Only return 'null' when truly uncertain."
  end
end
```

## UI Structure & Routing

### Routes
```ruby
# config/routes.rb
namespace :settings do
  resource :auto_categorization, only: [:edit, :update]
end
```

### Controller
```ruby
# app/controllers/settings/auto_categorizations_controller.rb
class Settings::AutoCategorizationsController < ApplicationController
  def edit
    @available_models = fetch_available_models
  end

  def update
    if Setting.update(auto_categorization_params)
      redirect_to edit_settings_auto_categorization_path, notice: "Auto-categorization settings updated"
    else
      @available_models = fetch_available_models
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def auto_categorization_params
    params.require(:setting).permit(
      :openai_categorization_model,
      :anthropic_categorization_model,
      :gemini_categorization_model,
      :categorization_confidence_threshold,
      :categorization_batch_size,
      :categorization_prefer_subcategories,
      :categorization_enforce_classification_match,
      :categorization_null_tolerance
    )
  end

  def fetch_available_models
    {
      openai: fetch_openai_models,
      anthropic: fetch_anthropic_models,
      gemini: fetch_gemini_models
    }
  end

  def fetch_openai_models
    return nil unless Setting.openai_access_token.present?
    Provider::Openai.list_available_models
  rescue => e
    Rails.logger.error("Failed to fetch OpenAI models: #{e.message}")
    Provider::Openai::FALLBACK_MODELS
  end

  def fetch_anthropic_models
    return nil unless Setting.anthropic_api_key.present?
    Provider::Anthropic.list_available_models
  rescue => e
    Rails.logger.error("Failed to fetch Anthropic models: #{e.message}")
    Provider::Anthropic::FALLBACK_MODELS
  end

  def fetch_gemini_models
    return nil unless Setting.gemini_api_key.present?
    Provider::Gemini.list_available_models
  rescue => e
    Rails.logger.error("Failed to fetch Gemini models: #{e.message}")
    Provider::Gemini::FALLBACK_MODELS
  end
end
```

### View Structure
```erb
<!-- app/views/settings/auto_categorizations/edit.html.erb -->
<div class="space-y-8">
  <div>
    <h1 class="text-2xl font-bold">Auto-Categorization Settings</h1>
    <p class="text-secondary mt-2">Configure how AI auto-categorizes your transactions</p>
  </div>

  <%= styled_form_with model: Setting.new,
                       url: settings_auto_categorization_path,
                       method: :patch,
                       data: {
                         controller: "auto-submit-form",
                         "auto-submit-form-trigger-event-value": "blur"
                       } do |form| %>

    <!-- LLM Model Selection Section -->
    <section class="space-y-4">
      <h2 class="text-lg font-medium">LLM Model Selection</h2>
      <p class="text-sm text-secondary">Choose which AI model to use for each provider</p>

      <% if @available_models[:openai].present? %>
        <%= form.select :openai_categorization_model,
                        options_for_select(@available_models[:openai], Setting.openai_categorization_model),
                        { label: "OpenAI Model" },
                        data: { "auto-submit-form-target": "auto" } %>
      <% end %>

      <% if @available_models[:anthropic].present? %>
        <%= form.select :anthropic_categorization_model,
                        options_for_select(@available_models[:anthropic], Setting.anthropic_categorization_model),
                        { label: "Anthropic Model" },
                        data: { "auto-submit-form-target": "auto" } %>
      <% end %>

      <% if @available_models[:gemini].present? %>
        <%= form.select :gemini_categorization_model,
                        options_for_select(@available_models[:gemini], Setting.gemini_categorization_model),
                        { label: "Gemini Model" },
                        data: { "auto-submit-form-target": "auto" } %>
      <% end %>
    </section>

    <!-- Categorization Behavior Section -->
    <section class="space-y-4">
      <h2 class="text-lg font-medium">Categorization Behavior</h2>

      <!-- Confidence Threshold Slider -->
      <div>
        <%= form.range_field :categorization_confidence_threshold,
                             label: "Confidence Threshold: #{Setting.categorization_confidence_threshold}%",
                             min: 0, max: 100, step: 5,
                             data: { "auto-submit-form-target": "auto" } %>
        <p class="text-sm text-secondary mt-1">
          Higher values mean fewer matches but higher accuracy
        </p>
      </div>

      <!-- Batch Size Input -->
      <%= form.number_field :categorization_batch_size,
                            label: "Batch Size",
                            min: 10, max: 200,
                            hint: "Number of transactions to categorize per API request",
                            data: { "auto-submit-form-target": "auto" } %>

      <!-- Null Tolerance Radio -->
      <%= form.select :categorization_null_tolerance,
                      options_for_select([
                        ["Pessimistic - Favor 'null' over false positives", "pessimistic"],
                        ["Balanced - Favor accuracy over completeness", "balanced"],
                        ["Optimistic - Attempt matches whenever plausible", "optimistic"]
                      ], Setting.categorization_null_tolerance),
                      { label: "Null Tolerance" },
                      data: { "auto-submit-form-target": "auto" } %>
    </section>

    <!-- Category Matching Preferences Section -->
    <section class="space-y-4">
      <h2 class="text-lg font-medium">Category Matching Preferences</h2>

      <%= form.check_box :categorization_prefer_subcategories,
                         label: "Prefer subcategories over parent categories",
                         data: { "auto-submit-form-target": "auto" } %>

      <%= form.check_box :categorization_enforce_classification_match,
                         label: "Enforce strict expense/income classification matching",
                         data: { "auto-submit-form-target": "auto" } %>
    </section>
  <% end %>
</div>
```

### Navigation
Add to settings sidebar navigation:
```erb
<!-- In app/views/layouts/_settings_sidebar.html.erb or equivalent -->
<%= link_to "Auto-Categorization", edit_settings_auto_categorization_path, class: "nav-link" %>
```

## Dynamic Model Discovery

### Provider Methods

Each provider class will implement `list_available_models`:

```ruby
# app/models/provider/openai.rb
class Provider::Openai
  FALLBACK_MODELS = [
    ["GPT-4o Mini (Recommended)", "gpt-4o-mini"],
    ["GPT-4o", "gpt-4o"],
    ["GPT-4 Turbo", "gpt-4-turbo"]
  ].freeze

  def self.list_available_models
    Rails.cache.fetch("openai_available_models", expires_in: 24.hours) do
      client = new(Setting.openai_access_token)
      models = client.models.list["data"]

      # Filter to text-completion models suitable for categorization
      suitable_models = models.select { |m| m["id"].start_with?("gpt-") && !m["id"].include?("instruct") }

      suitable_models.map { |m| [m["id"], m["id"]] }
    end
  rescue => e
    Rails.logger.error("Failed to fetch OpenAI models: #{e.message}")
    FALLBACK_MODELS
  end
end

# app/models/provider/anthropic.rb
class Provider::Anthropic
  FALLBACK_MODELS = [
    ["Claude 3.5 Sonnet (Recommended)", "claude-3-5-sonnet-20241022"],
    ["Claude 3.5 Haiku", "claude-3-5-haiku-20241022"],
    ["Claude 3 Opus", "claude-3-opus-20240229"]
  ].freeze

  def self.list_available_models
    Rails.cache.fetch("anthropic_available_models", expires_in: 24.hours) do
      # Anthropic may not have a models list endpoint
      # Use curated list or check their API documentation
      FALLBACK_MODELS
    end
  rescue => e
    Rails.logger.error("Failed to fetch Anthropic models: #{e.message}")
    FALLBACK_MODELS
  end
end

# app/models/provider/gemini.rb
class Provider::Gemini
  FALLBACK_MODELS = [
    ["Gemini 2.0 Flash (Recommended)", "gemini-2.0-flash-exp"],
    ["Gemini 1.5 Flash", "gemini-1.5-flash"],
    ["Gemini 1.5 Pro", "gemini-1.5-pro"]
  ].freeze

  def self.list_available_models
    Rails.cache.fetch("gemini_available_models", expires_in: 24.hours) do
      client = new(Setting.gemini_api_key)
      # Use Gemini's models list endpoint
      # Filter to suitable models
      FALLBACK_MODELS # Placeholder
    end
  rescue => e
    Rails.logger.error("Failed to fetch Gemini models: #{e.message}")
    FALLBACK_MODELS
  end
end
```

### Caching Strategy
- Cache model lists for 24 hours
- Cache key: `{provider}_available_models`
- Clear cache when API keys are updated
- Fallback to hardcoded minimal list on API failure

## Batch Size Implementation

### Processing Logic
```ruby
# In Family::AutoCategorizer
def auto_categorize
  raise Error, "No LLM provider for auto-categorization" unless llm_provider

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
```

### UI Constraints
- Minimum: 10 transactions
- Maximum: 200 transactions
- Default: 50 transactions
- Step: 10
- Help text: "Smaller batches are faster but may use more API calls. Larger batches are more efficient but slower."

## Error Handling & Edge Cases

### Scenarios

1. **Model listing API fails**
   - Fall back to hardcoded minimal model list
   - Show warning banner: "Unable to fetch latest models. Showing cached models."
   - Form remains usable

2. **Selected model becomes unavailable**
   - Log warning during categorization
   - Attempt API call anyway (let provider API return specific error)
   - Don't block categorization process

3. **Invalid model selected**
   - Validate against available models before saving
   - Show validation error inline
   - Prevent form submission

4. **Batch processing fails mid-way**
   - Continue with next batch
   - Log errors for failed batch
   - Return partial results for successful batches

5. **Settings page load fails**
   - Show cached settings
   - Display error banner about inability to fetch fresh model lists
   - Allow editing with stale data

### User Feedback
- Flash messages on successful save
- Inline validation errors on form fields
- Warning banners for degraded functionality
- Loading states while fetching models

## Testing Strategy

### Unit Tests

1. **Setting validations** (`test/models/setting_test.rb`)
```ruby
test "validates categorization_confidence_threshold range" do
  Setting.categorization_confidence_threshold = -1
  assert_not Setting.valid?

  Setting.categorization_confidence_threshold = 101
  assert_not Setting.valid?

  Setting.categorization_confidence_threshold = 60
  assert Setting.valid?
end

test "validates categorization_batch_size range" do
  Setting.categorization_batch_size = 5
  assert_not Setting.valid?

  Setting.categorization_batch_size = 250
  assert_not Setting.valid?

  Setting.categorization_batch_size = 50
  assert Setting.valid?
end

test "validates categorization_null_tolerance inclusion" do
  Setting.categorization_null_tolerance = "invalid"
  assert_not Setting.valid?

  %w[pessimistic balanced optimistic].each do |tolerance|
    Setting.categorization_null_tolerance = tolerance
    assert Setting.valid?
  end
end
```

2. **Provider model listing** (`test/models/provider/openai_test.rb`, etc.)
```ruby
test "list_available_models returns models from API" do
  # Mock API response
  # Test filtering logic
  # Test caching
end

test "list_available_models falls back on error" do
  # Mock API failure
  # Assert fallback models returned
end
```

3. **Batch processing** (`test/models/family/auto_categorizer_test.rb`)
```ruby
test "processes transactions in batches" do
  Setting.categorization_batch_size = 10
  transactions = create_list(:transaction, 25, family: @family, category: nil)

  # Mock LLM provider to track batch sizes
  # Assert 3 batches processed (10, 10, 5)
end
```

4. **Dynamic prompt generation** (provider auto-categorizer tests)
```ruby
test "generates prompt with custom confidence threshold" do
  categorizer = Provider::Openai::AutoCategorizer.new(
    client,
    transactions: [],
    user_categories: [],
    options: { confidence_threshold: 75 }
  )

  assert_includes categorizer.send(:instructions), "75%+ confident"
end

test "generates prompt with optimistic null tolerance" do
  categorizer = Provider::Openai::AutoCategorizer.new(
    client,
    transactions: [],
    user_categories: [],
    options: { null_tolerance: "optimistic" }
  )

  assert_includes categorizer.send(:instructions), "plausible"
  assert_not_includes categorizer.send(:instructions), "pessimistic"
end
```

### Integration Tests

1. **Settings controller** (`test/controllers/settings/auto_categorizations_controller_test.rb`)
```ruby
test "updates auto-categorization settings" do
  patch settings_auto_categorization_path, params: {
    setting: {
      categorization_confidence_threshold: 75,
      categorization_batch_size: 100
    }
  }

  assert_redirected_to edit_settings_auto_categorization_path
  assert_equal 75, Setting.categorization_confidence_threshold
  assert_equal 100, Setting.categorization_batch_size
end

test "rejects invalid settings" do
  patch settings_auto_categorization_path, params: {
    setting: { categorization_confidence_threshold: 150 }
  }

  assert_response :unprocessable_entity
end
```

2. **Auto-categorization flow** (`test/models/family/auto_categorizer_test.rb`)
```ruby
test "auto_categorize respects batch size setting" do
  Setting.categorization_batch_size = 5
  # Create 12 transactions
  # Mock provider responses
  # Assert 3 API calls made (5, 5, 2)
end

test "auto_categorize uses configured model" do
  Setting.openai_categorization_model = "gpt-4o"
  # Mock to capture API parameters
  # Assert correct model used in API call
end
```

### System Tests

1. **Settings page UI** (`test/system/settings/auto_categorizations_test.rb`)
```ruby
test "updates settings via form" do
  visit edit_settings_auto_categorization_path

  fill_in "Confidence Threshold", with: 80
  fill_in "Batch Size", with: 75
  select "Balanced", from: "Null Tolerance"

  # Wait for auto-submit
  sleep 1

  assert_equal 80, Setting.categorization_confidence_threshold
  assert_equal 75, Setting.categorization_batch_size
  assert_equal "balanced", Setting.categorization_null_tolerance
end

test "shows model dropdowns only for configured providers" do
  Setting.openai_access_token = "test-key"
  Setting.anthropic_api_key = nil

  visit edit_settings_auto_categorization_path

  assert_selector "select#setting_openai_categorization_model"
  assert_no_selector "select#setting_anthropic_categorization_model"
end
```

### VCR Cassettes
- Record API responses for model listing endpoints
- Test fallback behavior when cassettes simulate failures
- Cache appropriate responses for 24 hours

## Migration Plan

### Database Migration
```ruby
# db/migrate/YYYYMMDDHHMMSS_add_auto_categorization_settings.rb
class AddAutoCategorizationSettings < ActiveRecord::Migration[7.0]
  def change
    # Settings are stored in rails-settings-cached, no DB changes needed
    # This migration serves as documentation of the feature
  end
end
```

### Deployment Considerations
1. Deploy code with new settings (defaults maintain current behavior)
2. Users can opt-in to new features via settings page
3. No breaking changes to existing auto-categorization
4. ENV variables override settings (for infrastructure-managed deployments)

## Future Enhancements

Potential future improvements (out of scope for this design):

1. **Per-family settings** - Allow different families to have different categorization preferences
2. **A/B testing framework** - Test different settings to optimize categorization accuracy
3. **Categorization preview** - Show preview of how transactions would be categorized before committing
4. **Model performance metrics** - Track accuracy, cost, latency per model
5. **Auto-tuning** - Automatically adjust confidence threshold based on user feedback
6. **Custom prompts** - Allow advanced users to customize the categorization prompts
7. **Categorization history** - Track which settings were used for each categorization run

## Open Questions

1. Should we add rate limiting to prevent excessive API calls when batch size is small?
2. Should we expose token usage/cost estimates in the UI?
3. Should there be a "test categorization" button to preview results with current settings?
4. Should we add analytics to track which settings combinations work best?

## Conclusion

This design provides comprehensive control over auto-categorization through:
- Dynamic model selection per provider
- Tunable confidence and batch size
- Flexible category matching preferences
- Robust error handling and fallbacks
- Clean separation of concerns

The implementation maintains backward compatibility while enabling users to optimize categorization for their specific needs.
