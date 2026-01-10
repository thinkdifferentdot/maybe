# Phase 1: Foundation - Research

**Researched:** 2025-01-09
**Domain:** Anthropic Ruby gem integration into Rails 7.2 app
**Confidence:** HIGH

<research_summary>
## Summary

Researched the official Anthropic Ruby SDK for adding Claude support to Sure. The standard approach uses the official `anthropic` gem (v1.16.0+) maintained by Anthropic, which provides a well-designed Ruby interface to Claude's Messages API with streaming support, tool calling, and comprehensive error handling.

Key finding: The official Anthropic Ruby SDK requires Ruby 3.2+, but Sure currently uses Ruby 3.4.7, so version compatibility is excellent. The SDK follows patterns similar to the existing `ruby-openai` gem already in use, making the implementation straightforward.

**Primary recommendation:** Use the official `anthropic` gem from Anthropic. Mirror the existing `Provider::Openai` architecture: create `Provider::Anthropic` class inheriting from `Provider`, include `LlmConcept`, and implement the three required methods (auto_categorize, auto_detect_merchants, chat_response).
</research_summary>

<standard_stack>
## Standard Stack

The established libraries/tools for Anthropic Claude integration in Ruby:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| anthropic | ~> 1.16.0 | Official Anthropic Ruby SDK | Maintained by Anthropic, comprehensive API coverage, streaming support |
| ruby-openai | 8.1.0 | Existing OpenAI gem (already in Gemfile) | Reference architecture for patterns to follow |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| langfuse-ruby | ~> 0.1.4 | Observability tracing (already installed) | Reuse for Anthropic request tracing |
| connection_pool | (bundled with anthropic) | HTTP connection pooling | Automatic with SDK |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| anthropic (official) | ruby-anthropic (community) | Community gem renamed to make way for official; use official for long-term support |
| Direct HTTP calls | Faraday/HTTParty | More control but lose retry logic, streaming helpers, tool calling support |

**Installation:**
```bash
# Add to Gemfile in the AI section (near ruby-openai)
gem "anthropic", "~> 1.16.0"

# Then bundle
bundle install
```
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Recommended Class Structure
```
app/models/provider/
├── anthropic.rb              # Main provider class (mirror openai.rb)
├── anthropic/
│   ├── auto_categorizer.rb   # Categorization logic
│   ├── auto_merchant_detector.rb  # Merchant detection
│   └── chat_parser.rb        # Response parsing for chat
```

### Pattern 1: Provider::Anthropic Class Structure
**What:** Mirror the existing `Provider::Openai` architecture
**When to use:** As the primary pattern for all LLM providers
**Example:**
```ruby
# app/models/provider/anthropic.rb
class Provider::Anthropic < Provider
  include LlmConcept

  Error = Class.new(Provider::Error)

  DEFAULT_ANTHROPIC_MODEL_PREFIXES = %w[claude-]
  DEFAULT_MODEL = "claude-sonnet-4-5-20250929"

  def initialize(access_token, model: nil)
    @client = ::Anthropic::Client.new(api_key: access_token)
    @default_model = model.presence || DEFAULT_MODEL
  end

  def provider_name
    "Anthropic"
  end

  def auto_categorize(transactions: [], user_categories: [], model: "", family: nil, json_mode: nil)
    # Implementation uses Anthropic::Client#messages.create
  end

  def auto_detect_merchants(transactions: [], user_merchants: [], model: "", family: nil, json_mode: nil)
    # Implementation uses Anthropic::Client#messages.create
  end

  def chat_response(prompt, model:, instructions: nil, functions: [], ...)
    # Implementation uses Anthropic's tool calling (tools parameter)
  end
end
```

### Pattern 2: Client Initialization
**What:** Create Anthropic client with API key from ENV or Settings
**When to use:** In Provider::Registry#anthropic method
**Example:**
```ruby
def anthropic
  access_token = ENV["ANTHROPIC_API_KEY"].presence || Setting.anthropic_api_key
  return nil unless access_token.present?

  model = ENV["ANTHROPIC_MODEL"].presence || Setting.anthropic_model
  Provider::Anthropic.new(access_token, model: model)
end
```

### Pattern 3: Messages API Call
**What:** Use Anthropic's messages.create for structured outputs
**When to use:** For auto_categorize and auto_detect_merchants
**Example:**
```ruby
response = client.messages.create(
  model: model,
  system: instructions,
  messages: [{role: "user", content: user_message}],
  max_tokens: 4096
)

# Extract content from response
content = response.content.find { |block| block.type == "text" }&.text
usage = response.usage # {input_tokens:, output_tokens:, total_tokens:}
```

