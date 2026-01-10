# Phase 3: Chat Support - Research

**Researched:** 2025-01-09
**Domain:** Anthropic Messages API with tool calling in Ruby on Rails
**Confidence:** HIGH

<research_summary>
## Summary

Researched the official Anthropic Ruby SDK (`anthropic` gem ~> 1.16.0) for implementing chat_response with tool/function calling support. The standard approach uses the Messages API with client-side tools defined via JSON Schema, following the established OpenAI provider patterns in the Sure codebase.

Key finding: The Anthropic Ruby SDK provides a `beta.messages.tool_runner` helper that automatically handles the tool execution loop (tool_use → tool_result → next message), but for Rails integration following Sure's patterns, manual tool handling is more appropriate to maintain consistency with the existing Provider::Openai architecture.

**Primary recommendation:** Use the official `anthropic` gem with manual tool handling following the OpenAI provider's ChatConfig/ChatParser pattern. Implement streaming support using `anthropic.messages.stream` with the `.text` helper for incremental text delivery.
</research_summary>

<standard_stack>
## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| anthropic | ~> 1.16.0 | Official Anthropic Ruby SDK | Maintained by Anthropic, comprehensive type definitions, streaming support |
| anthropic (gem) | 1.16.0+ | Client for Messages API | Ruby 3.2.0+ required, thread-safe with connection pooling |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| None | - | - | Follow existing Sure patterns (Langfuse, LlmUsage) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Manual tool handling | `beta.messages.tool_runner` | Tool runner auto-handles loops but less control over Langfuse integration and error handling |
| Official SDK | alexrudall/ruby-anthropic | Community gem but official SDK has better type safety and Anthropic backing |

**Installation:**
```bash
# Already in Gemfile from Phase 1
gem "anthropic", "~> 1.16.0"
```
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Recommended Project Structure
Follow existing OpenAI provider structure:
```
app/models/provider/anthropic.rb          # Main provider class (skeleton exists)
app/models/provider/anthropic/
├── chat_config.rb                        # Convert functions to Anthropic tools format
├── chat_parser.rb                        # Parse Anthropic response to LlmConcept format
├── chat_stream_parser.rb                 # Parse streaming events
└── concerns/
    └── usage_recorder.rb                 # Shared usage recording (if needed)
```

### Pattern 1: Anthropic Messages API for Chat
**What:** Use `anthropic.messages.create` for non-streaming, `anthropic.messages.stream` for streaming
**When to use:** All chat_response implementations
**Example:**
```ruby
# Source: Official anthropic gem README
# Non-streaming
message = anthropic.messages.create(
  max_tokens: 1024,
  messages: [{role: "user", content: "Hello, Claude"}],
  model: :"claude-sonnet-4-5-20250929"
)

# Streaming with text helper
stream = anthropic.messages.stream(
  max_tokens: 1024,
  messages: [{role: :user, content: "Say hello there!"}],
  model: :"claude-sonnet-4-5-20250929"
)

stream.text.each do |text|
  print(text)
end
```

### Pattern 2: Tool Definition for Anthropic
**What:** Convert Sure's `functions` format to Anthropic's `tools` format
**When to use:** When building chat_config tools
**Example:**
```ruby
# Source: Anthropic Messages API documentation
# Sure's function format:
functions = [
  {
    name: "get_weather",
    description: "Get the current weather in a given location",
    params_schema: {
      type: "object",
      properties: {
        location: { type: "string", description: "City and state, e.g. San Francisco, CA" }
      },
      required: ["location"]
    }
  }
]

# Anthropic tools format:
tools = [
  {
    name: "get_weather",
    description: "Get the current weather in a given location",
    input_schema: {
      type: "object",
      properties: {
        location: { type: "string", description: "City and state, e.g. San Francisco, CA" }
      },
      required: ["location"]
    }
  }
]
```

