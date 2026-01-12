# Phase 31: Feedback UI - Context

**Gathered:** 2026-01-11
**Status:** Ready for planning

<vision>
## How This Should Work

When AI categorizes a transaction, the category is applied immediately but visually marked as an AI suggestion. The user can then provide explicit feedback through checkmark/X buttons that appear in specific contexts.

The flow feels confident and low-friction:
1. AI suggests and applies a category (no waiting for approval)
2. Category is visually distinct so user knows it's from AI
3. User sees checkmark/X buttons next to the category
4. User clicks checkmark if correct, X if wrong (and can edit the category)
5. Feedback is captured and stored for learning

This appears in two contexts:
- **Review screen** — dedicated area for reviewing recent AI categorizations
- **Transaction detail page** — focused feedback when viewing a single transaction

</vision>

<essential>
## What Must Be Nailed

The **explicit feedback mechanism** is the core of this phase. The checkmark/X buttons are non-negotiable because they give us clean training data. Without explicit feedback, we can't build quality evaluation frameworks in later phases.

Secondary essentials:
- Visual distinction — users must instantly recognize an AI-suggested category
- LearnedPattern integration — feedback should create/update learned patterns for Phase 30's few-shot pipeline

</essential>

<boundaries>
## What's Out of Scope

- **Model retraining** — Phase 32 (Accuracy Metrics) handles using the feedback data
- **Batch review workflow** — the existing bulk review from Phase 12 handles approval/rejection; this is about adding explicit feedback to that flow
- **Transactions list inline feedback** — feedback buttons only in review screen and detail page, not everywhere categories appear
- **Merchant detection feedback** — only category feedback, merchant is future work
- **New database tables** — reuse existing LearnedPattern model

</boundaries>

<specifics>
## Specific Ideas

- Checkmark/X buttons appear next to AI-suggested categories
- User can edit category AND give feedback in one flow (click X, then edit)
- Applied-but-marked approach: AI suggestion is active but visually distinct
- Two UI contexts:
  1. Review screen for recent AI categorizations
  2. Transaction detail page for single-item feedback
- Feedback creates or updates LearnedPattern records
- Explicit approval/rejection means clean training data vs. implicit learning from edits

</specifics>

<notes>
## Additional Context

User emphasized that explicit feedback (not implicit) is key because it produces clean training data. The checkmark/X pattern gives binary confirmation that's easy to capture and use in Phase 32's accuracy metrics tracking.

The "applied but marked" approach reduces friction compared to requiring approval before applying, while still maintaining clarity about what's AI-generated vs. user-chosen.

Connecting to LearnedPattern means this phase directly enables Phase 30's few-shot examples integration — user feedback becomes the training data that improves future categorization.

</notes>

---

*Phase: 31-feedback-ui*
*Context gathered: 2026-01-11*