### Anti-Patterns to Avoid
- **Using the community ruby-anthropic gem:** It was renamed to make way for the official SDK; use official `anthropic` gem instead
- **Not handling tool calling format:** Anthropic uses `tools` array with different structure than OpenAI's `functions`
- **Ignoring streaming differences:** Anthropic streaming returns SSE events, not the same format as OpenAI
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTTP retry logic | Custom retry loops with exponential backoff | Built-in SDK retries (max_retries option) | SDK handles 408, 429, 5xx errors automatically |
| Connection pooling | Thread.unsafe single client | SDK's built-in connection_pool (size: 99) | SDK is thread-safe and fork-safe |
| Tool calling execution | Manual tool loop with state | SDK's beta.messages.tool_runner | Handles multi-turn tool execution automatically |
| Streaming parsing | Manual SSE parsing | stream.text.each helper | SDK provides streaming helpers |
| Error handling | Rescue StandardError | Anthropic::Errors::APIError hierarchy | Specific error types for different HTTP status codes |

**Key insight:** The official SDK has ~2 years of production battle-testing. Hand-rolling HTTP logic for authentication, retries, streaming, and error handling leads to bugs that surface at scale (rate limiting, network blips, timeouts).
</dont_hand_roll>

<common_pitfalls>
## Pitfall 1: Ruby Version Incompatibility
**What goes wrong:** Official SDK requires Ruby 3.2+
**Why it happens:** SDK uses modern Ruby features (RBS types, pattern matching)
**How to avoid:** Verify Ruby version - Sure uses 3.4.7, which is compatible
**Warning signs:** Gem install fails with syntax errors

### Pitfall 2: API Key Configuration Mismatch
**What goes wrong:** SDK doesn't find API key because environment variable name differs
**Why it happens:** OpenAI uses `OPENAI_ACCESS_TOKEN`, Anthropic uses `ANTHROPIC_API_KEY`
**How to avoid:** Use consistent naming: `ANTHROPIC_API_KEY` for ENV, `anthropic_api_key` for Setting
**Warning signs:** 401 AuthenticationError from Anthropic API

### Pitfall 3: Tool Calling Format Differences
**What goes wrong:** Passing OpenAI-style `functions` parameter to Anthropic
**Why it happens:** Anthropic uses `tools` array with different schema
**How to avoid:** Convert function definitions to Anthropic tool format:
```ruby
# Anthropic tool format
tools: [{
  name: "function_name",
  description: "...",
  input_schema: { type: "object", properties: {...} }
}]
```
**Warning signs:** 400 BadRequestError with "invalid request"

### Pitfall 4: Streaming Response Format
**What goes wrong:** Assuming streaming returns same format as non-streaming
**Why it happens:** Anthropic streaming returns SSE events, not a complete response
**How to avoid:** Use `stream.text.each` helper or handle raw events
**Warning signs:** Incomplete response data, missing usage metadata

### Pitfall 5: Model Name Mismatch
**What goes wrong:** Using OpenAI model names like "gpt-4" with Anthropic
**Why it happens:** Copy-pasting from OpenAI code
**How to avoid:** Use Anthropic model IDs: `claude-sonnet-4-5-20250929`, `claude-opus-4-5-20251101`, etc.
**Warning signs:** 400 BadRequestError with "invalid model"
</common_pitfalls>

<code_examples>
## Code Examples

### Basic Anthropic Client Setup
```ruby
# Source: Official Anthropic Ruby SDK documentation
require "anthropic"

client = Anthropic::Client.new(
  api_key: ENV["ANTHROPIC_API_KEY"] # Default, can be omitted
)

message = client.messages.create(
  max_tokens: 1024,
  messages: [{role: "user", content: "Hello, Claude"}],
  model: :"claude-sonnet-4-5-20250929"
)

puts(message.content)
```

### Messages API with System Prompt
```ruby
# Source: Official SDK docs + Sure patterns
response = client.messages.create(
  model: "claude-sonnet-4-5-20250929",
  max_tokens: 4096,
  system: "You are a helpful assistant for personal finance.",
  messages: [{role: "user", content: "Categorize these transactions..."}]
)

# Extract usage for cost tracking
usage = response.usage
# => #<Anthropic::Models::MessageUsage input_tokens: 123, output_tokens: 45, total_tokens: 168>
```

### Streaming with Helper
```ruby
# Source: Official SDK documentation
stream = client.messages.stream(
  max_tokens: 1024,
  messages: [{role: :user, content: "Say hello there!"}],
  model: :"claude-sonnet-4-5-20250929"
)

stream.text.each do |text|
  print(text)
end
```

