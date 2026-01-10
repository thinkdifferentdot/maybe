# Phase 5: Settings Model - Context

**Gathered:** 2026-01-09
**Status:** Ready for planning

<vision>
## How This Should Work

A unified provider configuration system where users select their AI provider once (globally), and the app uses that choice across all AI features. The provider selection drives which API key and model fields are used — Anthropic fields when Anthropic is chosen, OpenAI fields when OpenAI is chosen.

The model should support both self-hosted deployments (ENV-based configuration) and managed deployments (database-stored settings). This mirrors the existing OpenAI pattern but extends it to support multiple providers through a single choice point.

</vision>

<essential>
## What Must Be Nailed

- **Provider selector field** — The `llm_provider` field that stores the user's choice (openai/anthropic)
- **Secure credential storage** — API keys and model configuration with proper validation and ENV fallbacks
- **Parallel to OpenAI** — Anthropic fields (`anthropic_access_token`, `anthropic_model`) following the same pattern as existing OpenAI settings

Both the selector UX and secure backend storage are equally critical — they must work together.

</essential>

<boundaries>
## What's Out of Scope

- **Settings UI** — Phase 6 handles the frontend form, dropdowns, and user-facing configuration interface
- **Per-feature provider selection** — Provider choice is global, not per-feature
- **Multi-level selection** — No family/user/feature hierarchy — single global setting only

</boundaries>

<specifics>
## Specific Ideas

- Unified provider config: one place where provider choice determines which credentials are used
- Global setting only: provider selection lives at the application level, not per-user or per-feature
- Mirror existing OpenAI patterns for API key and model storage
- ENV variable fallbacks for self-hosted deployments (standard Rails pattern)

</specifics>

<notes>
## Additional Context

User emphasized "unified" — the provider selection should feel like one cohesive configuration system, not separate settings bolted together. The choice drives everything else.

Backend-only phase — all UI work deferred to Phase 6.

</notes>

---

*Phase: 05-settings-model*
*Context gathered: 2026-01-09*
