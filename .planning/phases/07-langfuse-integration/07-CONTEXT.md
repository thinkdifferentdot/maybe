# Phase 7: Langfuse Integration - Context

**Gathered:** 2026-01-09
**Status:** Ready for research

<vision>
## How This Should Work

Anthropic requests should appear in Langfuse with observability tracing adapted to Anthropic's specific structure. The key is capturing tool_use and tool_result blocks naturally in the trace span structure — Anthropic's tool calling format is different from OpenAI's, and the traces should reflect that rather than forcing it into OpenAI's shape.

The integration should reuse existing Langfuse tracing patterns used for OpenAI, adapting them for Anthropic's response format.

</vision>

<essential>
## What Must Be Nailed

- **Trace visibility** — Having Anthropic requests appear in Langfuse at all, even if some fields are imperfect
- **Tool calling structure** — Represent Anthropic's tool_use and tool_result blocks naturally in the trace span structure

</essential>

<boundaries>
## What's Out of Scope

No specific exclusions — open to exploring what makes sense as we work through it.

</boundaries>

<specifics>
## Specific Ideas

- Reuse the existing Langfuse wrapper/tracing code used for OpenAI
- Adapt the patterns rather than creating entirely new infrastructure

</specifics>

<notes>
## Additional Context

User emphasized reusing existing patterns rather than building new infrastructure. The goal is adaptation, not reinvention.

</notes>

---

*Phase: 07-langfuse-integration*
*Context gathered: 2026-01-09*
