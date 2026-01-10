# Phase 14: Manual Testing - Context

**Gathered:** 2026-01-10
**Status:** Ready for planning

<vision>
## How This Should Work

A static markdown document that serves as an interactive testing checklist. The user works through it in their browser while testing the application in a separate tab/window, checking off features as they verify them.

The checklist should be organized around the new v1.1 AI features - settings UI, CSV import triggers, bulk AI categorization - providing clear steps to verify each feature works as intended.

</vision>

<essential>
## What Must Be Nailed

- **v1.1 AI feature focus** - Only test the new AI auto-categorization triggers from v1.1 (settings, CSV import, bulk actions)
- **Checkable format** - Markdown checkboxes that can be checked off as features are verified
- **Clear test steps** - Each feature should have specific actions to perform and expected outcomes

</essential>

<boundaries>
## What's Out of Scope

- **Documentation writing** - This is pure QA verification, not creating user-facing docs
- **v1.0 regression testing** - Not testing Anthropic provider features from v1.0 (that was Phase 8)
- **Performance testing** - Functional verification only, not load/stress testing
- **Automated testing** - This is manual QA only

</boundaries>

<specifics>
## Specific Ideas

- Static markdown document (markdown/printable checklist referenced while testing)
- Focus on v1.1 features: settings UI toggles, CSV import AI trigger, bulk AI categorization button
- Checkbox format for easy tracking of what's been verified

</specifics>

<notes>
## Additional Context

User wants a practical testing guide they can work through in their browser while testing in a separate window. The focus is strictly on the new v1.1 AI auto-categorization features - not a full regression test of everything.

</notes>

---

*Phase: 14-manual-testing*
*Context gathered: 2026-01-10*
