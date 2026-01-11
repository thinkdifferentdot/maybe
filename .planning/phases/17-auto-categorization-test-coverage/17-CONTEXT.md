# Phase 17: Auto-Categorization Test Coverage - Context

**Gathered:** 2026-01-10
**Status:** Ready for planning

<vision>
## How This Should Work

This phase fills the test coverage gap between OpenAI and Anthropic providers. OpenAI has comprehensive test coverage that we want to match for Anthropic — validating that Anthropic's auto_categorize, auto_detect_merchants, and chat_response methods all work correctly.

The vision is **functional validation through parity**: every public method in Provider::Anthropic should have a test that mirrors the OpenAI test structure, ensuring the Anthropic implementation works just as well as the proven OpenAI implementation.

</vision>

<essential>
## What Must Be Nailed

- **100% method coverage** — Every public method in Provider::Anthropic should have a corresponding test
- **Parity with OpenAI scenarios** — Test the same happy paths, error cases, and edge conditions that OpenAI tests cover
- **Validate functionality works** — Tests should prove that Anthropic actually calls the API and returns correct results

</essential>

<boundaries>
## What's Out of Scope

None explicitly excluded — this is a comprehensive coverage sweep across all Anthropic methods.

</boundaries>

<specifics>
## Specific Ideas

- **Match OpenAI test patterns** — Use the same VCR patterns, helper methods, and assertion styles as the existing OpenAI tests
- **Follow existing Anthropic test style** — Stay consistent with what's already in `anthropic_test.rb`
- **VCR details to be determined** — Whether to use real cassettes, mocks, or a mix will be figured out during implementation

</specifics>

<notes>
## Additional Context

This is part of v1.2 Anthropic Feature Parity milestone. The roadmap notes this phase depends on Phase 16 (Real Streaming Support) completing first, since streaming may affect how tests are structured.

User wants to achieve confidence that Anthropic works as well as OpenAI in production through comprehensive test coverage.

</notes>

---

*Phase: 17-auto-categorization-test-coverage*
*Context gathered: 2026-01-10*
