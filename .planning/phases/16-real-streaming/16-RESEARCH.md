# Phase 16: Real Streaming Support - Research

**Researched:** 2026-01-10
**Domain:** Anthropic Ruby gem streaming API + Rails chat integration
**Confidence:** HIGH

<research_summary>
## Summary

Researched the Anthropic Ruby SDK's streaming capabilities to implement true token-by-token streaming for Anthropic chat responses, matching OpenAI's current streaming behavior.

The Anthropic Ruby SDK (`anthropic` gem v1.16.0+) provides native streaming support via `client.messages.stream()` which returns a `MessageStream` object. The stream yields SSE events that can be iterated with `.each` or accessed via convenience helpers like `.text.each` for just text deltas.

Key finding: The SDK's `MessageStream` class provides:
- `stream.text.each { |text| ... }` - Enumerates text deltas only
- `stream.each { |event| ... }` - Enumerates all raw events
- `stream.__accumulated_message__` - Returns complete Message after stream completion
- `stream.__accumulated_text__` - Returns all text concatenated

**Primary recommendation:** Use `client.messages.stream()` with `stream.text.each` for text deltas, then handle tool_use events separately to maintain parity with OpenAI's streaming implementation. Create `ChatStreamParser` similar to OpenAI's to convert Anthropic events to `ChatStreamChunk` format.
</research_summary>

<standard_stack>
## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| anthropic | ~> 1.16.0 | Anthropic Ruby SDK | Official gem, provides MessageStream API |
| Ruby | 3.2.0+ | Language requirement | Minimum version for anthropic gem |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| net/http | stdlib | HTTP transport | Built-in, used by anthropic gem |
| connection_pool | bundled | Connection pooling | Automatic via anthropic gem |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| anthropic gem | alexrudall/ruby-anthropic | Community gem, renamed to make way for official SDK |

**Installation:**
```bash
# Already in Gemfile
gem "anthropic", "~> 1.16.0"
```
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Recommended Implementation Structure

```
app/models/provider/anthropic/
├── chat_stream_parser.rb   # NEW: Parse Anthropic stream events to ChatStreamChunk
├── chat_response.rb         # NEW OR REFACTOR: Streaming chat_response method
└── (existing files)
```

### Pattern 1: Basic Text Streaming with stream.text.each

**What:** Use the SDK's convenience method for iterating text deltas only

**When to use:** Simple chat responses without tool use

**Example:**
```ruby
# Source: anthropic-sdk-ruby GitHub README
stream = anthropic.messages.stream(
  max_tokens: 1024,
  messages: [{role: "user", content: "Hello, Claude"}],
  model: "claude-sonnet-4-5-20250929"
)

stream.text.each do |text|
  print(text)  # Yields text deltas as they arrive
end
```

### Pattern 2: Full Event Streaming with stream.each

**What:** Iterate all raw SSE events for complete control

**When to use:** Need to handle tool_use, thinking deltas, or other event types

**Example:**
```ruby
# Source: anthropic-sdk-ruby documentation
stream = anthropic.messages.stream(
  max_tokens: 1024,
  messages: [{role: "user", content: "Hello"}],
  model: "claude-sonnet-4-5-20250929"
)

stream.each do |event|
  puts(event.type)  # :content_block_start, :content_block_delta, :message_stop, etc.
end
```

### Pattern 3: ChatStreamParser for OpenAI Parity

**What:** Create a parser class that converts Anthropic stream events to `ChatStreamChunk` format

**When to use:** Need to maintain compatibility with existing streaming infrastructure (Assistant::Responder)

**Example:**
```ruby
# Based on OpenAI::ChatStreamParser pattern in app/models/provider/openai/chat_stream_parser.rb
class Provider::Anthropic::ChatStreamParser
  Error = Class.new(StandardError)

  def initialize(event)
    @event = event
  end

  def parsed
    case event.type
    when :content_block_delta
      if event.delta.type == :text_delta
        Chunk.new(type: "output_text", data: event.delta.text, usage: nil)
      elsif event.delta.type == :input_json_delta
        # Accumulate tool use params
        nil  # Tool use completion handled in message_stop
      end
    when :message_stop
      # Return accumulated message with usage
      Chunk.new(type: "response", data: accumulated_response, usage: accumulated_usage)
    end
  end

  private

  attr_reader :event
  Chunk = Provider::LlmConcept::ChatStreamChunk
end
```

