# Phase 19: Flexible JSON Parsing - Research

**Researched:** 2026-01-11
**Domain:** LLM JSON parsing resilience
**Confidence:** HIGH

<research_summary>
## Summary

Research focused on Claude/Anthropic-specific JSON output behaviors to inform the port of `parse_json_flexibly` from OpenAI to Anthropic providers.

**Key finding:** Unlike OpenAI which has a native "JSON mode," Claude does not guarantee pure JSON output without the new structured outputs API (beta, late 2025). The Sure codebase uses traditional JSON prompting, making flexible JSON parsing essential for reliability.

**Critical insight:** The existing OpenAI `parse_json_flexibly` implementation handles `

` tags intended for Qwen-thinking and similar models, NOT Claude's extended thinking. Claude's extended thinking uses separate content blocks in the API response (different structure). The parsing strategies (closed/unclosed markdown blocks, key-specific extraction) remain relevant for Claude.

**Primary recommendation:** Port the existing OpenAI `parse_json_flexibly` method as-is to Anthropic's auto_categorizer and auto_merchant_detector. No Claude-specific modifications needed based on current research.
</research_summary>

<standard_stack>
## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Ruby JSON stdlib | built-in | JSON parsing | Standard library, fast, reliable |
| Regexp patterns | built-in | Markdown/tag extraction | Native Ruby regex for text processing |

### Supporting
None - this is pure Ruby code porting, no external dependencies.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Manual regex extraction | json_extract gem | Unnecessary dependency for simple patterns |
| Multi-strategy fallback | Single strategy with retries | Multi-strategy is more deterministic than blind retries |

**Installation:** No new dependencies required.
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Recommended Implementation Structure

Port the exact method structure from OpenAI:

```ruby
def parse_json_flexibly(raw)
  return {} if raw.blank?

  # Strategy 0: Direct parse (fast path)
  cleaned = strip_thinking_tags(raw)
  JSON.parse(cleaned)
rescue JSON::ParserError
  # Strategy 1: Closed markdown code blocks
  # Strategy 2: Unclosed markdown code blocks
  # Strategy 3: Key-specific extraction
  # Strategy 4: Last-resort JSON object grab
end

def strip_thinking_tags(raw)
  # Handle

 tags (for non-Claude thinking models)
end
```

### Pattern 1: Multi-Strategy Fallback
**What:** Try parsing strategies from most specific to most general
**When to use:** When parsing LLM-generated JSON that may have formatting quirks
**Example:**
```ruby
# Strategy 1: Closed markdown ```json...```
if cleaned =~ /```(?:json)?\s*(\{[\s\S]*?\})\s*```/m
  matches.reverse_each do |match|
    begin
      return JSON.parse(match)
    rescue JSON::ParserError
      next
    end
  end
end
```

### Pattern 2: Greedy vs Non-Greedy Matching
**What:** Try non-greedy regex first, fall back to greedy if it fails
**When to use:** When multiple JSON objects may exist in response
**Example:**
```ruby
# Non-greedy first (prefer smaller, more specific matches)
matches = cleaned.scan(/(\{"categorizations"\s*:\s*[[\s\S]*?\]\s*\})/m).flatten
# If that fails, try greedy (matches largest possible)
begin
  return JSON.parse($1)  # $1 from the greedy pattern match
rescue JSON::ParserError
  # Continue
end
```

### Anti-Patterns to Avoid
- **Blind retries without extraction:** Don't just retry the same parse - apply different extraction strategies
- **Overly permissive regex:** Avoid grabbing non-JSON content; target specific patterns first
- **Silent failures:** Always raise a clear error if ALL strategies fail
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON extraction from markdown | Complex custom regex state machine | Ruby's built-in `scan` + `reverse_each` | Simpler, tested, handles multiple matches |
| Error handling | Custom error classes | Reuse `Provider::Anthropic::Error` | Consistent error handling across provider |
| Blank input handling | nil checks scattered everywhere | Single early return `return {} if raw.blank?` | Clearer, faster, predictable |

**Key insight:** LLM JSON parsing looks like a "simple regex problem" but has nasty edge cases (nested braces, escaped quotes, multiple objects). The multi-strategy fallback pattern handles these without over-engineering.
</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

