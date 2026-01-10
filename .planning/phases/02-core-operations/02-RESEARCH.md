# Phase 2: Core Operations - Research

**Researched:** 2025-01-09
**Domain:** Anthropic Ruby SDK + Messages API for structured outputs
**Confidence:** HIGH

<research_summary>
## Summary

Researched the official Anthropic Ruby SDK and Messages API for implementing auto-categorization and merchant detection. The official `anthropic` gem (v1.16.0+) provides a clean Ruby interface to Anthropic's Claude API with native support for structured outputs via the beta header `structured-outputs-2025-11-13`.

Key finding: Anthropic's approach to structured outputs differs from OpenAI. Anthropic uses a beta header with constrained decoding for guaranteed JSON schema compliance, while OpenAI uses native `json_schema` response format. The Ruby SDK provides `Anthropic::BaseModel` and `Anthropic::BaseTool` helper classes for defining structured data schemas.

**Primary recommendation:** Use the official `anthropic` gem (v1.16.0+), not the community `ruby-anthropic` gem. Implement `AutoCategorizer` and `AutoMerchantDetector` classes following the existing OpenAI provider pattern, using Anthropic's Messages API with structured outputs for reliable JSON responses.
</research_summary>

<standard_stack>
## Standard Stack

The established libraries/tools for Anthropic integration in Ruby:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| anthropic | ~> 1.16.0 | Official Anthropic Ruby SDK | Maintained by Anthropic, active development, supports latest Claude models |
| ruby-openai | ~0.7.0 | Existing OpenAI provider | Already in Gemfile, provides pattern to follow |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| langfuse-ruby | ~> 0.1.4 | Observability tracing | Already used for OpenAI, adapt for Anthropic |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| anthropic (official) | ruby-anthropic | Community gem renamed to make way for official SDK; use official for new projects |

**Installation:**
```ruby
# Add to Gemfile
gem "anthropic", "~> 1.16.0"
```

**Ruby version requirement:** Ruby 3.2.0+
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Recommended Project Structure
Following the existing OpenAI provider pattern:
```
app/models/provider/
├── anthropic.rb              # Main provider class (inherits from Provider)
├── anthropic/
    ├── auto_categorizer.rb   # Categorization logic
    ├── auto_merchant_detector.rb  # Merchant detection logic
    └── concerns/
        └── usage_recorder.rb  # LLM usage tracking (shared with OpenAI)
```

### Pattern 1: Provider Class Structure
**What:** Create `Provider::Anthropic` inheriting from `Provider`, including `LlmConcept`
**When to use:** For all LLM providers in the app
**Example:**
```ruby
# Source: Based on app/models/provider/openai.rb
class Provider::Anthropic < Provider
  include LlmConcept

  Error = Class.new(Provider::Error)

  DEFAULT_MODEL = "claude-sonnet-4-5-20250929"

  def initialize(access_token, model: nil)
    @client = Anthropic::Client.new(api_key: access_token)
    @default_model = model.presence || DEFAULT_MODEL
  end

  def auto_categorize(transactions:, user_categories:, model: "", family: nil)
    # Delegate to AutoCategorizer
  end
end
```

### Pattern 2: Messages API with Structured Outputs
**What:** Use `anthropic.messages.create` with `betas` header for structured outputs
**When to use:** For any operation requiring guaranteed JSON schema compliance
**Example:**
```ruby
# Source: anthropic-sdk-ruby official docs
response = client.messages.create(
  model: "claude-sonnet-4-5-20250929",
  max_tokens: 1024,
  messages: [{role: "user", content: "Categorize these transactions"}],
  betas: ["structured-outputs-2025-11-13"]
)
```

### Pattern 3: Tool Calling for Structured Outputs
**What:** Use `Anthropic::BaseTool` and `Anthropic::BaseModel` for type-safe tool definitions
**When to use:** For complex tool-based workflows (Phase 3 - chat support)
**Example:**
```ruby
# Source: anthropic-sdk-ruby helpers.md
class CategorizeInput < Anthropic::BaseModel
  required :transactions, Array[Hash]
  required :categories, Array[String]
end

class CategorizeTool < Anthropic::BaseTool
  input_schema CategorizeInput

  def call(input)
    # Process categorization
  end
end
```

