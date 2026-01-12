# Phase 32: Accuracy Metrics - Context

**Gathered:** 2026-01-11
**Status:** Ready for planning

<vision>
## How This Should Work

Users can see a per-category breakdown of AI categorization accuracy - presented as a list showing each category with its accuracy percentage and raw counts (e.g., "Groceries: 95% (42/44 correct)").

The accuracy is calculated implicitly: when the AI categorizes a transaction and the user doesn't change it, it counts as correct. When the user changes the category, it counts as incorrect.

Accuracy should be shown for rolling time windows - last 7 days, last 30 days, all time - with the user able to switch between views.

When a user sees a category with low accuracy, they can drill in to see "Recent misses" - actual transaction rows that were miscategorized, along with the pattern that caused the confusion.

</vision>

<essential>
## What Must Be Nailed

**Actionability is the core.** The accuracy breakdown itself is useful, but what matters most is that when someone sees a low-accuracy category, they understand WHY it's failing and can take action.

The "Recent misses" view must show both:
1. The full transaction details (what was miscategorized)
2. The pattern that caused the mistake (why it failed)

This enables users to create or fix LearnedPatterns for the problematic cases.

</essential>

<boundaries>
## What's Out of Scope

- **Cost/performance metrics** - Not tracking cost per categorization, latency, or other observability stats
- **Cross-user comparisons** - Single-user metrics only, no benchmarking against other users
- **ML model retraining** - No fine-tuning of AI models, just metrics based on existing pattern matching

</boundaries>

<specifics>
## Specific Ideas

- Accuracy calculation: implicit corrections (if AI categorizes and user doesn't change it = correct, if user changes category = incorrect)
- Display format: list view with percentages and raw counts per category
- Time windows: 7 days, 30 days, all time (user can switch)
- Drill-down: "Recent misses" per category showing both transaction rows AND the problematic pattern

</specifics>

<notes>
## Additional Context

Phase depends on Phase 31 (Feedback UI) being complete - assumes the feedback mechanism for tracking implicit corrections exists.

The vision emphasizes making metrics actionable. Simply showing "Groceries: 72%" isn't enough - the user needs to see WHAT went wrong (the miscategorized transactions) and WHY (the pattern that caused it) so they can improve the system.

</notes>

---

*Phase: 32-accuracy-metrics*
*Context gathered: 2026-01-11*