### Anti-Patterns to Avoid
- **Using non-streaming then simulating chunks:** Defeats purpose of streaming; use native API
- **Manually parsing SSE:** The SDK handles this; don't reinvent
- **Blocking until full response:** Don't call `__accumulated_message__` until stream ends
- **Ignoring event types:** Handle unknown events gracefully per Anthropic docs
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SSE parsing | Raw net/http event reading | `anthropic.messages.stream()` | SDK handles reconnection, parsing, retries |
| Text accumulation | String concatenation loop | `stream.__accumulated_text__` | Built-in helper handles multi-block content |
| Message reconstruction | Manual event aggregation | `stream.__accumulated_message__` | SDK provides complete Message object |
| Tool use JSON parsing | Manual partial JSON parsing | SDK's internal handling | Tool params are complex; let SDK handle |

**Key insight:** The Anthropic Ruby SDK provides a complete streaming abstraction. The `MessageStream` class handles all the complexity of SSE, event parsing, accumulation, and even provides typed access to the final result. Only build a thin adapter layer to convert to your `ChatStreamChunk` format.
</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

### Pitfall 1: Blocking Until Stream Completion
**What goes wrong:** Code calls `__accumulated_message__` immediately, blocking until entire stream finishes

**Why it happens:** The method waits for all events to be consumed before returning the accumulated message

**How to avoid:** Only call `__accumulated_message__` after the stream has been fully consumed via `.each`

**Warning signs:** UI doesn't show progressive text updates, all text appears at once

### Pitfall 2: Mixing stream.text.each with Full Event Handling
**What goes wrong:** Using `stream.text.each` consumes the iterator, preventing access to tool_use events

**Why it happens:** `stream.text.each` is a fused enumerable that consumes the underlying iterator

**How to avoid:** Use `stream.each` for full event access when tool use is possible; only use `stream.text.each` for text-only responses

**Warning signs:** Tool requests not being detected, function calls not executing

### Pitfall 3: Not Handling content_block_start for Tool Use
**What goes wrong:** Tool use events missed because code only looks at `content_block_delta`

**Why it happens:** Tool use flow requires tracking `content_block_start` to get tool_id and name, then accumulating `input_json_delta` for params

**How to avoid:** Track full event sequence for tool_use blocks: start → delta(s) → stop

**Warning signs:** Tool parameters incomplete, function calls failing with empty args

### Pitfall 4: Ignoring Ping and Error Events
**What goes wrong:** Stream hangs indefinitely or errors go undetected

**Why it happens:** Anthropic sends `ping` events and may send `error` events during streaming

**How to avoid:** Handle all event types, log unknown events gracefully

**Warning signs:** Stream timeouts, unhandled exceptions during streaming

### Pitfall 5: Token Usage Incomplete During Stream
**What goes wrong:** Usage metadata shows zero or partial token counts

**Why it happens:** Usage is cumulative and only complete in `message_delta` event

**How to avoid:** Wait for `message_delta` event before recording usage

**Warning signs:** Zero token counts in logs, cost tracking inaccurate
</common_pitfalls>

<code_examples>
## Code Examples

Verified patterns from official sources:

### Basic Streaming Setup
```ruby
# Source: anthropic-sdk-ruby GitHub README
# https://github.com/anthropics/anthropic-sdk-ruby

stream = anthropic.messages.stream(
  max_tokens: 1024,
  messages: [{role: "user", content: "Hello, Claude"}],
  model: "claude-sonnet-4-5-20250929"
)

stream.text.each do |text|
  print(text)
end
```

### Full Event Iteration
```ruby
# Source: anthropic-sdk-ruby GitHub README
stream = anthropic.messages.stream(
  max_tokens: 1024,
  messages: [{role: "user", content: "Hello, Claude"}],
  model: "claude-opus-4-5-20251101"
)

stream.each do |message|
  puts(message.type)
end
```

### Streaming with Tools (Event Flow)
```ruby
# Source: Anthropic streaming documentation
# https://platform.claude.com/docs/en/build-with-claude/streaming
# Event types: content_block_start → content_block_delta (multiple) → content_block_stop

stream = client.messages.stream(
  max_tokens: 1024,
  messages: [{role: "user", content: "What's the weather in SF?"}],
  model: "claude-sonnet-4-5-20250929",
  tools: [{name: "get_weather", ...}]
)

# Track tool use accumulation
current_tool = nil
accumulated_input = ""

stream.each do |event|
  case event.type
  when :content_block_start
    if event.content_block.type == :tool_use
      current_tool = {
        id: event.content_block.id,
        name: event.content_block.name
      }
    end
  when :content_block_delta
    if event.delta.type == :input_json_delta
      accumulated_input += event.delta.partial_json
    end
  when :content_block_stop
    if current_tool
      # Parse accumulated_input as JSON for tool params
      current_tool[:input] = JSON.parse(accumulated_input)
      # Execute tool...
      current_tool = nil
      accumulated_input = ""
    end
  when :message_stop
    # Stream complete
  end
end
```

