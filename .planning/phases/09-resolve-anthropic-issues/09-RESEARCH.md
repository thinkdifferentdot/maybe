# Phase 9: Resolve Anthropic Issues - Research

**Researched:** 2026-01-10
**Domain:** Bug triage and resolution for Anthropic Ruby SDK integration
**Confidence:** HIGH

<research_summary>
## Summary

Phase 9 is a bug triage and fix phase, not a new feature implementation. The research focused on known issues with the official Anthropic Ruby SDK (`anthropic` gem ~> 1.16.0) to anticipate potential sources of bugs discovered during Phase 8 testing.

Key finding: The official Anthropic Ruby SDK is actively maintained with no critical blocking bugs reported. The main known issues are:
1. AWS Bedrock integration has signature verification problems on retries (not applicable - direct API usage)
2. Streaming + tool calling has known edge cases in the broader ecosystem (streaming deferred per Phase 03-04)
3. Tool calls require unique IDs within each message (API requirement, not SDK bug)

The CONTEXT.md already established the systematic approach: discover → catalog → categorize → fix. This research validates that approach and identifies specific technical areas to investigate when bugs are found.

**Primary recommendation:** Follow the systematic triage process from CONTEXT.md. Focus investigation on three areas: (1) message structure for tool calling (unique IDs), (2) usage field mapping (input_tokens vs prompt_tokens), and (3) BaseModel vs Hash access patterns from the SDK.
</research_summary>

<standard_stack>
## Standard Stack

This phase uses existing infrastructure from prior phases:

### Core (Already Installed)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| anthropic | ~> 1.16.0 | Official Anthropic Ruby SDK | Actively maintained, official support |
| ruby-anthropic | N/A | Community gem (renamed) | NOT using - using official SDK |

### Testing Infrastructure
| Tool | Purpose | When to Use |
|------|---------|-------------|
| Minitest | Rails test framework | All automated tests |
| VCR | External API recording | For future API tests |
| Rails logger | Debug output | Investigating runtime issues |

**No new installations required.**
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Bug Triage Process (from CONTEXT.md)
**What:** Systematic discovery, cataloging, categorization, and fixing
**When to use:** Any bug discovered during testing
**Pattern:**
```
1. Full sweep discovery - Test ALL features
2. Catalog everything - Create ISSUES.md
3. Categorize - Critical / Normal / Minor
4. Fix systematically - Work through catalog
```

### Issue Severity Classification
| Severity | Definition | Example |
|----------|------------|---------|
| Critical | Feature completely broken | Chat returns 500 error |
| Normal | Feature works with limitations | Tool calling fails in edge case |
| Minor | Cosmetic or low-impact | Inconsistent logging format |

### Resolution Documentation Pattern
```markdown
## Issue: [Title]
**Status:** Open / Fixed / Won't Fix / Deferred
**Severity:** Critical / Normal / Minor
**Discovery:** [How it was found]
**Resolution:** [What was done]
**Files Changed:** [List of files]
```

### Anti-Patterns to Avoid
- **Fixing without cataloging:** Creates chaos, makes issues slip through
- **Premature optimization:** Fix bugs first, optimize later
- **Scope creep:** Don't add features during bug fixes
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Bug tracking | Custom ISSUES.md is fine | GitHub Issues if complex | For this phase, ISSUES.md in phase directory is sufficient |
| Tool call ID generation | Custom UUID logic | API requires unique IDs per message | Must enforce uniqueness within single message |
| Error extraction from SDK | Custom parsing | Use official SDK error objects | SDK provides structured error responses |

**Key insight:** The official SDK handles most complexity. Issues will likely be in integration layer, not the SDK itself.
</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

### Pitfall 1: Tool Call ID Collisions
**What goes wrong:** Multiple tool_use blocks in one message have the same ID
**Why it happens:** Not understanding Anthropic's API requirement for unique IDs
**How to avoid:** Ensure each tool_use block gets a unique ID (use UUID or incrementing counter)
**Warning signs:** API returns 400 error, "duplicate tool_use id"

### Pitfall 2: BaseModel vs Hash Access
**What goes wrong:** Calling `dig()` on Anthropic SDK objects that are BaseModel instances
**Why it happens:** SDK returns `Anthropic::Models::*` objects (BaseModel), not plain hashes
**How to avoid:** Use `to_h` to convert BaseModel to hash before parsing, or access attributes directly
**Warning signs:** `NoMethodError: undefined method 'dig' for #<Anthropic::Models::Message>`

### Pitfall 3: Usage Field Mapping
**What goes wrong:** Token counts are nil or incorrect
**Why it happens:** Anthropic uses `input_tokens`/`output_tokens`, LlmConcept expects `prompt_tokens`/`completion_tokens`
**How to avoid:** Map fields explicitly when recording usage
**Warning signs:** Usage records show 0 tokens or nil values

### Pitfall 4: Missing max_tokens
**What goes wrong:** API returns 400 error
**Why it happens:** Anthropic requires `max_tokens` parameter (unlike OpenAI which has default)
**How to avoid:** Always include `max_tokens: 4096` in Messages API calls
**Warning signs:** `400 Bad Request`, "max_tokens is required"

