# Phase 11: Import Triggers - Context

**Gathered:** 2026-01-10
**Status:** Ready for research

<vision>
## How This Should Work

AI categorization should happen automatically during CSV imports and Lunch Money syncs, but in a smart, cost-effective way that learns from user decisions over time.

The flow:
1. User imports CSV (opt-in checkbox) or runs Lunch Money sync
2. AI categorizes all uncategorized transactions
3. User reviews suggestions in bulk after import completes
4. Approved suggestions create learned patterns
5. Future transactions matching learned patterns are auto-approved

The system feels intelligent — it gets smarter the more you use it. Once you approve "Amazon → Shopping", you never have to categorize Amazon again.

Configurable timing (immediate vs background) is handled in Phase 10 settings.

</vision>

<essential>
## What Must Be Nailed

All three are equally essential to success:

1. **Learning system** — Lightweight "learned patterns" that remember approved AI suggestions and auto-approve future matches (per-family, fuzzy matching)

2. **AI accuracy** — Quality suggestions that users actually want to approve

3. **Review workflow** — Bulk review screen after import completes where users approve/reject AI suggestions

</essential>

<boundaries>
## What's Out of Scope

- Settings UI for cost limits and timing — that's Phase 10
- Individual/bulk AI categorization buttons in transaction UI — that's Phase 12
- Plaid/SimpleFIN bank syncs — out of scope for Phase 11 (CSV Import + Lunch Money only)
- Real Rules creation — learned patterns are a separate, lighter-weight system

</boundaries>

<specifics>
## Specific Ideas

**Trigger methods:**
- CSV Import: Opt-in checkbox on import form
- Lunch Money Sync: Defer to Phase 10 settings configuration

**Learned patterns:**
- Per-family only (no sharing across users)
- Fuzzy matching (not just exact string matches)
- Created when user approves an AI suggestion
- Auto-approve future transactions that match patterns

**Fallback behavior:**
- If no learned pattern matches, always run AI (don't skip)

**Review UX:**
- Bulk review after import completes (not during import)
- Follow existing Sure UI patterns (no special requirements)

**Cost controls:**
- Configurable limits (handled in Phase 10 settings)

</specifics>

<notes>
## Additional Context

This is part of v1.1 milestone — expanding AI categorization beyond the current Rules-only approach.

The key innovation is the "learned patterns" system — separate from full Rules, lighter weight, but providing the same auto-categorization benefit over time.

User wants a smart hybrid: AI suggestions that build up automatic approval through use, not blind auto-categorization of everything.

</notes>

---

*Phase: 11-import-triggers*
*Context gathered: 2026-01-10*