### Pitfall 1: Assuming Claude's Extended Thinking Uses Inline Tags
**What goes wrong:** Looking for `<thinking>` tags in Claude output when they don't exist inline
**Why it happens:** Confusion between Claude's API response format (separate content blocks) and other models' inline tags
**How to avoid:** The `strip_thinking_tags` method handles `` tags for Qwen-thinking, NOT Claude. Claude's extended thinking doesn't require inline tag stripping.
**Warning signs:** Trying to parse Claude responses with regex when the API provides structured content blocks

### Pitfall 2: Greedy Regex Grabbing Too Much
**What goes wrong:** Pattern `/{[\s\S]*}/` grabs from FIRST open brace to LAST closing brace, including intermediate content
**Why it happens:** Greedy quantifiers match as much as possible
**How to avoid:** Try non-greedy patterns (`{[\s\S]*?}`) first, use greedy only as fallback
**Warning signs:** JSON parse errors with unexpected content, or parse succeeding but returning wrong structure

### Pitfall 3: Not Handling Both `categorizations` and `merchants` Keys
**What goes wrong:** Copy-pasting the key-specific extraction strategy without updating the key name
**Why it happens:** OpenAI has separate implementations in auto_categorizer and auto_merchant_detector
**How to avoid:** When porting, ensure each file uses its correct key name (`categorizations` vs `merchants`)
**Warning signs:** Tests failing because categorizations/merchants aren't being extracted

### Pitfall 4: Forgetting Blank Input Handling
**What goes wrong:** `JSON.parse(nil)` raises TypeError instead of JSON::ParserError
**Why it happens:** Early return `return {} if raw.blank?` is easy to miss when copy-pasting
**How to avoid:** Always include the blank check at the top of the method
**Warning signs:** TypeError instead of proper JSON parsing errors in tests
</common_pitfalls>

<code_examples>
## Code Examples

### Strip Thinking Tags (from OpenAI)
```ruby
# Source: app/models/provider/openai/auto_categorizer.rb:439-457
def strip_thinking_tags(raw)
  # Remove

 blocks but keep content after them
  # If no closing tag, the model may have been cut off - try to extract JSON from inside
  if raw.include?("")
    # Check if there's content after the thinking block
    if raw =~ /<\/think>\s*([\s\S]*)/m
      after_thinking = $1.strip
      return after_thinking if after_thinking.present?
    end
    # If no content after  or no closing tag, look inside the thinking block
    # The JSON might be the last thing in the thinking block
    if raw =~ /([\s\S]*)/m
      return $1
    end
  end
  raw
end
```

### Full Parse Method Structure
```ruby
# Source: app/models/provider/openai/auto_categorizer.rb:375-437
def parse_json_flexibly(raw)
  return {} if raw.blank?

  cleaned = strip_thinking_tags(raw)

  # Try direct parse first
  JSON.parse(cleaned)
rescue JSON::ParserError
  # Strategy 1: Closed markdown code blocks
  if cleaned =~ /```(?:json)?\s*(\{[\s\S]*?\})\s*```/m
    matches = cleaned.scan(/```(?:json)?\s*(\{[\s\S]*?\})\s*```/m).flatten
    matches.reverse_each do |match|
      begin
        return JSON.parse(match)
      rescue JSON::ParserError
        next
      end
    end
  end

  # Strategy 2: Unclosed markdown blocks
  if cleaned =~ /```(?:json)?\s*(\{[\s\S]*\})\s*$/m
    begin
      return JSON.parse($1)
    rescue JSON::ParserError
      # Continue
    end
  end

  # Strategy 3: Key-specific extraction
  # Strategy 4: Last resort

  raise Provider::Anthropic::Error, "Could not parse JSON from response: #{raw.truncate(200)}"
