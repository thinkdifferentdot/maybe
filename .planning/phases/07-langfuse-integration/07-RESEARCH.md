# Phase 7: Langfuse Integration - Research

**Researched:** 2026-01-10
**Domain:** Langfuse Ruby SDK observability tracing for Anthropic
**Confidence:** HIGH

<research_summary>
## Summary

Researched Langfuse Ruby SDK integration patterns for Anthropic LLM observability. The codebase already uses the `langfuse-ruby` gem (v0.1.4) with established OpenAI integration patterns. The research reveals that:

1. **Existing patterns are sufficient** - The current OpenAI tracing implementation (Provider::Openai) uses standard Langfuse Ruby SDK patterns: `trace()`, `generation()`, and `update()` methods that work identically for Anthropic.

2. **Tool calling representation** - Langfuse has native `tool` observation type for tool calls. For Anthropic's `tool_use`/`tool_result` blocks, we should create child spans with `as_type: :tool` rather than embedding everything in the generation span.

3. **Minimal adaptation required** - The primary differences are token field names (`input_tokens`/`output_tokens` vs `prompt_tokens`/`completion_tokens`) and trace naming prefixes. The core SDK methods remain the same.

**Primary recommendation:** Reuse the existing Langfuse wrapper methods from Provider::Openai, adapting only the token field mapping and trace naming. Use child `tool` observation types for Anthropic's tool_use blocks.
</research_summary>

<standard_stack>
## Standard Stack

The Ruby SDK for Langfuse observability:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| langfuse-ruby | 0.1.4 | Langfuse Ruby SDK | Official Ruby client; already in Gemfile |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| anthropic | ~> 1.16.0 | Anthropic API client | Required for Phase 1 |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| langfuse-ruby | Manual HTTP API calls | SDK handles batching, retries, serialization |

**Installation:**
```bash
# Already installed - verify version
gem list langfuse-ruby
```
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Recommended Project Structure
```
app/models/provider/
├── anthropic.rb              # Main provider with langfuse_client
├── openai.rb                 # Reference implementation
└── anthropic/
    ├── chat_config.rb        # API format conversion (already exists)
    └── chat_parser.rb        # Response parsing (already exists)
```

### Pattern 1: Langfuse Client Initialization
**What:** Lazy-initialized Langfuse client with environment-based configuration
**When to use:** All provider classes needing observability
**Example:**
```ruby
# Source: Existing codebase pattern (Provider::Openai, Provider::Anthropic)
def langfuse_client
  return unless ENV["LANGFUSE_PUBLIC_KEY"].present? && ENV["LANGFUSE_SECRET_KEY"].present?

  @langfuse_client = Langfuse.new
end
```

### Pattern 2: Trace and Generation Pattern
**What:** Create a trace, add a generation span, update with results
**When to use:** LLM API calls (chat, categorize, merchant detection)
**Example:**
```ruby
# Source: Adapted from Provider::Openai#log_langfuse_generation
def log_langfuse_generation(name:, model:, input:, output: nil, usage: nil, error: nil, session_id: nil, user_identifier: nil)
  return unless langfuse_client

  trace = create_langfuse_trace(
    name: "anthropic.#{name}",  # Prefix with "anthropic."
    input: input,
    session_id: session_id,
    user_identifier: user_identifier
  )

  generation = trace&.generation(
    name: name,
    model: model,
    input: input
  )

  if error
    generation&.end(
      output: { error: error.message },
      level: "ERROR"
    )
    trace&.update(
      output: { error: error.message },
      level: "ERROR"
    )
  else
    generation&.end(output: output, usage: usage)
    trace&.update(output: output)
  end
rescue => e
  Rails.logger.warn("Langfuse logging failed: #{e.message}")
end
```

