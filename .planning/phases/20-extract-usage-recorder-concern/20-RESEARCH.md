# Phase 20: Extract UsageRecorder Concern - Research

**Researched:** 2026-01-11
**Domain:** Rails concern extraction (internal code organization)
**Confidence:** HIGH

<research_summary>
## Summary

This is an internal code organization refactoring, not an external integration. Research involved examining the existing codebase to understand the duplication pattern in usage recording code.

Key findings:
1. **OpenAI** already has `Provider::Openai::Concerns::UsageRecorder` — a 97-line concern module
2. **Anthropic** has inline `record_usage` methods in both `AutoCategorizer` (33 lines) and `AutoMerchantDetector` (33 lines) — nearly identical code
3. The duplication is clear: both Anthropic classes have the same `record_usage` method that handles the `Anthropic::Models::Usage` BaseModel format
4. The OpenAI concern handles both hash-based usage data (from API responses) and provides `record_usage_error` method for error handling

**Primary recommendation:** Extract a shared `Provider::Concerns::UsageRecorder` (top-level) that both providers can include, with provider-specific handling for different usage data formats.
</research_summary>

<standard_stack>
## Standard Stack

This is a Rails concern extraction — no external libraries needed.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Rails ActiveSupport::Concern | Built-in | Concern module pattern | Standard Rails pattern for shared behavior |
| LlmUsage model | Existing | Usage recording in DB | Already in codebase |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Shared concern | Service object | Concern is better for drop-in behavior |
| Top-level namespace | Provider-specific namespace | Shared top-level is more portable |

**Installation:** None (internal refactoring)
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Recommended Project Structure
```
app/models/provider/
├── concerns/
│   └── usage_recorder.rb      # NEW: Shared concern
├── openai/
│   ├── concerns/
│   │   └── usage_recorder.rb  # EXISTING: Can be deprecated
│   ├── auto_categorizer.rb
│   └── auto_merchant_detector.rb
└── anthropic/
    ├── auto_categorizer.rb    # Include shared concern
    └── auto_merchant_detector.rb  # Include shared concern
```

### Pattern 1: Shared Concern with Format Handling
**What:** A single concern that detects usage data format and extracts tokens appropriately
**When to use:** Multiple providers need identical usage recording behavior but receive different response formats
**Example:**
```ruby
module Provider::Concerns::UsageRecorder
  extend ActiveSupport::Concern

  private

  def record_usage(model_name, usage_data, operation:, metadata: {})
    return unless family && usage_data

    prompt_tokens, completion_tokens = extract_tokens(usage_data)
    total_tokens = prompt_tokens + completion_tokens

    estimated_cost = LlmUsage.calculate_cost(
      model: model_name,
      prompt_tokens: prompt_tokens,
      completion_tokens: completion_tokens
    )

    # Handle nil cost (unknown models)
    Rails.logger.info("Recording LLM usage without cost estimate for unknown model: #{model_name}") if estimated_cost.nil?

    family.llm_usages.create!(
      provider: LlmUsage.infer_provider(model_name),
      model: model_name,
      operation: operation,
      prompt_tokens: prompt_tokens,
      completion_tokens: completion_tokens,
      total_tokens: total_tokens,
      estimated_cost: estimated_cost,
      metadata: metadata
    )

    Rails.logger.info("LLM usage recorded - Operation: #{operation}, Cost: #{estimated_cost.inspect}")
  rescue => e
    Rails.logger.error("Failed to record LLM usage: #{e.message}")
  end

  # Extract tokens from different usage data formats
  # OpenAI: Hash with "prompt_tokens"/"input_tokens" keys
  # Anthropic: BaseModel with input_tokens/output_tokens attributes
  def extract_tokens(usage_data)
    if usage_data.respond_to?(:input_tokens)
      # Anthropic::Models::Usage BaseModel
      [usage_data.input_tokens, usage_data.output_tokens]
    else
      # Hash (OpenAI API response)
      prompt = usage_data["prompt_tokens"] || usage_data["input_tokens"] || 0
      completion = usage_data["completion_tokens"] || usage_data["output_tokens"] || 0
      [prompt, completion]
    end
  end
end
```

