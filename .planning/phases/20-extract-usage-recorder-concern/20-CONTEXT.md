# Phase 20: Extract UsageRecorder Concern - Context

**Gathered:** 2026-01-11
**Status:** Ready for planning

<vision>
## How This Should Work

A plug-and-play module that any provider can include to handle usage recording automatically. The concern should discover what needs to be recorded from the response without requiring explicit method calls from the provider class.

This is about clean separation — isolating usage recording logic into its own module makes the main provider classes cleaner and easier to understand. Both OpenAI and Anthropic (and future providers) should be able to use the same usage recording logic without duplication.

</vision>

<essential>
## What Must Be Nailed

- **Zero behavior change** — The module works correctly and records usage accurately; bugs are the enemy
- **Code clarity** — The code becomes more readable and easier to understand after extraction
- **Plug-and-play integration** — Providers simply `include UsageRecorder` and it works

</essential>

<boundaries>
## What's Out of Scope

- Only refactor the existing duplication — don't add new features or change how usage recording works fundamentally
- Broader cleanup of related patterns (cost tracking, Langfuse tracing) is out of scope — stay focused on usage recording DRY-up

</boundaries>

<specifics>
## Specific Ideas

- Providers should `include UsageRecorder` and the concern figures out what to record from the response automatically
- Automatic discovery pattern — not explicit `record_usage(response)` calls
- The concern should be completely self-contained

</specifics>

<notes>
## Additional Context

User emphasized clean separation of concerns — the module should be isolated and reusable. Testing approach left to implementation judgment based on what's discovered in the codebase.

</notes>

---

*Phase: 20-extract-usage-recorder-concern*
*Context gathered: 2026-01-11*