### Pattern 3: Token Field Mapping
**What:** Convert Anthropic usage fields to Langfuse format
**When to use:** Processing Anthropic API responses
**Example:**
```ruby
# Source: Existing codebase pattern (Provider::Anthropic#chat_response)
# Anthropic uses input_tokens/output_tokens, Langfuse expects prompt_tokens/completion_tokens
usage = {
  "prompt_tokens" => raw_response.dig("usage", "input_tokens"),
  "completion_tokens" => raw_response.dig("usage", "output_tokens"),
  "total_tokens" => raw_response.dig("usage", "input_tokens").to_i + raw_response.dig("usage", "output_tokens").to_i
}
```

### Anti-Patterns to Avoid
- **Creating multiple clients:** Use memoized `@langfuse_client` instance, not `Langfuse.new` per request
- **Skipping error handling:** Langfuse API calls should never break application flow
- **Hardcoding trace names:** Use provider prefix (`anthropic.` vs `openai.`) for filtering
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTTP batching to Langfuse | Custom background job for traces | SDK's built-in queue/batch | SDK handles retries, network errors, buffer management |
| Token cost calculation | Manual per-model pricing | LlmUsage.calculate_cost | Already implemented; handles all models |
| Tool span structure | Custom JSON for tool_use | SDK's tool observation type | Native UI support for tool call filtering |

**Key insight:** The langfuse-ruby SDK (v0.1.4) already provides the necessary observability primitives. Reusing the Provider::Openai patterns ensures consistency across providers.
</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

### Pitfall 1: Token Field Name Mismatch
**What goes wrong:** Langfuse traces show 0 tokens or missing cost data
**Why it happens:** Anthropic uses `input_tokens`/`output_tokens`, Langfuse expects `prompt_tokens`/`completion_tokens`
**How to avoid:** Always map Anthropic usage fields to Langfuse format before logging
**Warning signs:** Cost tracking shows $0.00 for Anthropic requests

### Pitfall 2: Missing Trace Context
**What goes wrong:** Traces appear but can't be filtered by user or session
**Why it happens:** Forgetting to pass `session_id` and `user_identifier` to trace creation
**How to avoid:** Always include session/user context when creating traces
**Warning signs:** Unable to find specific user's activity in Langfuse UI

### Pitfall 3: Tool Calls Not Visible
**What goes wrong:** Tool calling happens but traces don't show individual tool invocations
**Why it happens:** Only logging the generation span, not creating child spans for tool_use blocks
**How to avoid:** Create child `tool` observation spans for each tool_use block (future enhancement)
**Warning signs:** Can't debug which tools were called or why they failed

### Pitfall 4: Langfuse Errors Breaking Application
**What goes wrong:** Langfuse API downtime causes application failures
**Why it happens:** Not rescuing Langfuse client errors
**How to avoid:** Wrap all Langfuse calls in rescue blocks, log warnings only
**Warning signs:** 500 errors when Langfuse is unreachable
</common_pitfalls>

<code_examples>
## Code Examples

Verified patterns from existing codebase:

### Client Configuration
```ruby
# Source: config/initializers/langfuse.rb
require "langfuse"

if ENV["LANGFUSE_PUBLIC_KEY"].present? && ENV["LANGFUSE_SECRET_KEY"].present?
  Langfuse.configure do |config|
    config.public_key = ENV["LANGFUSE_PUBLIC_KEY"]
    config.secret_key = ENV["LANGFUSE_SECRET_KEY"]
    config.host = ENV["LANGFUSE_HOST"] if ENV["LANGFUSE_HOST"].present?
  end
end
```

### Trace Creation for Operations
```ruby
# Source: Provider::Anthropic (already implemented)
trace = create_langfuse_trace(
  name: "anthropic.auto_categorize",
  input: { transactions: transactions, user_categories: user_categories }
)

result = AutoCategorizer.new(
  client,
  model: effective_model,
  transactions: transactions,
  user_categories: user_categories,
  langfuse_trace: trace,  # Pass trace to sub-operation
  family: family
).auto_categorize

trace&.update(output: result.map(&:to_h))
```