### Pattern 3: Multi-Turn Conversation with Tool Results
**What:** Handle tool_use → tool_result cycle manually
**When to use:** When Claude requests tool use
**Example:**
```ruby
# Source: Anthropic Messages API documentation
# When Claude returns tool_use blocks:
response = anthropic.messages.create(
  model: "claude-sonnet-4-5-20250929",
  max_tokens: 1024,
  tools: tools,
  messages: [{role: "user", content: "What's the weather in San Francisco?"}]
)

# Response contains tool_use content blocks
# Extract and execute tools, then send results back:
tool_results = response.content
  .select { |block| block.type == "tool_use" }
  .map do |tool_use|
    { tool_use_id: tool_use.id, content: execute_tool(tool_use) }
  end

# Continue conversation with tool results
followup = anthropic.messages.create(
  model: "claude-sonnet-4-5-20250929",
  max_tokens: 1024,
  tools: tools,
  messages: [
    {role: "user", content: "What's the weather in San Francisco?"},
    {role: "assistant", content: response.content},
    {role: "user", content: tool_results}  # tool_result blocks
  ]
)
```

### Pattern 4: Streaming with Event Types
**What:** Parse SSE events for incremental updates
**When to use:** When streamer proc is provided
**Example:**
```ruby
# Source: Official anthropic gem README
stream = anthropic.messages.stream(
  max_tokens: 1024,
  messages: [{role: "user", content: "Hello"}],
  model: :"claude-sonnet-4-5-20250929"
)

stream.each do |event|
  puts(event.type)  # message_start, content_block_start, content_block_delta, etc.
end
```

### Anti-Patterns to Avoid
- **Using `tool_runner` for Rails:** The beta tool_runner abstracts the loop but makes Langfuse integration and error handling more complex
- **Mixing content block types:** tool_result blocks must come FIRST in user message content array, text after
- **Ignoring stop_reason:** Always check stop_reason for "tool_use" to know when to continue the loop
- **Not handling parallel tool use:** Claude may call multiple tools at once; handle all tool_use blocks before responding
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Tool execution loop | Manual while/loop logic | Check stop_reason == "tool_use" pattern | Edge cases in conversation state, tool_result ordering |
| JSON Schema validation | Custom schema validator | input_schema in API request | API validates for you |
| Streaming parser | Custom SSE parser | anthropic.messages.stream with helpers | Official SDK handles event parsing, reconnection |
| Connection pooling | Custom HTTP management | Built-in connection_pool gem | Thread-safety, connection reuse handled |

**Key insight:** The Anthropic Ruby SDK handles the complex parts (HTTP, SSE, connection pooling). Focus on mapping between Sure's LlmConcept format and Anthropic's request/response format.
</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

### Pitfall 1: Incorrect tool_result Block Ordering
**What goes wrong:** 400 error "tool_use ids were found without tool_result blocks immediately after"
**Why it happens:** Anthropic requires tool_result blocks to come FIRST in the user message content array, with any text after
**How to avoid:** Always structure user message with tool_results first:
```ruby
# WRONG:
{role: "user", content: [
  {type: "text", text: "Here are results:"},  # Text before tool_result
  {type: "tool_result", tool_use_id: "...", content: "..."}
]}

# CORRECT:
{role: "user", content: [
  {type: "tool_result", tool_use_id: "...", content: "..."},  # tool_result first
  {type: "text", text: "What should I do next?"}  # Text after
]}
```
**Warning signs:** 400 errors with "tool_use ids" message

### Pitfall 2: Not Handling Parallel Tool Use
**What goes wrong:** Only processing first tool_use block when Claude calls multiple tools
**Why it happens:** Assuming single tool_use per response
**How to avoid:** Always iterate through ALL tool_use blocks:
```ruby
tool_use_blocks = response.content.select { |b| b.type == "tool_use" }
tool_use_blocks.each do |tool_use|
  # Execute each tool and collect results
end
```
**Warning signs:** Claude seems to "forget" to use available tools

### Pitfall 3: Incorrect Token Usage Field Names
**What goes wrong:** Usage recording shows 0 tokens
**Why it happens:** Anthropic uses `input_tokens`/`output_tokens`, not `prompt_tokens`/`completion_tokens`
**How to avoid:** Map field names correctly:
```ruby
# Anthropic API returns:
usage = {
  input_tokens: 2095,
  output_tokens: 503
}

# Map to Sure's expected format:
prompt_tokens = usage["input_tokens"]
completion_tokens = usage["output_tokens"]
```
**Warning signs:** LlmUsage records with 0 tokens despite successful responses

