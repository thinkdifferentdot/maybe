# Phase 12: Transaction UI Actions - Context

**Gathered:** 2026-01-10
**Status:** Ready for research

<vision>
## How This Should Work

Users should be able to trigger AI categorization directly from the transaction UI—both for individual transactions and in bulk. The experience should feel instant and responsive, with inline updates that don't interrupt the flow.

**Individual transactions:** Each transaction row has an "AI categorize" button. When clicked, it shows a loading state, then instantly updates the transaction with its new category. The button is always available (even on already-categorized transactions) for re-categorization.

**Bulk operations:** Users select multiple transactions, which reveals a contextual bulk action toolbar. The toolbar shows the estimated API cost for the batch. When triggered, transactions process with inline feedback—high-confidence ones apply immediately, low-confidence ones show a confirmation dialog before applying. Errors don't stop the batch; failed transactions are skipped and summarized at the end.

**Confidence display:** After categorization, the UI shows the confidence percentage (e.g., "87% confident") so users understand how certain AI is about each suggestion.

</vision>

<essential>
## What Must Be Nailed

- **Both individual and bulk modes** — The feature needs single-transaction quick-categorization AND batch processing to be truly useful
- **Instant inline updates** — Click once, see the result immediately in place. No page loads, no modal hell.
- **Confidence transparency** — Always show the confidence percentage so users can trust (or verify) AI's decisions
- **Low-confidence confirmations** — When AI isn't sure (below ~60%), require user confirmation before applying the suggestion
- **Contextual bulk toolbar** — Bulk actions only appear when transactions are selected, keeping the UI clean

</essential>

<boundaries>
## What's Out of Scope

- **Rules system integration** — AI categorization buttons are separate from the existing rule-based categorization. No rules UI changes in this phase.
- **Auto-suggestions** — Not showing what AI *would* do until user explicitly asks. No preemptive suggestions appearing in the UI.
- **Advanced error handling** — Basic error handling (skip on failure, show summary), but not retry logic or complex recovery flows.

</boundaries>

<specifics>
## Specific Ideas

**Confidence levels:**
- Show explicit percentage display (e.g., "87% confident")
- Low confidence (below ~60%) requires confirmation before applying
- For bulk: individual confirmations for each low-confidence suggestion

**UI placement:**
- Individual button: in each transaction row
- Bulk actions: contextual toolbar that appears only when transactions are selected
- Individual buttons visible on uncategorized transactions; available on all for re-categorization

**Re-categorization:**
- Individual button works on already-categorized transactions
- Flow is same as first-time: replace immediately with confirmation if low confidence

**Cost transparency:**
- Bulk operations show estimated API cost before running
- Cost updates as user selects/deselects transactions

**Error handling:**
- Bulk operations continue on errors
- Skip failed transactions, show summary at end

</specifics>

<notes>
## Additional Context

User emphasized that individual quick-categorize and bulk batch processing are equally important—the feature isn't complete without both.

The confidence display is central to the UX: users should always know how certain AI is about each suggestion. This builds trust and helps users decide when to manually review.

The confirmation requirement for low-confidence suggestions balances automation with control—AI can be fast when confident, but asks for human help when uncertain.

</notes>

---

*Phase: 12-transaction-ui-actions*
*Context gathered: 2026-01-10*