### Anti-Patterns to Avoid
- **Using the old `ruby-anthropic` gem:** It was renamed; use official `anthropic` gem instead
- **Not handling error types:** Anthropic SDK has specific error types (`RateLimitError`, `APIConnectionError`, etc.)
- **Ignoring rate limits:** Anthropic has default rate limits; implement proper backoff
- **Using `json_schema` response format like OpenAI:** Anthropic uses beta headers for structured outputs
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON schema validation | Custom regex/parsing | Anthropic structured outputs (beta header) | Guaranteed schema compliance via constrained decoding |
| Type-safe tool definitions | Manual hash schemas | `Anthropic::BaseTool`, `Anthropic::BaseModel` | Automatic schema generation, validation |
| Error handling | Generic rescue | Specific `Anthropic::Errors::*` classes | Proper error classification, retry logic |
| HTTP connection management | Custom net/http code | Built-in connection pooling in SDK | Thread-safe, auto-retries, connection reuse |

**Key insight:** The official SDK handles retry logic (2 attempts by default), connection pooling, and proper error classification. Hand-rolling these leads to bugs, especially around rate limits and transient failures.
</dont_hand_roll>

<common_pitfalls>
## Pitfall 1: Beta Header Required for Structured Outputs
**What goes wrong:** Making requests without the `betas: ["structured-outputs-2025-11-13"]` header, resulting in validation errors or unstructured responses
**Why it happens:** Structured outputs are a public beta feature requiring explicit opt-in via header
**How to avoid:** Always include `betas: ["structured-outputs-2025-11-13"]` when using `output_format` or `strict: true` on tools
**Warning signs:** Responses that don't match schema, or 400 errors about invalid response format

### Pitfall 2: Confusing Model IDs
**What goes wrong:** Using wrong model format like "claude-sonnet-4.5" instead of "claude-sonnet-4-5-20250929"
**Why it happens:** Anthropic model IDs have date suffixes, different from OpenAI's naming
**How to avoid:** Use model constants, reference official docs for current model names
**Warning signs:** 400/404 errors about invalid model

### Pitfall 3: Not Handling Thinking Model Output
**What goes wrong:** JSON parsing fails when reasoning tags are present in response
**Why it happens:** Some models output reasoning before final answer
**How to avoid:** Extract text from `message` type blocks, not reasoning blocks
**Warning signs:** JSON parse errors, malformed JSON in response

### Pitfall 4: Response Format Differences from OpenAI
**What goes wrong:** Trying to use OpenAI-style `json_schema` in `response_format`
**Why it happens:** Anthropic uses different API structure for structured outputs
**How to avoid:** Use Anthropic's beta header approach or tool-based strict schemas
**Warning signs:** 400 errors, responses not matching expected format
</common_pitfalls>

<code_examples>
## Code Examples

Verified patterns from official sources:

### Basic Anthropic Client Initialization
```ruby
# Source: https://github.com/anthropics/anthropic-sdk-ruby
require "anthropic"

anthropic = Anthropic::Client.new(
  api_key: ENV["ANTHROPIC_API_KEY"] # This is the default and can be omitted
)

# Make a simple request
message = anthropic.messages.create(
  max_tokens: 1024,
  messages: [{role: "user", content: "Hello, Claude"}],
  model: :"claude-opus-4-5-20251101"
)
```

### Messages API for Categorization (Conceptual)
```ruby
# Source: Adapted from OpenAI provider pattern + Anthropic SDK docs
def auto_categorize Anthropic
  response = @client.messages.create(
    model: model.presence || @default_model,
    max_tokens: 1024,
    messages: [
      {role: "user", content: developer_message}
    ],
    system: instructions,
    betas: ["structured-outputs-2025-11-13"]
  )

  # Extract content from response
  content = response.content.find { |block| block.type == "text" }&.text
  categorizations = JSON.parse(content).dig("categorizations")

  build_response(categorizations)
end
```

