# Phase 16: Real Streaming Support - Context

**Gathered:** 2026-01-10
**Status:** Ready for research

<vision>
## How This Should Work

Anthropic chat responses should stream token-by-token, following Anthropic's native streaming API behavior. The user experience should match the mental model of watching someone type in real-time — text appears progressively as each token is generated, not all at once.

The implementation should follow whatever patterns Anthropic's Ruby gem and API naturally provide rather than forcing a different abstraction on top.

</vision>

<essential>
## What Must Be Nailed

- **Functional parity** — Anthropic chat responses must actually stream token-by-token like OpenAI currently does
- **API-native behavior** — Work with Anthropic's streaming patterns as they exist, not against them
- **Chat only** — Focus on streaming for chat responses; auto-categorize and merchant detection don't need streaming (they run async anyway)

</essential>

<boundaries>
## What's Out of Scope

- Auto-categorization streaming — runs in background jobs, doesn't need real-time token flow
- Merchant detection streaming — also async, no UI that benefits from streaming
- Visual parity with OpenAI — function over form; as long as text appears progressively, exact visual match isn't critical
- Custom streaming abstractions — use Anthropic's native patterns, don't invent new ones

</boundaries>

<specifics>
## Specific Ideas

- Token-by-token flow is the desired mental model
- Graceful degradation is acceptable if streaming fails (implementation detail to be determined)
- Functional correctness matters more than visual polish

</specifics>

<notes>
## Additional Context

User emphasized "API-native behavior" — they want the implementation to work with Anthropic's streaming API as designed rather than forcing it into an existing abstraction.

Error handling and edge cases (what if streaming fails) left to implementation judgment.

</notes>

---

*Phase: 16-real-streaming*
*Context gathered: 2026-01-10*