### Accessing Accumulated Message
```ruby
# Source: RubyDoc MessageStream documentation
# https://www.rubydoc.info/github/anthropics/anthropic-sdk-ruby/Anthropic/Helpers/Streaming/MessageStream

stream = client.messages.stream(...)

# Must consume stream first
stream.each { |event| /* handle events */ }

# Now access accumulated result
message = stream.__accumulated_message__  # Full Message object
text = stream.__accumulated_text__        # All text concatenated
```

### Streaming Event Type Reference
```ruby
# Source: Anthropic streaming documentation
# https://platform.claude.com/docs/en/build-with-claude/streaming

# Event types to handle:
:message_start           # Initial message metadata
:content_block_start     # New content block (text, tool_use, thinking)
:content_block_delta     # Incremental update to block
  # delta.type can be:
  #   :text_delta       # Text content
  #   :input_json_delta # Tool use params (partial JSON)
  #   :thinking_delta   # Extended thinking
  #   :signature_delta  # Thinking signature
:content_block_stop      # End of content block
:message_delta           # Top-level message changes (stop_reason, usage)
:message_stop            # Stream complete
:ping                    # Keep-alive
:error                   # Error during stream
```
</code_examples>

<sota_updates>
## State of the Art (2024-2025)

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| alexrudall/ruby-anthropic | anthropics/anthropic-sdk-ruby | 2024 | Official gem now available; use it |
| Manual SSE parsing | MessageStream class | 2024 | SDK provides full streaming abstraction |
| Partial JSON manually | SDK handles tool params | 2024-2025 | `input_json_delta` accumulation built-in |

**New tools/patterns to consider:**
- **MessageStream helpers**: `__accumulated_text__`, `__accumulated_message__` for post-stream access
- **Fused enumerables**: `stream.text.each` creates lazy text-only enumerable
- **Private API methods**: Note that `__*__` methods are marked as private API but are the documented way to access accumulated data

**Deprecated/outdated:**
- **alexrudall/ruby-anthropic**: Still works but superseded by official SDK
- **Manual SSE handling**: Don't parse raw Server-Sent Events yourself; use the SDK
</sota_updates>

<open_questions>
## Open Questions

1. **Tool use streaming with partial JSON**
   - What we know: Anthropic sends `input_json_delta` events with partial JSON strings
   - What's unclear: Whether to accumulate manually or use SDK helpers
   - Recommendation: Accumulate manually per the docs; parse after `content_block_stop`

2. **Error recovery during stream**
   - What we know: Anthropic docs mention error events and recovery strategies
   - What's unclear: How to implement in Rails context with existing error handling
   - Recommendation: Graceful degradation to non-streaming if stream fails

3. **Langfuse integration with streaming**
   - What we know: Current implementation logs generation after completion
   - What's unclear: Whether to log intermediate events or just final accumulated result
   - Recommendation: Log only final result to match existing pattern; streaming is UI concern
</open_questions>

<sources>
## Sources

### Primary (HIGH confidence)
- [anthropics/anthropic-sdk-ruby](https://github.com/anthropics/anthropic-sdk-ruby) - Official Ruby SDK, streaming examples
- [Anthropic Streaming Messages Documentation](https://platform.claude.com/docs/en/build-with-claude/streaming) - Complete event type reference, HTTP examples
- [RubyDoc MessageStream Reference](https://www.rubydoc.info/github/anthropics/anthropic-sdk-ruby/Anthropic/Helpers/Streaming/MessageStream) - API docs for MessageStream class

### Secondary (MEDIUM confidence)
- [alexrudall/ruby-anthropic](https://github.com/alexrudall/ruby-anthropic) - Community gem (superseded by official)

### Tertiary (LOW confidence - needs validation)
- None - all findings verified against official sources
</sources>

<metadata>
## Metadata

**Research scope:**
- Core technology: Anthropic Ruby SDK (anthropic gem ~> 1.16.0)
- Ecosystem: Ruby 3.2+, net/http, connection_pool
- Patterns: MessageStream, event iteration, text deltas, tool use streaming
- Pitfalls: Blocking, event handling, usage tracking, tool use accumulation

**Confidence breakdown:**
- Standard stack: HIGH - official SDK, well-documented
- Architecture: HIGH - based on official examples and RubyDoc
- Pitfalls: HIGH - documented in official Anthropic docs
- Code examples: HIGH - from official GitHub and documentation

**Research date:** 2026-01-10
**Valid until:** 2026-02-10 (30 days - SDK is stable, but API may evolve)
</metadata>

---

*Phase: 16-real-streaming*
*Research completed: 2026-01-10*
*Ready for planning: yes*