### Error Handling Pattern
```ruby
# Source: anthropic-sdk-ruby README
begin
  message = anthropic.messages.create(
    max_tokens: 1024,
    messages: [{role: "user", content: "Hello, Claude"}],
    model: :"claude-opus-4-5-20251101"
  )
rescue Anthropic::Errors::APIConnectionError => e
  puts("The server could not be reached")
  puts(e.cause)
rescue Anthropic::Errors::RateLimitError => e
  puts("A 429 status code was received; we should back off.")
rescue Anthropic::Errors::APIStatusError => e
  puts("Another non-200-range status code was received")
  puts(e.status)
end
```
</code_examples>

<sota_updates>
## State of the Art (2024-2025)

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| ruby-anthropic (community) | anthropic (official SDK) | April 2025 | Official SDK maintained by Anthropic, newer features |
| Standard JSON responses | Structured outputs (beta) | Nov 2025 | Guaranteed schema compliance via constrained decoding |
| Manual JSON parsing | SDK BaseModel/BaseTool helpers | Nov 2025 | Type-safe tool definitions, automatic schema generation |

**New tools/patterns to consider:**
- **Structured outputs beta (2025-11-13):** Guaranteed JSON schema compliance, no more parse errors
- **Tool calling with strict mode:** Type-safe tool inputs using `strict: true`
- **Computer Use v5:** Available in latest SDK (not needed for Phase 2, but noted for future)

**Deprecated/outdated:**
- **ruby-anthropic gem:** Renamed to make way for official SDK; use `anthropic` instead
- **Unconstrained JSON generation:** Use structured outputs for reliability
</sota_updates>

<open_questions>
## Open Questions

1. **Should we use tool-based or response-format-based structured outputs?**
   - What we know: Anthropic supports both `output_format` (response-level) and `strict: true` on tools
   - What's unclear: Which approach is more maintainable for categorization/merchant detection
   - Recommendation: Start with response-level `output_format` (simpler), consider tools for Phase 3 chat

2. **How should we handle JSON mode configuration like the OpenAI provider?**
   - What we know: OpenAI provider has `json_mode` settings (strict, json_object, none, auto)
   - What's unclear: Anthropic's structured outputs are always strict; no equivalent "none" mode
   - Recommendation: Don't implement json_mode for Anthropic; structured outputs are always reliable

3. **What model should be the default for Anthropic?**
   - What we know: Claude Sonnet 4.5 (claude-sonnet-4-5-20250929) is the balanced choice
   - What's unclear: User preference, cost considerations
   - Recommendation: Use Sonnet 4.5 as default (like OpenAI uses gpt-4.1), allow configuration
</open_questions>

<sources>
## Sources

### Primary (HIGH confidence)
- [anthropics/anthropic-sdk-ruby GitHub](https://github.com/anthropics/anthropic-sdk-ruby) - Official Ruby SDK, installation, usage patterns
- [Anthropic Structured Outputs Docs](https://platform.claude.com/docs/en/build-with-claude/structured-outputs) - Official structured outputs guide
- [RubyDoc for anthropic-sdk-ruby](https://www.rubydoc.info/github/anthropics/anthropic-sdk-ruby/main) - API reference

### Secondary (MEDIUM confidence)
- [alexrudall/ruby-anthropic GitHub](https://github.com/alexrudall/ruby-anthropic) - Community gem (for context on rename)

### Tertiary (LOW confidence - needs validation)
- None - all findings verified against official sources
</sources>

<metadata>
## Metadata

**Research scope:**
- Core technology: Anthropic Ruby SDK (anthropic gem ~> 1.16.0)
- Ecosystem: Messages API, structured outputs, error handling
- Patterns: Provider class structure, AutoCategorizer/AutoMerchantDetector pattern
- Pitfalls: Beta headers, model IDs, response format differences

**Confidence breakdown:**
- Standard stack: HIGH - official SDK from Anthropic, well-documented
- Architecture: HIGH - based on existing OpenAI provider pattern in codebase
- Pitfalls: HIGH - documented in official docs and common issues
- Code examples: HIGH - from official GitHub and docs

**Research date:** 2025-01-09
**Valid until:** 2025-02-09 (30 days - Anthropic SDK is actively developed)
</metadata>

---

*Phase: 02-core-operations*
*Research completed: 2025-01-09*
*Ready for planning: yes*