### Usage Field Mapping
```ruby
# Source: Provider::Anthropic#chat_response (already implemented)
# Map Anthropic usage field names to LlmConcept format
usage = {
  "prompt_tokens" => raw_response.dig("usage", "input_tokens"),
  "completion_tokens" => raw_response.dig("usage", "output_tokens"),
  "total_tokens" => raw_response.dig("usage", "input_tokens").to_i + raw_response.dig("usage", "output_tokens").to_i
}
```

### Error Handling
```ruby
# Source: Provider::Anthropic (already implemented)
def log_langfuse_generation(name:, model:, input:, output: nil, usage: nil, error: nil, session_id: nil, user_identifier: nil)
  return unless langfuse_client

  trace = create_langfuse_trace(...)
  generation = trace&.generation(...)

  if error
    generation&.end(output: { error: error.message }, level: "ERROR")
    trace&.update(output: { error: error.message }, level: "ERROR")
  else
    generation&.end(output: output, usage: usage)
    trace&.update(output: output)
  end
rescue => e
  Rails.logger.warn("Langfuse logging failed: #{e.message}")
end
```
</code_examples>

<sota_updates>
## State of the Art (2024-2025)

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual HTTP calls to Langfuse API | langfuse-ruby SDK | 2024 | SDK handles batching, retries |
| Generic spans only | Specialized observation types (tool, agent, etc.) | 2024 | Better filtering in Langfuse UI |
| Token tracking only | Token + cost tracking via LlmUsage | Existing | Already implemented in codebase |

**New tools/patterns to consider:**
- **Tool observation type:** Langfuse now supports `as_type: :tool` for instrumenting individual tool calls (not yet implemented in codebase)
- **OpenTelemetry instrumentation:** Python/JS SDKs support OTel-based auto-instrumentation for Anthropic; Ruby SDK does not yet have this

**Deprecated/outdated:**
- **Manual trace flushing:** SDK v0.1.x handles this automatically; only needed for short-lived scripts
</sota_updates>

<open_questions>
## Open Questions

1. **Tool call span structure**
   - What we know: Langfuse supports `tool` observation type for child spans
   - What's unclear: Whether to create child spans for tool_use immediately or defer
   - Recommendation: Start with basic generation spans (already implemented), add tool spans as enhancement

2. **Streaming support**
   - What we know: Anthropic supports streaming via `messages.stream`
   - What's unclear: How to trace streaming generations in Langfuse Ruby SDK
   - Recommendation: Defer until Phase 03-04 (streaming support marked as deferred)

</open_questions>

<sources>
## Sources

### Primary (HIGH confidence)
- Langfuse Ruby SDK GitHub (simplepractice/langfuse-rb) - README and API patterns
- Langfuse Documentation - Observation Types
- Langfuse Documentation - Anthropic Integration Guide
- Existing codebase - Provider::Openai langfuse implementation
- Existing codebase - Provider::Anthropic current langfuse implementation

### Secondary (MEDIUM confidence)
- RubyGems - langfuse-ruby gem version history
- Langfuse Documentation - Tracing Concepts

### Tertiary (LOW confidence - needs validation)
- None - all findings verified against codebase or official docs
</sources>

<metadata>
## Metadata

**Research scope:**
- Core technology: Langfuse Ruby SDK (langfuse-ruby v0.1.4)
- Ecosystem: Anthropic Ruby gem integration
- Patterns: Trace/generation pattern from existing OpenAI implementation
- Pitfalls: Token field mapping, error handling, tool call representation

**Confidence breakdown:**
- Standard stack: HIGH - gem already in codebase, verified version
- Architecture: HIGH - patterns adapted from working OpenAI implementation
- Pitfalls: HIGH - based on existing codebase patterns and official docs
- Code examples: HIGH - from actual codebase implementation

**Research date:** 2026-01-10
**Valid until:** 2025-02-10 (30 days - stable SDK, minimal changes expected)
</metadata>

---

*Phase: 07-langfuse-integration*
*Research completed: 2026-01-10*
*Ready for planning: yes*
