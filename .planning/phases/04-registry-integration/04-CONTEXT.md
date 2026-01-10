# Phase 4: Registry Integration - Context

**Gathered:** 2026-01-09
**Status:** Ready for planning

<vision>
## How This Should Work

Anthropic should feel like an "equal citizen" to OpenAI in the provider system. When you interact with the registry — discovering providers, getting an instance, calling methods — there should be no sense that Anthropic is a second-class addition. It's just another provider, following the same patterns, with the same discoverability.

The registry exposes Anthropic identically to how it exposes OpenAI. Code calling `Provider.anthropic` or looking up available providers should feel seamless — like Anthropic was always there.

</vision>

<essential>
## What Must Be Nailed

- **Registry consistency** — The registry must expose Anthropic identically to OpenAI. Same patterns, same discoverability, no special cases.
- **Pricing accuracy** — Cost tracking must work. LlmUsage should properly calculate Anthropic request costs so we know what users are spending.

Both are equally core to this phase. One without the other would be incomplete.

</essential>

<boundaries>
## What's Out of Scope

- **No UI yet** — Phase 4 is backend plumbing only. Provider selector dropdown and configuration forms come in Phase 6.
- **No settings model changes** — API keys, model selection, and provider choice are Phase 5.
- **No actual usage** — We're making Anthropic available and trackable, but it's not selectable by users yet.

</boundaries>

<specifics>
## Specific Ideas

No specific requirements — follow existing OpenAI patterns in the registry and LlmUsage cost calculations.

</specifics>

<notes>
## Additional Context

User emphasized the "equal citizen" framing — this is about parity, not just "it works." The feeling matters: when you interact with the provider system, Anthropic should feel as native as OpenAI.

Both registry integration AND cost tracking are non-negotiable for this phase.

</notes>

---

*Phase: 04-registry-integration*
*Context gathered: 2026-01-09*
