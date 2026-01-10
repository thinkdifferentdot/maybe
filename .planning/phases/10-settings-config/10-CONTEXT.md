# Phase 10: Settings & Config - Context

**Gathered:** 2026-01-10
**Status:** Ready for planning

<vision>
## How This Should Work

Users get granular, toggle-based control over when AI auto-categorization runs. There's a dedicated "Auto-Categorization" settings section with independent toggles for each trigger context: CSV import, sync jobs, and manual UI actions.

The pattern is opt-in by default — AI categorization is disabled on all triggers until users explicitly enable what they want. This respects user choice and avoids surprise AI costs.

Settings should work seamlessly regardless of which AI provider the user has selected (OpenAI or Anthropic).

</vision>

<essential>
## What Must Be Nailed

- **Reliability** — Toggles must be correctly checked before any AI categorization runs
- **Discoverability** — Users should know these options exist and find them easily
- **Provider-agnostic** — Settings work the same whether OpenAI or Anthropic is selected

</essential>

<boundaries>
## What's Out of Scope

- **Not implementing the actual triggers** — CSV import, sync jobs, and UI actions are Phases 11-12
- **Not building cost tracking or usage analytics** — Just the on/off controls
- **Not adding advanced AI configuration** — No per-trigger model selection or temperature controls

</boundaries>

<specifics>
## Specific Ideas

- **Per-trigger toggles:** Separate on/off for CSV import, sync jobs, manual actions
- **Opt-in defaults:** All toggles default to OFF
- **Dedicated section:** New "Auto-Categorization" area in settings (not merged into existing AI/LLM settings)
- **Provider independence:** Settings apply regardless of which LLM provider is selected

</specifics>

<notes>
## Additional Context

User wants simple, clear control — not buried in advanced settings. The dedicated "Auto-Categorization" section signals this as a distinct feature area worth of user attention.

Opt-in by default is important: users should consciously choose to use AI rather than having it run unexpectedly.

</notes>

---

*Phase: 10-settings-config*
*Context gathered: 2026-01-10*
