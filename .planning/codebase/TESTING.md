# Testing Patterns

**Analysis Date:** 2026-01-11

## Test Framework

**Runner:**
- Minitest - Rails' built-in testing framework
- Config: `test/test_helper.rb`
- Parallel: Enabled (configured workers)

**Assertion Library:**
- Minitest built-in assertions
- Matchers: `assert`, `refute`, `assert_equal`, `assert_includes`

**Run Commands:**
```bash
bin/rails test                    # Run all tests
bin/rails test:db                 # Run tests with database reset
bin/rails test:system             # Run system tests
bin/rails test test/models/file_test.rb  # Single file
bin/rails test test/models/file_test.rb:42  # Specific line
```

## Test File Organization

**Location:**
- `test/models/` for model tests
- `test/controllers/` for controller tests
- `test/system/` for system tests
- `test/jobs/` for background job tests
- `test/support/` for test helpers

**Naming:**
- `{name}_test.rb` for all test files
- Mirror source structure (e.g., `models/provider/anthropic_test.rb`)

**Structure:**
```
test/
├── models/
│   ├── provider/
│   │   ├── anthropic_test.rb
│   │   └── openai_test.rb
│   ├── family/
│   │   └── auto_categorizer_test.rb
│   └── learned_pattern_test.rb
├── controllers/
│   └── transactions/
│       └── ai_categorizations_controller_test.rb
├── system/
│   └── transactions_ai_categorize_system_test.rb
├── vcr_cassettes/        # API response fixtures
│   ├── anthropic/
│   └── openai/
└── support/
    ├── provider_test_helper.rb
    └── entries_test_helper.rb
```

## Test Structure

**Suite Organization:**
```ruby
require "test_helper"

class Provider::AnthropicTest < ActiveSupport::TestCase
  setup do
    @provider = create_provider
  end

  teardown do
    # Cleanup if needed
  end

  test "auto_categorize with valid input" do
    # arrange
    transactions = create_transactions
    categories = create_categories

    # act
    result = @provider.auto_categorize(
      transactions: transactions,
      user_categories: categories
    )

    # assert
    assert result.success?
    assert_equal 2, result.items.length
  end

  test "raises error when no categories available" do
    assert_raises(Provider::Anthropic::Error) do
      @provider.auto_categorize(transactions: [], user_categories: [])
    end
  end
end
```

**Patterns:**
- `setup` for per-test setup
- `teardown` for cleanup (rarely used)
- Descriptive test names: `"auto_categorize with valid input"`
- Comments for arrange/act/assert in complex tests

## Mocking

**Framework:**
- Mocha (included in Rails)
- VCR for external API recording/playback

**Patterns:**

**VCR for API calls:**
```ruby
VCR.use_cassette("anthropic/auto_categorize") do
  result = @provider.auto_categorize(transactions: transactions, user_categories: categories)
  assert_equal "Groceries", result.first.category_name
end
```

**Mocha for mocking:**
```ruby
Provider::Openai::AutoCategorizer.any_instance.expects(:new).returns(mock_categorizer)
mock_categorizer.expects(:auto_categorize).returns([])
```

**What to Mock:**
- External APIs (via VCR cassettes)
- Background jobs (sometimes)
- Time-dependent operations

**What NOT to Mock:**
- Database queries (use transactional fixtures)
- Internal business logic
- Simple utilities

## Fixtures and Factories

**Test Data:**
```ruby
# Fixtures (YAML in test/fixtures/)
# transactions.yml, categories.yml, etc.

# Factory methods in test/support/
def create_transaction(**attrs)
  Transaction.new({ name: "Test", amount: 100 }.merge(attrs))
end

# Test helpers for complex setup
def setup_provider_mock
  # Returns configured mock provider
end
```

**Location:**
- Fixtures: `test/fixtures/*.yml`
- Factory methods: Defined inline or in `test/support/`

## Coverage

**Requirements:**
- No enforced coverage target
- SimpleCov configured for awareness
- Focus on critical paths

**Configuration:**
- Tool: SimpleCov
- Exclusions: Test files, config files
- Run: Automatically during tests

**View Coverage:**
```bash
bin/rails test
# Check coverage/index.html after run
```

## Test Types

**Unit Tests:**
- Scope: Single class/method in isolation
- Mocking: External dependencies (VCR for APIs)
- Speed: Fast (<100ms per test)
- Examples: `anthropic_test.rb`, `auto_categorizer_test.rb`

**Integration Tests:**
- Scope: Multiple classes together
- Mocking: External services only
- Examples: Controller tests, job tests with real database

**System Tests:**
- Framework: Capybara
- Scope: Full user flows
- Location: `test/system/`
- Examples: `transactions_ai_categorize_system_test.rb`

## AI-Specific Testing Patterns

**VCR Cassettes for API Testing:**
- Location: `test/vcr_cassettes/{provider}/{feature}.yml`
- Examples:
  - `anthropic/auto_categorize.yml`
  - `openai/chat/basic_response.yml`
  - `anthropic/auto_detect_merchants.yml`
- Sensitive data filtering enabled for API keys
- ERB template support for dynamic content

**Provider Testing:**
```ruby
# test/models/provider/anthropic_test.rb
test "chat_response returns parsed response" do
  VCR.use_cassette("anthropic/chat/basic") do
    response = @provider.chat_response("Hello")
    assert response.success?
    assert_match(/hello/i, response.content)
  end
end

test "auto_categorize with valid transactions" do
  VCR.use_cassette("anthropic/auto_categorize") do
    transactions = create_transactions
    categories = create_categories

    result = @provider.auto_categorize(
      transactions: transactions,
      user_categories: categories
    )

    assert_equal 2, result.length
    assert result.first.category_id.present?
    assert result.first.confidence > 0.5
  end
end
```

**Environment Isolation:**
```ruby
# Use ClimateControl for environment variable testing
ClimateControl.modify ANTHROPIC_API_KEY: "test-key" do
  # Test with specific environment
end
```

**Error Testing:**
```ruby
test "raises error when API key missing" do
  ClimateControl.modify ANTHROPIC_API_KEY: nil do
    assert_raises(Provider::Anthropic::Error) do
      Provider::Anthropic.new(access_token: nil)
    end
  end
end
```

## Common Patterns

**Async Testing:**
```ruby
test "background job processes categorization" do
  transaction = create_transaction
  AutoCategorizeJob.perform_now(transaction.id)

  assert transaction.reload.category_id.present?
end
```

**Error Testing:**
```ruby
test "handles API errors gracefully" do
  VCR.use_cassette("anthropic/error") do
    response = @provider.chat_response("test")
    refute response.success?
    assert_kind_of Provider::Anthropic::Error, response.error
  end
end
```

**Confidence Score Testing:**
```ruby
test "stores AI confidence score" do
  VCR.use_cassette("anthropic/auto_categorize") do
    result = @provider.auto_categorize(...)
    assert result.first.confidence.is_a?(Float)
    assert_operator result.first.confidence, :>=, 0.0
    assert_operator result.first.confidence, :<=, 1.0
  end
end
```

---

*Testing analysis: 2026-01-11*
*Update when test patterns change*
