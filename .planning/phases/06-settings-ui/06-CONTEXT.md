# Phase 6: Settings UI - Context

**Gathered:** 2026-01-09
**Status:** Ready for planning

<vision>
## How This Should Work

Users configure their AI provider through a clean settings interface where they first select their provider (OpenAI or Anthropic), and then the relevant configuration fields are revealed below for that provider.

The interaction flow: Provider dropdown first → Reveal relevant config section → Enter API key and model → Save button to commit.

The UI should feel like a natural extension of existing Sure settings — same patterns, same visual language, not a "bolted on" feature. When you switch providers, the form adapts to show only what's relevant for that choice.

</vision>

<essential>
## What Must Be Nailed

- **Consistency with existing UI** — This should feel native to Sure. Follow existing settings patterns, use the same components/styling/interactions as other settings areas.
- **Clear provider relationship** — The mental model is obvious: select provider first, then configure that provider. No confusion about which fields apply to which choice.
- **Integration with existing API settings** — Provider configuration lives where API keys are already configured, not a separate or isolated section.

</essential>

<boundaries>
## What's Out of Scope

- Advanced provider options (model selection dropdowns, timeout configuration, custom base URLs)
- Connection testing (no "Test Connection" buttons or API validation)
- Active provider indicators (no visual indication of which provider is currently in use)
- Auto-save behavior (everything requires explicit save action)

</boundaries>

<specifics>
## Specific Ideas

- Provider selection is a dropdown that reveals the relevant configuration section below
- Only the selected provider's fields are visible at any time (hide/show based on selection)
- All changes require explicit save button — no auto-save
- Lives in existing API settings area, not a new dedicated section

</specifics>

<notes>
## Additional Context

User emphasized UI consistency over features. The priority is making this feel like a natural part of Sure's existing settings, not a new or special subsystem.

The "reveal on selection" pattern provides a clean, focused experience — users only see fields relevant to their chosen provider, reducing cognitive load.

</notes>

---

*Phase: 06-settings-ui*
*Context gathered: 2026-01-09*
