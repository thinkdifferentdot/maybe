# Phase 4: Registry Integration - Research

**Researched:** 2026-01-09
**Domain:** Internal provider registry and cost tracking patterns
**Confidence:** HIGH

<research_summary>
## Summary

This phase is about internal codebase patterns, not external ecosystem research. The goal is to register Anthropic as an "equal citizen" to OpenAI in the provider registry and add accurate cost tracking.

Research focused on understanding the existing OpenAI integration patterns:
1. **Provider Registry**: How OpenAI is registered, instantiated, and discovered
2. **LlmUsage Cost Calculation**: How pricing is stored and calculated
3. **Anthropic Pricing**: Current official Claude model pricing from Anthropic docs

All patterns are internal to the Sure codebase and follow established conventions. The implementation is straightforward: mirror the OpenAI patterns for Anthropic.

**Primary recommendation:** Follow the OpenAI patterns exactly — add `anthropic` method to Provider::Registry, add to `:llm` available_providers, add Anthropic pricing to LlmUsage::PRICING hash.
</research_summary>

<standard_stack>
## Standard Stack

### Core (Internal Libraries)

| Component | Location | Purpose | Why Standard |
|-----------|----------|---------|--------------|
| Provider::Registry | app/models/provider/registry.rb | Provider instantiation and discovery | Central registry pattern for all providers |
| LlmUsage | app/models/llm_usage.rb | Cost tracking and usage statistics | Token-based cost calculation with per-model pricing |
| LlmConcept | app/models/provider/llm_concept.rb | Interface all LLM providers must implement | Defines auto_categorize, auto_detect_merchants, chat_response |

### No External Dependencies

This phase uses only internal code patterns. No new gems or libraries required.

</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Pattern 1: Provider Registration in Registry

**What:** Add a private method to Provider::Registry that instantiates the provider

**When to use:** Adding any new provider to the system

**Example (OpenAI pattern to follow):**
```ruby
# In app/models/provider/registry.rb

def openai
  access_token = ENV["OPENAI_ACCESS_TOKEN"].presence || Setting.openai_access_token

  return nil unless access_token.present?

  uri_base = ENV["OPENAI_URI_BASE"].presence || Setting.openai_uri_base
  model = ENV["OPENAI_MODEL"].presence || Setting.openai_model

  if uri_base.present? && model.blank?
    Rails.logger.error("Custom OpenAI provider configured without a model")
    return nil
  end

  Provider::Openai.new(access_token, uri_base: uri_base, model: model)
end
```

**Anthropic equivalent:**
```ruby
def anthropic
  access_token = ENV["ANTHROPIC_API_KEY"].presence || Setting.anthropic_access_token

  return nil unless access_token.present?

  model = ENV["ANTHROPIC_MODEL"].presence || Setting.anthropic_model

  Provider::Anthropic.new(access_token, model: model)
end
```

### Pattern 2: Available Providers List

**What:** Add provider symbol to the appropriate concept's available_providers array

**When to use:** When adding a new provider for a concept

**Example:**
```ruby
# In available_providers method
when :llm
  %i[openai anthropic]  # Add anthropic here
```

### Pattern 3: LlmUsage Pricing Structure

**What:** Add pricing hash to PRICING constant with per-model costs

**When to use:** Adding any LLM provider with trackable costs

**Example (existing OpenAI structure):**
```ruby
PRICING = {
  "openai" => {
    "gpt-4.1" => { prompt: 2.00, completion: 8.00 },
    "gpt-4o" => { prompt: 2.50, completion: 10.00 },
    # ...
  }
}
```

**Anthropic pricing to add:**
```ruby
"anthropic" => {
  "claude-opus-4" => { prompt: 15.00, completion: 75.00 },
  "claude-sonnet-4" => { prompt: 3.00, completion: 15.00 },
  "claude-sonnet-3.7" => { prompt: 3.00, completion: 15.00 },
  "claude-sonnet-3.5" => { prompt: 3.00, completion: 15.00 },
  "claude-haiku-3.5" => { prompt: 0.80, completion: 4.00 },
  "claude-opus-3" => { prompt: 15.00, completion: 75.00 },
  "claude-haiku-3" => { prompt: 0.25, completion: 1.25 },
}
```

### Pattern 4: Provider Discovery

**What:** LlmUsage automatically infers provider from model name using prefix matching

**How it works:**
1. `infer_provider` checks each provider's pricing hash
2. Uses prefix matching (e.g., "claude-sonnet-4-5-20250929" matches "claude-sonnet-4")
3. This means we only need base model names in pricing, not full versioned model names

**Key insight:** The pricing system already handles prefix matching. Add base model names like "claude-sonnet-4" and it will match "claude-sonnet-4-5-20250929".

### Anti-Patterns to Avoid
- **Don't duplicate configuration logic** — Registry methods should follow the ENV → Setting → default pattern
- **Don't hardcode model versions** — Use base model names in pricing, let prefix matching handle versions
- **Don't skip nil checks** — Always return nil gracefully when configuration is missing
- **Don't forget error logging** — Log helpful messages when configuration is invalid

</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Provider instantiation | Custom factory logic | Registry pattern with private methods | Established pattern, handles nil cases consistently |
| Cost calculation | Custom pricing math | LlmUsage.calculate_cost | Already handles per-1M-tokens conversion and prefix matching |
| Provider discovery | Manual provider lookup | Registry.for_concept(:llm).providers | Centralized, testable, follows existing patterns |
| Model/provider inference | Custom string parsing | LlmUsage.infer_provider | Already handles prefix matching across providers |

