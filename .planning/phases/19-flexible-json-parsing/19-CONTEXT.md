# Phase 19: Flexible JSON Parsing - Context

**Gathered:** 2026-01-11
**Status:** Ready for planning

<vision>
## How This Should Work

LLMs are messy - they don't always return clean, parseable JSON. Sometimes Claude wraps responses in `<thinking>` tags. Sometimes markdown code blocks get left unclosed. Sometimes the JSON is buried in other content.

The flexible JSON parser should gracefully extract valid JSON from all these messy scenarios. It tries multiple strategies in order: direct parse first (fast path), then closed markdown blocks, then unclosed blocks (thinking models often forget to close), then key-specific extraction, and finally a last-resort grab of any JSON object.

The goal is resilience: AI features should work reliably even when the LLM output isn't perfectly formatted.

</vision>

<essential>
## What Must Be Nailed

- **All AI features work** - The parser should benefit both auto-categorization and merchant detection (chat uses different paths)
- **Match OpenAI behavior** - Port the existing `parse_json_flexibly` method from OpenAI's `auto_categorizer.rb` and `auto_merchant_detector.rb`
- **Graceful degradation** - Try multiple strategies; if all fail, raise a clear error

</essential>

<boundaries>
## What's Out of Scope

- **Not expanding beyond OpenAI patterns** - Port what exists; don't add new formats or strategies
- **Not fixing invalid JSON** - This is about extracting JSON from messy wrapper content, not repairing malformed JSON itself
- **Not handling streaming edge cases** - Streaming scenarios are handled differently

</boundaries>

<specifics>
## Specific Ideas

- Port the exact implementation from OpenAI:
  - `parse_json_flexibly(raw)` method with 4 strategies
  - `strip_thinking_tags(raw)` helper for `<think>...</think>` blocks
- Duplicate in both files (auto_categorizer.rb and auto_merchant_detector.rb) to match OpenAI's pattern
- Anthropic's Claude specifically may output `<thinking>` tags that need stripping

</specifics>

<notes>
## Additional Context

OpenAI's implementation was created to handle various LLM quirks including:
- Qwen-thinking models that output reasoning in tags
- Models that forget to close markdown code blocks
- JSON wrapped in various formats

The same issues apply to Anthropic's Claude, especially when using thinking-enabled models.

</notes>

---

*Phase: 19-flexible-json-parsing*
*Context gathered: 2026-01-11*
