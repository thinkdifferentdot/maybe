# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-10)

**Core value:** Smooth UX configuration — Users select AI provider through settings dropdown
**Current focus:** Milestone v1.2 — Anthropic Feature Parity

## Current Position

Phase: Phase 16 of 21 (Real Streaming Support)
Plan: 1 of 1 in current phase
Status: Phase complete
Last activity: 2026-01-10 — Completed 16-01-PLAN.md

Progress for Phase 16: ██████████ 100%
Overall v1.2 Progress: ██░░░░░░░░ 17% (1 of 6 phases complete)

**Summary (16-01):** Implemented token-by-token streaming for Anthropic chat responses using MessageStream API. Created Provider::Anthropic::ChatStreamParser to convert MessageStream events to ChatStreamChunk format. Updated Provider::Anthropic#chat_response to use client.messages.stream() when streamer provided. Added comprehensive test coverage (13 tests) for ChatStreamParser event handling.

**Summary (15-01):** Converted Anthropic model field from text input to select dropdown with dynamic model fetching from Anthropic API. Created `/settings/hosting/anthropic_models` backend endpoint that proxies requests to Anthropic's `/v1/models` API. Implemented `anthropic-model-select` Stimulus controller for fetching models on page load, populating select dropdown, and managing "Custom..." option for manual entry. Added comprehensive test coverage with mocked API responses.

**Summary (14.2-01):** Fixed missing toggle labels on auto-categorization settings page. Root cause was DS::Toggle component not accepting or displaying label parameter. Fixed by adding label attribute to component and updating template to render label text conditionally with flex container for proper alignment.

**Summary (14.1-01):** Fixed 404 error on individual AI categorize button. Root cause was view sending transaction.id instead of entry.id (different UUIDs in delegated_type pattern). Added controller-level rescue_from to override StoreLocation concern's 404 handling. Returns 422 for orphaned entries instead of 404.

**Summary (13-02):** Added comprehensive test coverage for AI categorization controllers (29 new tests: 10 individual controller tests, 13 bulk controller tests, 6 system tests). Tests cover auth, authorization, Turbo Stream responses, confidence handling, error handling, and Stimulus integration. Fixed route definition bug (ai_categorization controller path) and controller bug (transactions.reload on Array).

**Summary (13-03):** Verified existing AI trigger tests for CSV import and Lunchflow sync settings integration. Created confidence badge view tests (9 test cases) covering all confidence ranges (>80% green, 60-80% yellow, <60% orange) and boundary conditions.

**Summary (13-04):** Full AI regression test suite executed - all 1644 tests passing. Verified LearnedPattern normalization, matching, integration; AI categorization controllers (individual, bulk, system); Settings model integration; confidence badge view rendering; CSV import and Lunchflow sync AI triggers; cost estimation; edge cases; and error handling. No regressions found.

**Summary (14-01):** Created comprehensive manual testing checklist document for v1.1 AI auto-categorization features. Checklist covers all 4 implemented features (Settings UI, CSV Import AI trigger, Individual AI categorize button, Bulk AI categorization) with 275 checkable items, clear test steps, expected outcomes, edge cases, and issues tracking table.

## Next Milestone Goals

**v1.2: Anthropic Feature Parity** — 6 phases
- Phase 16: Real Streaming Support — Implement true streaming for Anthropic chat responses
- Phase 17: Auto-Categorization Test Coverage — Add missing test to match OpenAI
- Phase 18: Fuzzy Category & Merchant Matching — Port fuzzy_name_match from OpenAI
- Phase 19: Flexible JSON Parsing — Handle LLM output quirks (thinking tags, unclosed markdown)
- Phase 20: Extract UsageRecorder Concern — DRY up usage recording code
- Phase 21: Custom Provider Support — Allow Anthropic-compatible APIs

## Performance Metrics