**Key insight:** The registry and cost calculation systems are mature. Follow the patterns exactly — don't invent new approaches for consistency's sake.

</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

### Pitfall 1: Missing ENV Fallback
**What goes wrong:** Provider only checks ENV, ignores Setting model
**Why it happens:** Copying the simple pattern without understanding the full OpenAI implementation
**How to avoid:** Always use `ENV["KEY"].presence \|\| Setting.model_key` pattern
**Warning signs:** Test with ENV unset, Setting populated

### Pitfall 2: Wrong Pricing Structure
**What goes wrong:** Pricing not calculated because format doesn't match expected structure
**Why it happens:** PRICING hash requires specific format: `{ prompt: X.XX, completion: Y.YY }`
**How to avoid:** Match OpenAI pricing format exactly, use symbols for keys
**Warning signs:** `LlmUsage.calculate_cost` returns nil or logs "No pricing found"

### Pitfall 3: Not Adding to available_providers
**What goes wrong:** Registry method exists but provider isn't discoverable
**Why it happens:** Adding the method but forgetting to update the case statement
**How to avoid:** Add symbol to appropriate concept array in `available_providers`
**Warning signs:** `Registry.for_concept(:llm).providers` doesn't include Anthropic

### Pitfall 4: Using Full Model Names in Pricing
**What goes wrong:** Specific model versions like "claude-sonnet-4-5-20250929" don't match
**Why it happens:** Not understanding that prefix matching is used
**How to avoid:** Use base model names ("claude-sonnet-4"), let prefix matching handle versions
**Warning signs:** Pricing not found for versioned model names

</common_pitfalls>

<code_examples>
## Code Examples

### Registry Method Pattern
```ruby
# Source: app/models/provider/registry.rb lines 65-79
def openai
  access_token = ENV["OPENAI_ACCESS_TOKEN"].presence || Setting.openai_access_token

  return nil unless access_token.present?

  uri_base = ENV["OPENAI_URI_BASE"].presence || Setting.openai_uri_base
  model = ENV["OPENAI_MODEL"].presence || Setting.openai_model

  if uri_base.present? && model.blank?
    Rails.logger.error("Custom OpenAI provider configured without a model")
    return nil
  end

  Provider::Openai.new(access_token, uri_base: uri_base, model: model)
end
```

### Pricing Hash Pattern
```ruby
# Source: app/models/llm_usage.rb lines 15-41
PRICING = {
  "openai" => {
    "gpt-4.1" => { prompt: 2.00, completion: 8.00 },
    "gpt-4o" => { prompt: 2.50, completion: 10.00 },
  }
}.freeze
```

### Cost Calculation Usage
```ruby
# Source: app/models/llm_usage.rb lines 46-62
def self.calculate_cost(model:, prompt_tokens:, completion_tokens:)
  provider = infer_provider(model)
  pricing = find_pricing(provider, model)

  return nil unless pricing

  # Pricing is per 1M tokens
  prompt_cost = (prompt_tokens * pricing[:prompt]) / 1_000_000.0
  completion_cost = (completion_tokens * pricing[:completion]) / 1_000_000.0

  (prompt_cost + completion_cost).round(6)
end
```

### Available Providers Pattern
```ruby
# Source: app/models/provider/registry.rb lines 106-117
def available_providers
  case concept
  when :llm
    %i[openai]  # Add :anthropic here
  else
    %i[plaid_us plaid_eu github openai]
  end
end
```

</code_examples>

<sota_updates>
## State of the Art (2024-2025)

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| N/A (new feature) | Following OpenAI patterns | Phase 1 | Registry and pricing patterns are established, mature |

**Anthropic pricing current as of:** January 2025 (from official docs)

**Model availability:**
- Claude Opus 4: $15/$75 per MTok (input/output)
- Claude Sonnet 4/3.7/3.5: $3/$15 per MTok
- Claude Haiku 3.5: $0.80/$4 per MTok
- Claude Haiku 3: $0.25/$1.25 per MTok

**Note:** Anthropic uses "input" and "output" terminology. Map to "prompt" and "completion" for consistency with existing codebase.

</sota_updates>

<open_questions>
## Open Questions

None. This is internal code following established patterns. All requirements are clear from the existing OpenAI implementation.

</open_questions>

<sources>
## Sources

### Primary (HIGH confidence)
- **app/models/provider/registry.rb** - Provider registration and discovery patterns
- **app/models/llm_usage.rb** - Cost calculation and pricing structure
- **app/models/provider/anthropic.rb** - Existing Anthropic provider class (Phase 1)
- **app/models/provider/openai.rb** - OpenAI implementation to mirror
- **Official Anthropic pricing docs** (https://docs.anthropic.com/en/docs/about-claude/pricing) - Current Claude model pricing

### Secondary (MEDIUM confidence)
- None - all findings from codebase analysis

### Tertiary (LOW confidence - needs validation)
- None

</sources>

<metadata>
## Metadata

**Research scope:**
- Core technology: Internal provider registry and LlmUsage patterns
- Ecosystem: None (internal codebase only)
- Patterns: Provider registration, cost calculation, provider discovery
- Pitfalls: Configuration fallbacks, pricing format, available_providers

**Confidence breakdown:**
- Standard stack: HIGH - verified with codebase analysis
- Architecture: HIGH - patterns directly from existing code
- Pitfalls: HIGH - based on common mistakes in similar implementations
- Code examples: HIGH - copied directly from codebase

**Research date:** 2026-01-09
**Valid until:** 2026-02-09 (30 days - internal patterns stable)

</metadata>

---

*Phase: 04-registry-integration*
*Research completed: 2026-01-09*
*Ready for planning: yes*