### Tool Calling (Anthropic Format)
```ruby
# Source: Official SDK docs - helpers.md
class CalculatorInput < Anthropic::BaseModel
  required :lhs, Float
  required :rhs, Float
  required :operator, Anthropic::InputSchema::EnumOf[:+, :-, :*, :/]
end

class Calculator < Anthropic::BaseTool
  input_schema CalculatorInput

  def call(expr)
    expr.lhs.public_send(expr.operator, expr.rhs)
  end
end

# Automatically handles tool execution loop
client.beta.messages.tool_runner(
  model: "claude-sonnet-4-5-20250929",
  max_tokens: 1024,
  messages: [{role: "user", content: "What's 15 * 7?"}],
  tools: [Calculator.new]
).each_message { puts _1.content }
```

### Error Handling Pattern
```ruby
# Source: Official SDK documentation
begin
  message = client.messages.create(...)
rescue Anthropic::Errors::APIConnectionError => e
  Rails.logger.error("Anthropic server unreachable: #{e.cause}")
rescue Anthropic::Errors::RateLimitError => e
  Rails.logger.warn("Anthropic rate limit hit, back off needed")
rescue Anthropic::Errors::AuthenticationError => e
  Rails.logger.error("Anthropic API key invalid: #{e.message}")
rescue Anthropic::Errors::APIStatusError => e
  Rails.logger.error("Anthropic API error #{e.status}: #{e.message}")
end
```
</code_examples>

<sota_updates>
## State of the Art (2024-2025)

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Community ruby-anthropic gem | Official anthropic gem | April 2025 | Official support, better compatibility |
| Manual streaming parsing | SDK streaming helpers (stream.text.each) | v1.16.0 (Nov 2025) | Simpler streaming code |
| Manual tool execution loop | beta.messages.tool_runner | v1.16.0 | Automatic multi-turn tool handling |

**New tools/patterns to consider:**
- **BaseModel/BaseTool:** Strongly-typed input schemas for tools with automatic validation
- **Connection pooling:** Built-in with 99 connection pool size per client instance
- **AWS Bedrock support:** Same SDK supports Bedrock via `Anthropic::BedrockClient`
- **Google Vertex support:** Same SDK supports Vertex via `Anthropic::VertexClient`

**Deprecated/outdated:**
- **ruby-anthropic community gem:** Renamed to make way for official SDK; no longer recommended
- **anthropic gem name conflict:** Community gem renamed to `ruby-anthropic` to avoid confusion
</sota_updates>

<open_questions>
## Open Questions

1. **Anthropic model naming convention for Settings**
   - What we know: Anthropic models use date-based versioning (claude-sonnet-4-5-20250929)
   - What's unclear: How to present model options in UI (dropdown with specific dates or friendly names?)
   - Recommendation: Use friendly names in Settings ("Claude Sonnet 4.5"), map to specific model ID internally

2. **Streaming support for chat_response**
   - What we know: OpenAI provider supports streaming, Anthropic SDK has streaming helpers
   - What's unclear: Should Phase 1 include streaming or defer to later phase?
   - Recommendation: Defer streaming to Phase 3 (Chat Support) as specified in roadmap

3. **Langfuse integration format for Anthropic**
   - What we know: OpenAI provider uses Langfuse for observability tracing
   - What's unclear: Exact format for Anthropic traces in Langfuse
   - Recommendation: Mirror OpenAI pattern, verify in Phase 7 (Langfuse Integration)
</open_questions>

<sources>
## Sources

### Primary (HIGH confidence)
- [anthropics/anthropic-sdk-ruby](https://github.com/anthropics/anthropic-sdk-ruby) - Official Anthropic Ruby SDK documentation, installation, usage examples
- [Official Anthropic Ruby SDK GitHub README](https://github.com/anthropics/anthropic-sdk-ruby) - Complete API reference, streaming, tool calling, error handling

### Secondary (MEDIUM confidence)
- [alexrudall/ruby-anthropic](https://github.com/alexrudall/ruby-anthropic) - Community gem (now renamed, for context on deprecation)
- [Ruby AI News 2025](https://rubyai.beehiiv.com/p/ruby-ai-news-july-8th-2025-389f029dedf446ae) - Context on official SDK release

### Tertiary (LOW confidence - needs validation)
- None - all findings verified against official sources
</sources>

<metadata>
## Metadata

**Research scope:**
- Core technology: Anthropic Ruby SDK (official)
- Ecosystem: Ruby 3.4.7, Rails 7.2, langfuse-ruby
- Patterns: Messages API, streaming, tool calling, error handling
- Pitfalls: Version compatibility, API key config, model naming, response formats

**Confidence breakdown:**
- Standard stack: HIGH - official SDK from Anthropic, widely adopted
- Architecture: HIGH - mirrors existing OpenAI provider patterns in codebase
- Pitfalls: HIGH - documented in official SDK with examples
- Code examples: HIGH - from official SDK documentation

**Research date:** 2025-01-09
**Valid until:** 2025-02-08 (30 days - stable API, official SDK)
</metadata>

---

*Phase: 01-foundation*
*Research completed: 2025-01-09*
*Ready for planning: yes*