### Pattern 2: Preserve OpenAI's Additional Methods
**What:** Keep `record_usage_error` and `extract_http_status_code` from existing concern
**When to use:** Error handling needs to be consistent across providers

The existing OpenAI concern has additional methods that should be preserved:
- `record_usage_error` — records failed API calls with error details
- `extract_http_status_code` — extracts HTTP status from various error types

### Anti-Patterns to Avoid
- **Breaking existing includes:** `Provider::Openai::AutoCategorizer` and `AutoMerchantDetector` already include `Provider::Openai::Concerns::UsageRecorder` — preserve backward compatibility
- **Hardcoding to one provider's format:** The concern must handle both Hash (OpenAI) and BaseModel (Anthropic) formats
- **Removing error handling:** The OpenAI concern has error recording that Anthropic lacks — this should be available to both
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Usage token extraction | Custom format detection per provider | `extract_tokens` format detector | Both providers use same data, different formats |
| Error recording | Separate error handling per provider | `record_usage_error` method | OpenAI already has this pattern |

**Key insight:** The OpenAI concern already implements the right pattern. We're extracting it to be shared, not inventing new patterns.
</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

### Pitfall 1: Breaking Backward Compatibility
**What goes wrong:** Existing `include Provider::Openai::Concerns::UsageRecorder` statements break
**Why it happens:** Moving the concern without aliasing the old path
**How to avoid:** Keep `Provider::Openai::Concerns::UsageRecorder` as an alias to the new shared concern
**Warning signs:** Test failures in OpenAI classes

### Pitfall 2: Format-Specific Logic
**What goes wrong:** Anthropic's BaseModel handling breaks OpenAI's Hash handling
**Why it happens:** Hardcoding to one format instead of detecting format
**How to avoid:** Use `extract_tokens` method that detects format via `respond_to?`
**Warning signs:** One provider works, the other breaks

### Pitfall 3: Missing Error Handling
**What goes wrong:** Anthropic lacks `record_usage_error` method that OpenAI relies on
**Why it happens:** Only porting the basic `record_usage` method
**How to avoid:** Port the full concern including error recording methods
**Warning signs:** No-op when `record_usage_error` is called
</common_pitfalls>

<code_examples>
## Code Examples

### Current OpenAI Usage (Working)
```ruby
# app/models/provider/openai/concerns/usage_recorder.rb
module Provider::Openai::Concerns::UsageRecorder
  extend ActiveSupport::Concern

  private

  def record_usage(model_name, usage_data, operation:, metadata: {})
    return unless family && usage_data

    # Handle both old and new OpenAI API response formats
    prompt_tokens = usage_data["prompt_tokens"] || usage_data["input_tokens"] || 0
    completion_tokens = usage_data["completion_tokens"] || usage_data["output_tokens"] || 0
    total_tokens = usage_data["total_tokens"] || 0

    estimated_cost = LlmUsage.calculate_cost(
      model: model_name,
      prompt_tokens: prompt_tokens,
      completion_tokens: completion_tokens
    )

    inferred_provider = LlmUsage.infer_provider(model_name)
    family.llm_usages.create!(
      provider: inferred_provider,
      model: model_name,
      operation: operation,
      prompt_tokens: prompt_tokens,
      completion_tokens: completion_tokens,
      total_tokens: total_tokens,
      estimated_cost: estimated_cost,
      metadata: metadata
    )

    Rails.logger.info("LLM usage recorded - Operation: #{operation}, Cost: #{estimated_cost.inspect}")
  rescue => e
    Rails.logger.error("Failed to record LLM usage: #{e.message}")
  end

  def record_usage_error(model_name, operation:, error:, metadata: {})
    # ... error recording logic
  end

  def extract_http_status_code(error)
    # ... HTTP status extraction logic
  end
end
```

