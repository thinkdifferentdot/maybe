# Phase 2: Core Operations - Context

**Gathered:** 2025-01-09
**Status:** Ready for planning

<vision>
## How This Should Work

The core AI operations — auto-categorization and merchant detection — should work through Anthropic Claude instead of OpenAI. When transactions sync or are imported, Anthropic analyzes the description and assigns categories and merchants.

The hope is that Anthropic provides better quality: more accurate context understanding of transaction descriptions and more consistent, predictable categorization choices. Both categorization and merchant detection need to work.

Chat support is explicitly out of scope — that's Phase 3.

</vision>

<essential>
## What Must Be Nailed

Both operations must work:
- `auto_categorize` — Returns category for a transaction
- `auto_detect_merchants` — Returns merchant for a transaction

If Anthropic returns unexpected results (malformed JSON, non-existent category, timeout), it should fail loudly — no silent fallback to OpenAI. We want to know immediately if Anthropic isn't working.

</essential>

<boundaries>
## What's Out of Scope

- Chat support — that's Phase 3
- Streaming responses — basic operations only
- Provider switching UI — that's later phases
- Silent fallback to OpenAI — fail loudly instead

</boundaries>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches for Anthropic Messages API.

</specifics>

<notes>
## Additional Context

User wants Anthropic as a quality improvement over OpenAI, with both context understanding and consistency being equally important.

Error handling should be loud — if something goes wrong, we want to know about it rather than silently degrading.

</notes>

---

*Phase: 02-core-operations*
*Context gathered: 2025-01-09*
