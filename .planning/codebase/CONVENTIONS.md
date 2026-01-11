# Coding Conventions

**Analysis Date:** 2026-01-11

## Naming Patterns

**Files:**
- snake_case.rb for all Ruby files
- {feature}_controller.rb for controllers (e.g., `ai_categorizations_controller.rb`)
- {feature}_job.rb for background jobs (e.g., `auto_categorize_job.rb`)
- {provider}_{feature}.rb for provider-specific code (e.g., `anthropic_auto_categorizer.rb`)
- *_test.rb for test files

**Functions/Methods:**
- snake_case for all methods
- No special prefix for async methods (background jobs handle this)
- `auto_{action}` for AI operations (e.g., `auto_categorize`, `auto_detect_merchants`)
- `{verb}_noun?` for predicate methods (e.g., `supports_model?`, `custom_provider?`)

**Classes:**
- PascalCase for all classes
- `Provider::{ProviderName}` for provider classes (e.g., `Provider::Anthropic`)
- `Provider::{ProviderName}::{FeatureName}` for provider features (e.g., `Provider::Anthropic::AutoCategorizer`)
- `{Model}::{Feature}` for namespaced model features (e.g., `Family::AutoCategorizer`)

**Constants:**
- UPPER_SNAKE_CASE for constants (e.g., `DEFAULT_MODEL`, `CONFIDENCE_THRESHOLD`)
- Error classes: `Error = Class.new(ParentError)` for provider-specific errors

## Code Style

**Formatting:**
- Tool: RuboCop with rubocop-rails-omakase
- Indentation: 2 spaces (spaces, not tabs)
- Line length: Default RuboCop limits (~120 characters)
- Quotes: Prefer double quotes for strings
- Semicolons: Not used (Ruby convention)

**Linting:**
- Tool: RuboCop (`bin/rubocop`)
- Configuration: `.rubocop.yml`
- Run: `bin/rubocop` for checking, `bin/rubocop -a` for auto-correct
- Extends: rubocop-rails-omakose (community Rails style guide)

## Import Organization

**Order:**
1. Ruby standard library (require)
2. External gems (require)
3. Internal requires (require_relative)
4. Class/module definitions

**Grouping:**
- No blank lines between related requires
- Blank line before class/module definition
- Alphabetical within groups (generally)

**Path Aliases:**
- None (uses standard Ruby requires)

## Error Handling

**Patterns:**
- Provider-specific error classes: `Provider::{ProviderName}::Error`
- Raise errors for invalid input, missing configuration
- Generic rescue in controllers with user-friendly messages
- Logging before raising: `Rails.logger.error("Context: #{message}")`

**Error Types:**
- Raise on: Invalid input, missing dependencies, API failures
- Return early for: Validation failures, missing configuration
- Rescue at: Controller boundaries, job boundaries

**Logging:**
- `Rails.logger.error` for errors
- `Rails.logger.warn` for warnings
- Langfuse for AI-specific error tracking

## Logging

**Framework:**
- Rails.logger (standard Rails logging)
- Langfuse for AI operation tracing

**Levels:**
- debug, info, warn, error, fatal (standard Rails levels)

**Patterns:**
- Log at service boundaries (before API calls)
- Log errors with context: `Rails.logger.error("Failed to categorize: #{error.message}")`
- Langfuse traces for all AI operations

## Comments

**When to Comment:**
- Explain why, not what (code shows what)
- Document business rules and edge cases
- Explain non-obvious algorithmic choices
- Avoid obvious comments

**Example patterns:**
```ruby
# Be slightly pessimistic. Only match a category if you're 60%+ confident
CONFIDENCE_THRESHOLD = 0.60

# Fallback: if AI returns >50% null values, retry with strict mode
return result_with_strict_mode if null_ratio > 0.5
```

**TODO Comments:**
- Format: `# TODO: description` (no username convention)
- Link to issue if exists: `# TODO: Handle edge case (issue #123)`

## Function Design

**Size:**
- Keep under 50 lines when possible
- Extract helpers for complex logic
- One level of abstraction per function

**Parameters:**
- Keyword arguments for clarity: `def auto_categorize(transactions:, user_categories:, model: "")`
- Options object for 4+ parameters (rare in this codebase)
- Destructure in parameter list for hashes

**Return Values:**
- Explicit returns for early exits
- Implicit returns for final value (Ruby convention)
- Struct objects for complex returns (e.g., `Provider::LlmConcept::AutoCategorization`)

## Module Design

**Exports:**
- No explicit exports (Ruby module system)
- Public API defined by public methods
- Private methods marked with `private`

**Concerns:**
- `include ConcernName` for mixing in behavior
- `included { class_method ... }` for class methods
- `class_methods` block for class-level methods

## AI-Specific Conventions

**Provider Pattern:**
- Inherit from `Provider::Base`
- Include `LlmConcept` for AI capabilities
- Define `Error = Class.new(Provider::Error)`
- Implement: `chat_response`, `auto_categorize`, `auto_detect_merchants`

**Prompt Structure:**
- Heredoc strings with clear formatting
- Dynamic content insertion: `"#{variable}"`
- Section headers: `## Instructions`, `## Categories`, `## Transactions`

**Result Objects:**
- Use Struct for typed results: `AutoCategorization = Struct.new(:transaction_id, :category_id, :confidence)`
- Always return arrays for batch operations
- Include confidence scores for AI results

---

*Convention analysis: 2026-01-11*
*Update when patterns change*