### Pitfall 4: Model Name as Symbol vs String
**What goes wrong:** "unknown model" error
**Why it happens:** Official SDK examples show model as symbol (e.g., `:"claude-sonnet-4-5-20250929"`)
**How to avoid:** Pass model as string from Setting/ENV:
```ruby
# SDK accepts both string and symbol
model: "claude-sonnet-4-5-20250929"  # String from settings
```
**Warning signs:** Model validation errors or unexpected model being used

### Pitfall 5: Missing max_tokens Parameter
**What goes wrong:** 400 error "max_tokens is required"
**Why it happens:** Anthropic requires max_tokens on every request (unlike OpenAI's sensible default)
**How to avoid:** Always include max_tokens:
```ruby
anthropic.messages.create(
  model: model,
  max_tokens: 4096,  # Always required
  messages: messages
)
```
**Warning signs:** 400 errors about max_tokens
</common_pitfalls>

<code_examples>
## Code Examples

### Basic Anthropic Client Initialization
```ruby
# Source: Official anthropic gem README
require "anthropic"

client = Anthropic::Client.new(api_key: ENV["ANTHROPIC_API_KEY"])

# Or with custom timeout (default 600s)
client = Anthropic::Client.new(
  api_key: access_token,
  timeout: 120
)
```

### Simple Chat Request
```ruby
# Source: Official anthropic gem README
message = client.messages.create(
  max_tokens: 1024,
  messages: [{role: "user", content: "Hello, Claude"}],
  model: :"claude-sonnet-4-5-20250929"
)

puts(message.content)  # => [{type: "text", text: "Hi! My name is Claude."}]
```

### Chat with Tools Definition
```ruby
# Source: Anthropic Messages API documentation
tools = [
  {
    name: "get_weather",
    description: "Get the current weather in a given location",
    input_schema: {
      type: "object",
      properties: {
        location: {
          type: "string",
          description: "The city and state, e.g. San Francisco, CA"
        },
        unit: {
          type: "string",
          enum: ["celsius", "fahrenheit"],
          description: "The unit of temperature"
        }
      },
      required: ["location"]
    }
  }
]

response = client.messages.create(
  model: "claude-sonnet-4-5-20250929",
  max_tokens: 1024,
  tools: tools,
  messages: [{role: "user", content: "What's the weather in San Francisco?"}]
)
```

### Handling Tool Use Response
```ruby
# Source: Anthropic Messages API documentation
# When response.stop_reason == "tool_use", extract tool calls:
tool_use_blocks = response.content.select { |block| block.type == "tool_use" }

tool_results = tool_use_blocks.map do |tool_use|
  # Execute the tool (this is your application logic)
  result = execute_tool_function(tool_use.name, tool_use.input)

  {
    type: "tool_result",
    tool_use_id: tool_use.id,
    content: result.to_s
  }
end

# Continue the conversation
followup = client.messages.create(
  model: "claude-sonnet-4-5-20250929",
  max_tokens: 1024,
  tools: tools,
  messages: [
    {role: "user", content: original_prompt},
    {role: "assistant", content: response.content},
    {role: "user", content: tool_results}
  ]
)
```

### Streaming with Text Helper
```ruby
# Source: Official anthropic gem README
stream = client.messages.stream(
  max_tokens: 1024,
  messages: [{role: :user, content: "Say hello there!"}],
  model: :"claude-sonnet-4-5-20250929"
)

stream.text.each do |text|
  print(text)  # Incrementally prints text content
end
```

### Error Handling
```ruby
# Source: Official anthropic gem README
begin
  message = client.messages.create(
    max_tokens: 1024,
    messages: [{role: "user", content: "Hello"}],
    model: :"claude-opus-4-5-20251101"
  )
rescue Anthropic::Errors::APIConnectionError => e
  puts("The server could not be reached")
rescue Anthropic::Errors::RateLimitError => e
  puts("Rate limit exceeded, back off")
rescue Anthropic::Errors::APIStatusError => e
  puts("HTTP #{e.status}: #{e.message}")
end
```
</code_examples>

<sota_updates>
## State of the Art (2024-2025)

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| alexrudall/ruby-anthropic | Official anthropic gem | 2024 | Official SDK has better type safety, Anthropic backing |
| Manual tool loop | beta.messages.tool_runner | 2024-2025 | Tool runner auto-handles execution but less control |
| No streaming support | Full SSE streaming with helpers | 2024 | stream.text helper provides incremental text |

**New tools/patterns to consider:**
- **Programmatic Tool Calling (PTC):** Announced Nov 2025 - Claude can orchestrate tools directly (Python/TS SDKs, Ruby support unclear)
- **input_examples (beta):** Provide concrete examples in tool definitions for better performance (requires beta header)
- **Extended thinking:** Can be combined with tool use but has restrictions (tool_choice "any" not supported)

**Deprecated/outdated:**
- **Text Completions API:** Legacy, use Messages API instead
- **ruby-anthropic community gem:** Official SDK available
</sota_updates>

<open_questions>
## Open Questions

1. **Should we use beta.messages.tool_runner?**
   - What we know: Tool runner auto-handles tool execution loop, available in Ruby SDK
   - What's unclear: How well it integrates with Langfuse tracing and Sure's error handling patterns
   - Recommendation: Start with manual tool handling for consistency with OpenAI provider, consider tool_runner for future simplification

2. **Streaming priority?**
   - What we know: Official SDK supports streaming with stream.text helper
   - What's unclear: User priority - context emphasizes "natural conversation feel" over streaming
   - Recommendation: Implement non-streaming first (plan 03-01), add streaming in 03-04 if time allows

3. **Function results mapping?**
   - What we know: Anthropic uses tool_result blocks, OpenAI uses "tool" role messages
   - What's unclear: Exact format expected by generic_chat_response pattern
   - Recommendation: Map function_results to Anthropic's tool_result format in ChatConfig

4. **Session/pagination support?**
   - What we know: Anthropic doesn't have equivalent to OpenAI's previous_response_id
   - What's unclear: How to handle multi-turn sessions for Anthropic
   - Recommendation: Manage conversation history manually (append assistant/user messages)
</open_questions>

<sources>
## Sources

### Primary (HIGH confidence)
- [anthropics/anthropic-sdk-ruby](https://github.com/anthropics/anthropic-sdk-ruby) - Official Ruby SDK README with examples
- [Messages API - Claude Docs](https://docs.anthropic.com/en/api/messages) - Official Messages API reference
- [How to implement tool use - Claude Docs](https://platform.claude.com/docs/en/agents-and-tools/tool-use/implement-tool-use) - Tool use implementation guide
- [Introducing advanced tool use - Anthropic Engineering](https://www.anthropic.com/engineering/advanced-tool-use) - Programmatic Tool Calling announcement

### Secondary (MEDIUM confidence)
- [RubyLLM Tools](https://rubyllm.com/tools/) - Community Ruby LLM library patterns
- [Function Calling in Ruby - Jetrockets Blog](https://jetrockets.com/blog/building-intelligent-ai-agents-with-function-calling-in-ruby) - Ruby function calling best practices
- [Tool use - Amazon Bedrock](https://docs.aws.amazon.com/bedrock/latest/userguide/model-parameters-anthropic-claude-messages-tool-use.html) - Tool use examples with JSON Schema

### Tertiary (LOW confidence - needs validation)
- None - all findings verified against official docs
</sources>

<metadata>
## Metadata

**Research scope:**
- Core technology: Anthropic Ruby SDK (`anthropic` gem ~> 1.16.0)
- Ecosystem: Ruby on Rails integration, following OpenAI provider patterns
- Patterns: Messages API, tool calling (tool_use/tool_result), streaming
- Pitfalls: Tool result ordering, token field names, max_tokens requirement

**Confidence breakdown:**
- Standard stack: HIGH - official gem well-documented
- Architecture: HIGH - following existing OpenAI provider patterns
- Pitfalls: HIGH - documented in official docs with clear error messages
- Code examples: HIGH - from official SDK README and docs

**Research date:** 2025-01-09
**Valid until:** 2025-02-09 (30 days - Anthropic API stable)
</metadata>

---

*Phase: 03-chat-support*
*Research completed: 2025-01-09*
*Ready for planning: yes*
