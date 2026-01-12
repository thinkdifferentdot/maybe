# Phase 30: LearnedPattern Integration - Context

**Gathered:** 2026-01-11
**Status:** Ready for planning

<vision>
## How This Should Work

When the AI categorizes a transaction, it should learn from the user's past behavior. The user has already created LearnedPattern records through their categorization history — now those patterns should flow back into the AI as "strong hints" about how this specific user categorizes things.

I imagine it working like this:
1. Before each AI categorization call, find relevant LearnedPatterns for this transaction
2. Select the top 3 most relevant patterns (prioritizing manually confirmed ones)
3. Inject them into the prompt as a separate "user patterns" section — not mixed with the generic few-shot examples
4. The AI sees these as strong signals about this user's preferences, not just generic examples

The goal is better accuracy through personalization. The AI shouldn't just categorize like "a generic user" — it should categorize like *this* user.

</vision>

<essential>
## What Must Be Nailed

- **Accuracy improvement** — This is the non-negotiable. The integration must measurably improve categorization accuracy, otherwise the phase is a failure.
- **Merchant matching** — Patterns should be selected based on merchant/payee similarity (fuzzy matching)
- **Quality over quantity** — Only include patterns that meet a relevance threshold, not just filling 3 slots with noise

</essential>

<boundaries>
## What's Out of Scope

- **UI features** — Showing users which patterns were used, or any UI for managing patterns, is Phase 31 (Feedback UI)
- **Pattern creation** — This phase assumes LearnedPattern records already exist. Creating/updating patterns happens elsewhere (bulk approve, individual confirm)
- **Category-based matching** — Selection is merchant-only, not category matching (could be future work)

</boundaries>

<specifics>
## Specific Ideas

- **Separate "user patterns" section** in the prompt — emphasize these as *this user's* patterns, distinct from generic examples
- **Fixed count of 3 patterns** — keeps prompts focused while providing sufficient signal
- **Prioritize manually confirmed** — patterns from individual "approve" actions rank higher than bulk-created ones
- **Quality threshold** — if fewer than 3 patterns meet the relevance bar, only include the ones that do (could be 0, 1, or 2)
- **Fuzzy merchant matching** — use the existing fuzzy_name_match? pattern from the codebase

</specifics>

<notes>
## Additional Context

This builds directly on Phase 29 (FewShotExamples concern). The FewShotExamples module already exists with static baseline examples. This phase extends it to dynamically include user-specific LearnedPatterns.

The LearnedPattern model already exists from v1.1. It stores:
- `payee` — the merchant/payee name
- `category_id` — what this user categorized it as
- `confidence` — how confident the system was (may be useful for weighting)

User wants these presented as "strong hints" to the AI — not just examples, but signals like "this user has consistently categorized Starbucks as Coffee: Cafes."

</notes>

---

*Phase: 30-learned-pattern-integration*
*Context gathered: 2026-01-11*