**Velocity:**
- Total plans completed: 46 (26 v1.0 + 20 v1.1)
- Total commits: 48 (implementation + fixes)
- Average duration: ~6 min
- Total execution time: ~280 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1 (Foundation) | 3 | 9 min | 3 min |
| 2 (Core Operations) | 3 | 14 min | 4.7 min |
| 3 (Chat Support) | 4 | 17 min | 4.3 min |
| 4 (Registry Integration) | 3 | 8 min | 2.7 min |
| 5 (Settings Model) | 3 | 15 min | 5 min |
| 6 (Settings UI) | 4 | 10 min | 2.5 min |
| 7 (Langfuse Integration) | 1 | 5 min | 5 min |
| 8 (Validation & Testing) | 3 | 40 min | 13.3 min |
| 9 (Resolve Issues) | 1 | 15 min | 15 min |
| 9.1 (get_transactions fix) | 1 | 26 min | 26 min |
| 10 (Settings & Config) | 1 | ~5 min | ~5 min |
| 11 (Import Triggers) | 4 | ~35 min | ~9 min |
| 12 (Transaction UI Actions) | 3 | ~15 min | ~5 min |
| 13 (Testing & Docs) | 4 | ~35 min | ~9 min |
| 14 (Manual Testing) | 1 | <1 min | <1 min |
| 14.1 (Fix AI Categorize Route) | 1 | ~5 min | ~5 min |
| 14.2 (Fix Auto-Categorize Labels) | 1 | ~1 min | ~1 min |
## Accumulated Context

### v1.0 Milestone Summary

**Delivered:**
- Provider::Anthropic class with full implementation (auto_categorize, auto_detect_merchants, chat_response)
- Provider registry integration with Anthropic cost tracking
- Settings UI with provider selector dropdown and Anthropic configuration form
- Comprehensive test suite (11 Anthropic tests, 56 OpenAI regression tests)
- VCR cassettes for offline testing
- All bugs resolved (provider switching, SDK compatibility, VCR test environment)

**Stats:**
- 62 files changed
- 6,372 lines added
- 59 milestone-related commits
- ~1 day development time (2026-01-09 → 2026-01-10)

### v1.1 Milestone Progress

**Phase 10 - Settings & Config (COMPLETE):**
- AI trigger settings added to Setting model (ai_categorize_on_import, ai_categorize_on_sync, ai_categorize_on_ui_action)
- Settings UI for toggling AI auto-categorization triggers
- All default to false (opt-in)

**Phase 11 - Import Triggers (COMPLETE):**
- 11-01: LearnedPattern model for AI categorization pattern learning
- 11-02: AI categorization trigger in CSV import flow
- 11-03: AI categorization trigger in Lunchflow sync jobs
- 11-04: Bulk review workflow for approving/rejecting AI suggestions

**Phase 12 - Transaction UI Actions (COMPLETE):**
- 12-01: Backend Provider Selection & Confidence
- 12-02: Individual AI categorize button
- 12-03: Bulk AI categorize workflow

**Phase 13 - Testing & Docs (COMPLETE):**
- 13-01: LearnedPattern model tests (50 tests: validations, normalization, matching)
- 13-02: AI categorization controllers tests (29 tests: individual controller, bulk controller, system tests)
- 13-03: Settings & confidence integration tests (verified existing, added confidence badge view tests)
- 13-04: Full AI regression test suite (all 1644 tests passing)

**Phase 14 - Manual Testing (COMPLETE):**
- 14-01: Manual testing checklist document for v1.1 features (275 checkable items)

**Decisions:**
- Use PostProcessor pattern for batch AI categorization after sync
- Track imported transaction IDs in memory (no DB schema changes)
- Async job to avoid blocking sync operations
- Only categorize uncategorized, enrichable transactions
- Rails 7.2 ActiveJob::TestHelper uses `assert_enqueued_jobs` not `.jobs.count`
- Confidence stored in transaction.extra metadata (no new table)
- Default confidence 1.0 until providers return actual scores
- Bulk review workflow: Approve creates learned pattern, Reject removes category
- 7-day window for "recent AI" filter (configurable via scope parameter)
- Cost estimation: 100 tokens/transaction + 50/category * model pricing
- 60% confidence threshold for low-confidence confirmations
- Errors per transaction continue batch process (don't stop bulk operation)

### Deferred Issues

None.

### Roadmap Evolution

- **v1.0 COMPLETE**: Anthropic Support (2026-01-10) — Full provider integration shipped
- **v1.1 COMPLETE**: AI Auto-Categorization Triggers (2026-01-10) — 5 phases + 2 urgent fixes + model autopopulate feature
- **v1.2 CREATED** (2026-01-10): Anthropic Feature Parity — 6 phases (Phase 16-21) to achieve feature parity with OpenAI implementation

### Blockers/Concerns

None.

## Session Continuity

Last session: 2026-01-10
Stopped at: Completed 16-01-PLAN.md
Resume file: None
