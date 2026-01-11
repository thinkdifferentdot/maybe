# Phase 29: Improve Categorization Prompts - Context

**Gathered:** 2026-01-11
**Status:** Ready for planning

<vision>
## How This Should Work

AI categorization should return fewer null results by giving the LLM concrete examples to learn from. I imagine a hybrid approach:

1. **Static baseline examples** — Hardcode 3-5 representative transaction→category examples directly in the prompt template. These serve as the foundation—clear, canonical examples that show what "good" categorization looks like.

2. **Optional user pattern enhancement** — After the baseline, optionally inject examples from the user's own LearnedPattern data. This personalizes the prompt with their actual transaction history and categories.

The prompt becomes: "Here's how categorization works (static examples), AND here's how YOU categorize things (your patterns)."

The AI should see the pattern and apply it to new transactions.

</vision>

<essential>
## What Must Be Nailed

- **Ship something** — Get it working. Any reduction in nulls is a win. Don't overengineer.
- **Reuse LearnedPattern** — The model already exists; leverage it rather than building new infrastructure.
- **Mixed approach** — Static baseline + optional user patterns, not one or the other.

</essential>

<boundaries>
## What's Out of Scope

- **Full prompt overhaul** — We're adding few-shot examples, not rewriting the entire categorization prompt structure.
- **Merchant detection** — Focus only on categorization prompts, not auto_detect_merchants.
- **Provider-specific work** — If it works for one provider, good enough. Parity can come later.

</boundaries>

<specifics>
## Specific Ideas

- Static examples should cover common transaction types (grocery stores, restaurants, gas stations, subscriptions)
- LearnedPattern integration should be optional—fallback gracefully if no patterns exist
- Keep the prompt size reasonable—don't stuff it with 50 examples

</specifics>

<notes>
## Additional Context

The user emphasized "ship something" over perfection. The goal is incremental improvement to reduce null categorization results, not a complete AI system overhaul.

Current state: >50% null categorization results. Even a modest improvement through few-shot learning would be valuable.

</notes>

---

*Phase: 29-improve-categorization-prompts*
*Context gathered: 2026-01-11*