end
```
</code_examples>

<sota_updates>
## State of the Art (2025)

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Claude without JSON mode | Structured Outputs (beta) | 2025-11-13 | New API guarantees valid JSON but requires beta header |
| Manual JSON extraction | SDK helpers (Pydantic, Zod) | 2025-11-13 | Python/TypeScript SDKs have automatic validation |

**New tools/patterns to consider:**
- **Structured Outputs API**: Beta feature for Claude 4.5/4.1 with `output_format` parameter - guarantees valid JSON
- **SDK `parse()` method**: Automatic schema transformation and validation (Python/TypeScript only)
- **Grammar caching**: First request has latency, subsequent requests cached for 24h

**Deprecated/outdated:**
- **JSON mode assumptions**: Claude never had a "JSON mode" like OpenAI - structured outputs is the new solution
- **Inline `<thinking>` tag extraction**: Claude's extended thinking uses separate content blocks, not inline tags

**Impact on Phase 19:** The codebase does NOT use structured outputs (no beta header, traditional prompting). Therefore, flexible JSON parsing remains necessary. The multi-strategy fallback pattern is the correct approach for traditional JSON prompting with Claude.
</sota_updates>

<open_questions>
## Open Questions

1. **Should we adopt Structured Outputs API?**
   - What we know: Structured Outputs guarantees valid JSON but requires beta header and Claude 4.5/4.1
   - What's unclear: Whether the project wants to adopt beta APIs, model version requirements
   - Recommendation: Stick with traditional JSON prompting + flexible parsing for now. Reconsider when structured outputs is GA.

2. **Will Anthropic Ruby SDK get structured outputs support?**
   - What we know: Python/TypeScript SDKs have `parse()` helpers
   - What's unclear: Ruby SDK support timeline, whether Sure would use it
   - Recommendation: Monitor but not block on this. Our custom parse_json_flexibly works fine.
</open_questions>

<sources>
## Sources

### Primary (HIGH confidence)
- [Structured outputs - Claude Docs](https://platform.claude.com/docs/en/build-with-claude/structured-outputs) - Official docs on JSON outputs, beta requirements, limitations
- [Claude's extended thinking](https://www.anthropic.com/news/visible-extended-thinking) - Official announcement explaining separate content blocks (not inline tags)
- Internal codebase: `app/models/provider/openai/auto_categorizer.rb` - Source implementation to port
- Internal codebase: `app/models/provider/openai/auto_merchant_detector.rb` - Source implementation to port

### Secondary (MEDIUM confidence)
- [Zero-Error JSON with Claude](https://medium.com/@meshuggah22/zero-error-json-with-claude-how-anthropics-structured-outputs-actually-work-in-real-code-789cde7aff13) - Confirms Claude lacks native JSON mode without structured outputs
- [A Hands-On Guide to Structured Outputs](https://towardsdatascience.com/hands-on-with-anthropics-new-structured-output-capabilities/) - Explains structured outputs implementation details
- [The guide to structured outputs](https://agenta.ai/blog/the-guide-to-structured-outputs-and-function-calling-with-llms) - Notes "Claude doesn't have a JSON mode"

### Tertiary (LOW confidence - needs validation)
- [GitHub: crawl4ai #1663](https://github.com/unclecode/crawl4ai/issues/1663) - Community reports of Claude returning markdown-wrapped JSON
- [GitHub: Perplexica #959](https://github.com/ItzCrazyKns/Perplexica/issues/959) - Reports JSON parse errors with Claude models via JSON mode
</sources>

<metadata>
## Metadata

**Research scope:**
- Core technology: LLM JSON parsing, Claude API response formats
- Ecosystem: None (internal code porting)
- Patterns: Multi-strategy fallback parsing, regex extraction patterns
- Pitfalls: Claude-specific quirks, markdown handling, regex edge cases

**Confidence breakdown:**
- Standard stack: HIGH - No external dependencies needed
- Architecture: HIGH - Porting existing working code
- Pitfalls: HIGH - Official docs + community reports
- Code examples: HIGH - Directly from source codebase

**Research date:** 2026-01-11
**Valid until:** 2026-02-10 (30 days - LLM APIs evolve quickly, verify before implementing)

**Conclusion:** Proceed with porting `parse_json_flexibly` from OpenAI to Anthropic. No Claude-specific modifications required based on research. The existing implementation's strategies (direct parse, markdown blocks, key extraction, last resort) are appropriate for Claude's traditional JSON prompting behavior.
</metadata>

---

*Phase: 19-flexible-json-parsing*
*Research completed: 2026-01-11*
*Ready for planning: yes*
