# Phase 18: Fuzzy Category & Merchant Matching - Context

**Gathered:** 2026-01-10
**Status:** Ready for research

<vision>
## How This Should Work

Port the fuzzy name matching functionality from OpenAI to Anthropic to enable better category and merchant normalization. When the AI returns slightly different names than expected, or when users import data with messy merchant names, fuzzy matching helps clean these up automatically.

The goal is feature parity between providers: both OpenAI and Anthropic should use fuzzy matching to normalize inputs. This isn't just a straight port — there's an opportunity to improve the implementation by tuning fuzzy matching thresholds and improving code quality/organization around the algorithm.

</vision>

<essential>
## What Must Be Nailed

- **Algorithm accuracy** — The fuzzy matching algorithm must work correctly. Categories and merchants get matched even with typos, variations, or slight differences in naming.
- **Test coverage** — The ported code must have proper test coverage to ensure it works as expected. Both algorithm accuracy AND test coverage are equally critical for this phase's success.

</essential>

<boundaries>
## What's Out of Scope

- **Modifying OpenAI's existing fuzzy matching** — We're not changing how OpenAI's implementation works, only porting to Anthropic
- **Data model changes** — Changes to how categories or merchants are stored/managed are out of scope for this phase
- **New fuzzy matching features** — Beyond what OpenAI currently has; defer to future work

</boundaries>

<specifics>
## Specific Ideas

- Key use cases: import cleanup (messy merchant names from user data) AND AI normalization (slight variations in AI categorization results)
- Algorithm improvement area: threshold tuning — the distance threshold for fuzzy matching might benefit from tuning based on real-world data
- Also interested in code quality improvements: organization, error handling, testing coverage

</specifics>

<notes>
## Additional Context

User sees value in fuzzy matching for both import cleanup scenarios and AI result normalization. The "port + improve" approach suggests we should implement the feature but remain open to enhancements where they make sense — particularly around threshold tuning for the matching algorithm.

</notes>

---

*Phase: 18-fuzzy-category-merchant-matching*
*Context gathered: 2026-01-10*