### Current Anthropic Usage (Duplicate)
```ruby
# app/models/provider/anthropic/auto_categorizer.rb (lines 397-429)
def record_usage(model_name, usage_data, operation:, metadata: {})
  return unless family && usage_data

  # Note: usage_data is an Anthropic::Models::Usage BaseModel
  input_toks = usage_data.input_tokens
  output_toks = usage_data.output_tokens
  total_toks = input_toks + output_toks

  LlmUsage.calculate_cost(
    model: model_name,
    prompt_tokens: input_toks,
    completion_tokens: output_toks
  ).yield_self do |estimated_cost|
    if estimated_cost.nil?
      Rails.logger.info("Recording LLM usage without cost estimate for unknown model: #{model_name}")
    end

    family.llm_usages.create!(
      provider: LlmUsage.infer_provider(model_name),
      model: model_name,
      operation: operation,
      prompt_tokens: input_toks,
      completion_tokens: output_toks,
      total_tokens: total_toks,
      estimated_cost: estimated_cost,
      metadata: metadata
    )

    Rails.logger.info("LLM usage recorded - Operation: #{operation}, Cost: #{estimated_cost.inspect}")
  end
rescue => e
  Rails.logger.error("Failed to record LLM usage: #{e.message}")
end
```

### Proposed Shared Concern
```ruby
# app/models/provider/concerns/usage_recorder.rb (NEW)
module Provider::Concerns::UsageRecorder
  extend ActiveSupport::Concern

  private

  def record_usage(model_name, usage_data, operation:, metadata: {})
    return unless family && usage_data

    prompt_tokens, completion_tokens = extract_tokens(usage_data)
    total_tokens = prompt_tokens + completion_tokens

    estimated_cost = LlmUsage.calculate_cost(
      model: model_name,
      prompt_tokens: prompt_tokens,
      completion_tokens: completion_tokens
    )

    if estimated_cost.nil?
      Rails.logger.info("Recording LLM usage without cost estimate for unknown model: #{model_name}")
    end

    family.llm_usages.create!(
      provider: LlmUsage.infer_provider(model_name),
      model: model_name,
      operation: operation,
      prompt_tokens: prompt_tokens,
      completion_tokens: completion_tokens,
      total_tokens: total_tokens,
      estimated_cost: estimated_cost,
      metadata: metadata
    )

    Rails.logger.info("LLM usage recorded - Operation: #{operation}, Cost: #{estimated_cost.inspect}")
  rescue => e
    Rails.logger.error("Failed to record LLM usage: #{e.message}")
  end

  def extract_tokens(usage_data)
    if usage_data.respond_to?(:input_tokens)
      # Anthropic::Models::Usage BaseModel (and similar)
      [usage_data.input_tokens, usage_data.output_tokens]
    else
      # Hash (OpenAI API response)
      prompt = usage_data["prompt_tokens"] || usage_data["input_tokens"] || 0
      completion = usage_data["completion_tokens"] || usage_data["output_tokens"] || 0
      [prompt, completion]
    end
  end
end
```
</code_examples>

<sota_updates>
## State of the Art (2024-2025)

No changes — this is standard Rails concern pattern that has been stable for years.
</sota_updates>

<open_questions>
## Open Questions

None — this is a straightforward refactoring with clear existing patterns to follow.
</open_questions>

<sources>
## Sources

### Primary (HIGH confidence)
- Existing `app/models/provider/openai/concerns/usage_recorder.rb` — 97 lines, reference implementation
- Existing `app/models/provider/anthropic/auto_categorizer.rb` — lines 397-429, duplicate implementation
- Existing `app/models/provider/anthropic/auto_merchant_detector.rb` — lines 330-362, duplicate implementation
</sources>

<metadata>
## Metadata

**Research scope:**
- Core technology: Rails ActiveSupport::Concern pattern
- Ecosystem: None (internal refactoring)
- Patterns: Concern extraction, format detection via `respond_to?`
- Pitfalls: Backward compatibility, format handling

**Confidence breakdown:**
- Standard stack: HIGH - Built-in Rails pattern
- Architecture: HIGH - Based on existing working code
- Pitfalls: HIGH - Common Rails refactoring concerns
- Code examples: HIGH - From actual codebase

**Research date:** 2026-01-11
**Valid until:** 2026-02-11 (30 days - Rails patterns stable)
</metadata>

---

*Phase: 20-extract-usage-recorder-concern*
*Research completed: 2026-01-11*
*Ready for planning: yes*
