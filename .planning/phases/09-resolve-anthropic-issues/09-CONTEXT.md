# Phase 9: Resolve Anthropic Issues - Context

**Gathered:** 2026-01-10
**Status:** Ready for research

<vision>
## How This Should Work

This is a bug triage and fix phase. After completing all the testing in Phase 8, we discovered issues that need resolution. The approach is systematic:

1. **Full sweep discovery** - Test ALL features: chat, categorization, merchant detection, settings UI, provider switching
2. **Catalog everything** - Create a comprehensive ISSUES.md file listing every bug discovered
3. **Categorize** - Organize issues by severity (critical, normal, minor)
4. **Fix systematically** - Work through the catalog with clear resolution for each item

The goal isn't just to fix bugs, but to ensure **resolution clarity** - every discovered issue has a documented outcome, whether that's a fix, a "won't fix" decision, or a deferral to future work.

</vision>

<essential>
## What Must Be Nailed

- **Resolution clarity** - Every cataloged issue has a clear documented resolution
- **ISSUES.md tracking** - All discovered bugs are cataloged in a central document
- **Full feature coverage** - Test all Anthropic features, not just happy paths

</essential>

<boundaries>
## What's Out of Scope

- **No new features** - Any feature requests discovered during testing are deferred to future phases
- **Performance optimizations** - Unless blocking functionality, perf work is deferred

</boundaries>

<specifics>
## Specific Ideas

- Create ISSUES.md in the phase directory with discovered bugs
- Test only complex fixes with automated tests - simple fixes can be verified manually
- Use severity categories: critical, normal, minor

</specifics>

<notes>
## Additional Context

User emphasized a systematic approach: catalog first, then categorize, then fix. This prevents the chaos of ad-hoc bug fixing and ensures nothing slips through the cracks.

The ISSUES.md file serves as the source of truth for what was discovered and how it was resolved.

</notes>

---

*Phase: 09-resolve-anthropic-issues*
*Context gathered: 2026-01-10*
