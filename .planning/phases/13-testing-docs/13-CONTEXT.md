# Phase 13: Testing & Docs - Context

**Gathered:** 2026-01-10
**Status:** Ready for planning

<vision>
## How This Should Work

This is a testing-focused phase where we verify everything works correctly after implementing the AI auto-categorization triggers in Phases 10-12. The approach is comprehensive: unit tests for new models/controllers plus integration tests for full trigger flows.

We need to test the entire AI feature surface to ensure no regressions while confirming the new trigger paths work. This means verifying all AI features (chat, merchant detection, auto-categorization) work with both OpenAI and Anthropic providers.

When issues are found, document them first and complete the full test sweep before fixing — this gives us a complete picture of what needs attention.

Documentation is incidental: code comments and test coverage only, no user-facing guides or README updates.

</vision>

<essential>
## What Must Be Nailed

- **No regressions**: Existing AI features (chat, merchant detection, Rules) must still work perfectly after adding the new triggers
- **New triggers work**: The three new trigger paths (CSV import, Lunchflow sync, UI action buttons) must function correctly
- **Both providers**: All features must work with both OpenAI and Anthropic providers
- **Settings integration**: The toggle settings from Phase 10 must correctly control trigger behavior
- **Confidence feature**: Confidence badge display AND low-confidence confirmation flows must work

</essential>

<boundaries>
## What's Out of Scope

- **No new features**: This phase is verification only — no new functionality beyond what's in plans 10-12
- **Performance testing**: Not optimizing AI response times or testing batch performance for large datasets
- **User-facing docs**: No README or user guide updates — code comments and test coverage only

</boundaries>

<specifics>
## Specific Ideas

**Test coverage approach:**
- Unit tests for new models (LearnedPattern) and controllers (AiCategorizations, BulkAiCategorizations)
- Integration tests for end-to-end flows:
  - CSV import → AI categorization
  - Lunchflow sync → AI categorization
  - UI button click → AI categorization
- Full AI regression across all features with both providers

**Issue handling:**
- Document failures and continue full test sweep
- Fix everything at once after complete picture is gathered

**Settings integration:**
- Verify ai_categorize_on_import, ai_categorize_on_sync, ai_categorize_on_ui_action actually control triggers

**Confidence feature:**
- Test confidence badge color coding (>80% green, 60-80% yellow, <60% orange)
- Test low-confidence confirmation flow

</specifics>

<notes>
## Additional Context

User emphasized that both "no regressions" and "new triggers work" are equally important — this is not a prioritized list but a dual requirement.

The testing should be thorough enough that we have confidence everything works, but pragmatic enough not to delay shipping.

</notes>

---

*Phase: 13-testing-docs*
*Context gathered: 2026-01-10*