### Pitfall 5: Array vs Hash for Tool Input
**What goes wrong:** Tool calling fails with parsing errors
**Why it happens:** Anthropic SDK returns `input` as Hash, but some code paths expect JSON string
**How to avoid:** Check `is_a?(Hash)` before parsing; handle both formats
**Warning signs:** `JSON::ParserError` when processing tool results
</common_pitfalls>

<code_examples>
## Code Examples

Verified patterns from official sources and existing codebase:

### BaseModel to Hash Conversion
```ruby
# Source: app/models/provider/anthropic.rb:142
# The SDK returns BaseModel objects; convert to hash before parsing
raw_response = client.messages.create(parameters)
response_hash = raw_response.to_h  # Critical: convert before parsing
parsed = ChatParser.new(response_hash).parsed
```

### Usage Field Mapping
```ruby
# Source: app/models/provider/anthropic.rb:150-155
# Anthropic SDK returns BaseModel Usage object; access attributes directly
raw_usage = raw_response.usage
usage = {
  "prompt_tokens" => raw_usage&.input_tokens,      # Map input -> prompt
  "completion_tokens" => raw_usage&.output_tokens,  # Map output -> completion
  "total_tokens" => (raw_usage&.input_tokens || 0) + (raw_usage&.output_tokens || 0)
}
```

### Tool Results Array Handling
```ruby
# Source: app/models/assistant/function_tool_caller.rb:11-16
# Map function requests to tool call results
def fulfill_requests(function_requests)
  function_requests.map do |function_request|
    result = execute(function_request)
    ToolCall::Function.from_function_request(function_request, result)
  end
end
```

### Required max_tokens Parameter
```ruby
# Source: app/models/provider/anthropic.rb:130-134
parameters = {
  model: effective_model,
  max_tokens: 4096,  # Required by Anthropic API
  messages: messages
}
```
</code_examples>

<sota_updates>
## State of the Art (2024-2025)

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| ruby-anthropic (community) | anthropic (official SDK) | April 2025 | Official gem has better support and docs |
| Streaming tools (experimental) | Streaming deferred | Phase 03-04 | Avoid known edge cases in streaming+tools |

**Current SDK status:**
- Official gem: `anthropic` ~> 1.16.0
- Actively maintained by Anthropic
- Ruby 3.2+ requirement
- No critical open bugs for direct API usage

**Deprecated/outdated:**
- **ruby-anthropic gem:** Renamed to avoid conflict with official SDK
- **Streaming tool calling (03-04):** Deferred due to ecosystem complexity
</sota_updates>

<open_questions>
## Open Questions

1. **What bugs exist?**
   - What we know: Tests couldn't be run in session due to env proxy settings
   - What's unclear: What specific bugs will be discovered during manual testing
   - Recommendation: Follow systematic discovery process from CONTEXT.md, catalog in ISSUES.md

2. **Streaming implementation?**
   - What we know: Streaming was deferred in Phase 03-04
   - What's unclear: Whether streaming bugs will be found when it's implemented
   - Recommendation: Treat streaming as separate feature, not part of this bug-fix phase
</open_questions>

<sources>
## Sources

### Primary (HIGH confidence)
- [anthropics/anthropic-sdk-ruby GitHub](https://github.com/anthropics/anthropic-sdk-ruby) - Official Ruby SDK repository
- [alexrudall/ruby-anthropic GitHub](https://github.com/alexrudall/ruby-anthropic) - Community gem (renamed, not in use)
- [Anthropic Advanced Tool Use Documentation](https://www.anthropic.com/engineering/advanced-tool-use) - Tool use best practices (Nov 2025)
- [app/models/provider/anthropic.rb](app/models/provider/anthropic.rb) - Existing implementation
- [app/models/assistant/function_tool_caller.rb](app/models/assistant/function_tool_caller.rb) - Tool calling implementation
- [.planning/phases/09-resolve-anthropic-issues/09-CONTEXT.md](.planning/phases/09-resolve-anthropic-issues/09-CONTEXT.md) - Phase context

### Secondary (MEDIUM confidence)
- [Gem reannouncement discussion](https://www.reddit.com/r/rails/comments/1j8lpnt/rubyllm_10/) - Confirms community gem renamed for official SDK
- [Ruby AI News July 2025](https://rubyai.beehiiv.com/p/ruby-ai-news-july-8th-2025-389f029dedf446ae) - SDK ecosystem updates

### Tertiary (LOW confidence - needs validation)
- None - all findings verified or from codebase
</sources>

<metadata>
## Metadata

**Research scope:**
- Core technology: Anthropic Ruby SDK (official)
- Ecosystem: Rails testing patterns, bug triage methodology
- Patterns: Systematic bug fixing, issue categorization
- Pitfalls: Tool calling, usage mapping, BaseModel vs Hash

**Confidence breakdown:**
- Standard stack: HIGH - official SDK in use
- Architecture: HIGH - CONTEXT.md established clear methodology
- Pitfalls: HIGH - documented in codebase with specific examples
- Code examples: HIGH - from actual implementation

**Research date:** 2026-01-10
**Valid until:** 2026-02-10 (30 days - SDK is stable, bugs are implementation-specific)
</metadata>

---

*Phase: 09-resolve-anthropic-issues*
*Research completed: 2026-01-10*
*Ready for planning: yes*
