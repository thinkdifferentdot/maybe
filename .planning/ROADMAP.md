# Roadmap: Anthropic Support for Sure

## Overview

Add native Anthropic Claude support as a first-class LLM provider in Sure. Users will be able to select between OpenAI and Anthropic through a settings UI dropdown, configure their API keys, and use all AI features (chat, auto-categorization, merchant detection) with their chosen provider. The implementation follows existing Sure patterns: Provider abstraction, registry pattern, and settings model with ENV fallbacks.

## Domain Expertise

None (Rails backend work following established patterns in the Sure codebase)

## Milestones

- ✅ **[v1.0 Anthropic Support](milestones/v1.0-ROADMAP.md)** - Phases 1-9 + 9.1 (shipped 2026-01-10)
- ✅ **[v1.1 AI Auto-Categorization Triggers](milestones/v1.1-ROADMAP.md)** - Phases 10-15 (shipped 2026-01-10)
- ✅ **v1.2 Anthropic Feature Parity** - Phases 16-20 (shipped 2026-01-11)
- 🚧 **v1.3 Codebase Health** - Phases 24-29 (in progress, 2026-01-11)

## Phases

<details>
<summary>✅ v1.0 Anthropic Support (Phases 1-9 + 9.1) — SHIPPED 2026-01-10</summary>

See [milestones/v1.0-ROADMAP.md](milestones/v1.0-ROADMAP.md) for full details.

- [x] Phase 1: Foundation (3/3 plans) — completed 2026-01-09
- [x] Phase 2: Core Operations (3/3 plans) — completed 2026-01-10
- [x] Phase 3: Chat Support (4/4 plans) — completed 2026-01-09
- [x] Phase 4: Registry Integration (3/3 plans) — completed 2026-01-09
- [x] Phase 5: Settings Model (3/3 plans) — completed 2026-01-09
- [x] Phase 6: Settings UI (4/4 plans) — completed 2026-01-09
- [x] Phase 7: Langfuse Integration (1/1 plans) — completed 2026-01-10
- [x] Phase 8: Validation & Testing (3/3 plans) — completed 2026-01-10
- [x] Phase 9: Resolve Anthropic Issues (1/1 plans) — completed 2026-01-10
- [x] Phase 9.1: Fix get_transactions function tool (1/1 plans) — completed 2026-01-10 (INSERTED)

</details>

<details>
<summary>✅ v1.1 AI Auto-Categorization Triggers (Phases 10-15) — SHIPPED 2026-01-10</summary>

See [milestones/v1.1-ROADMAP.md](milestones/v1.1-ROADMAP.md) for full details.

- [x] Phase 10: Settings & Config (1/1 plans) — completed 2026-01-10
- [x] Phase 11: Import Triggers (4/4 plans) — completed 2026-01-10
- [x] Phase 12: Transaction UI Actions (3/3 plans) — completed 2026-01-10
- [x] Phase 13: Testing & Docs (4/4 plans) — completed 2026-01-10
- [x] Phase 14: Manual Testing (1/1 plans) — completed 2026-01-10
- [x] Phase 14.1: Fix AI Categorize Route (1/1 plans) — completed 2026-01-10 (INSERTED)
- [x] Phase 14.2: Fix Auto-Categorize Page Labels (1/1 plans) — completed 2026-01-10 (INSERTED)
- [x] Phase 15: Anthropic Model Autopopulate (1/1 plans) — completed 2026-01-10

</details>

<details>
<summary>✅ v1.2 Anthropic Feature Parity (Phases 16-18, 20) — SHIPPED 2026-01-11</summary>

See [milestones/v1.2-ROADMAP.md](milestones/v1.2-ROADMAP.md) for full details.

- [x] Phase 16: Real Streaming Support (1/1 plans) — completed 2026-01-10
- [x] Phase 17: Auto-Categorization Test Coverage (1/1 plans) — completed 2026-01-10
- [x] Phase 18: Fuzzy Category & Merchant Matching (1/1 plans) — completed 2026-01-11
- [x] Phase 20: Extract UsageRecorder Concern (1/1 plans) — completed 2026-01-11

</details>

---

### 🚧 v1.3 Codebase Health (In Progress)

**Milestone Goal:** Reduce technical debt and fix known bugs to establish clean patterns for future feature work. Focuses on DRY-ing up duplicated code, improving error handling, and enhancing AI categorization accuracy.

#### Phase 24: Env Example Updates

**Goal**: Add missing ANTHROPIC_* environment variable entries to .env.example
**Depends on**: v1.2 complete
**Research**: Unlikely (simple file update)
**Plans**: TBD

Plans:
- [ ] 24-01: Add ANTHROPIC_API_KEY and ANTHROPIC_MODEL to .env.example

#### Phase 25: Extract JSON Parser

**Goal**: Extract duplicated `parse_json_flexibly` method to shared concern across 4 provider files
**Depends on**: Phase 24
**Research**: Unlikely (following existing UsageRecorder pattern)
**Plans**: TBD

Plans:
- [ ] 25-01: Create Provider::Concerns::JsonParser with parse_json_flexibly method

#### Phase 26: Extract Thinking Tags

**Goal**: Extract duplicated `strip_thinking_tags` method to shared concern across 4 provider files
**Depends on**: Phase 25
**Research**: Unlikely (following JsonParser pattern)
**Plans**: TBD

Plans:
- [ ] 26-01: Add strip_thinking_tags to JsonParser concern

#### Phase 27: Simplify JSON Parsing

**Goal**: Break down 85-line complex JSON parsing method into smaller helper methods
**Depends on**: Phase 26
**Research**: Unlikely (code refactoring)
**Plans**: TBD

Plans:
- [ ] 27-01: Refactor parse_json_flexibly with helper methods and unit tests

#### Phase 28: Standardize Error Handling

**Goal**: Standardize error handling patterns across auto-categorizer and auto-merchant-detector
**Depends on**: Phase 27
**Research**: Unlikely (following existing error patterns)
**Plans**: TBD

Plans:
- [ ] 28-01: Implement consistent error handling across AI providers

#### Phase 29: Improve Categorization Prompts

**Goal**: Add few-shot examples to prompts to reduce >50% null categorization results
**Depends on**: Phase 28
**Research**: Unlikely (prompt engineering)
**Plans**: TBD

Plans:
- [ ] 29-01: Enhance prompts with few-shot examples and validate accuracy improvement

---

## v1.4 Future — AI Observability (Planned)

**Deferred Features:**
- Categorization feedback loop (LearnedPattern integration)
- Evaluation framework automation (manual runner execution)
- AI cost monitoring (DB + ENV hybrid, hard/soft limits)

---

## Archived Phase Details (v1.0)

### Phase 1: Foundation
**Goal**: Add Anthropic gem and create Provider::Anthropic class with basic structure
**Depends on**: Nothing (first phase)
**Research**: Likely (external gem integration)
**Research topics**: Anthropic Ruby gem API, Ruby version compatibility, authentication patterns
**Plans**: 3 plans

Plans:
- [x] 01-01: Add anthropic gem to Gemfile and bundle
- [x] 01-02: Create Provider::Anthropic class skeleton inheriting from Provider
- [ ] 01-03: Implement client initialization and error handling

### Phase 2: Core Operations
**Goal**: Implement auto_categorize and auto_detect_merchants with Anthropic
**Depends on**: Phase 1
**Research**: Likely (new API)
**Research topics**: Anthropic Messages API, tool/function calling format, JSON mode for structured outputs
**Plans**: 3 plans

Plans:
- [x] 02-01: Foundation - Add Anthropic gem and create Provider::Anthropic class skeleton
- [x] 02-02: Implement AutoCategorizer using Anthropic Messages API with structured outputs
- [x] 02-03: Implement auto_detect_merchants method using Anthropic Messages API

**Status**: Complete (2026-01-10)

### Phase 3: Chat Support
**Goal**: Implement chat_response with Anthropic including function/tool calling
**Depends on**: Phase 2
**Research**: Likely (complex integration)
**Research topics**: Anthropic streaming vs non-streaming, Claude tool calling format
**Plans**: 4 plans

Plans:
- [x] 03-01: Implement basic chat_response without tools
- [x] 03-02: Add tool/function calling support for chat
- [x] 03-03: Handle function results and multi-turn conversations
- [x] 03-04: Add streaming support (deferred for future work)

**Status**: Complete (2026-01-09)

### Phase 4: Registry Integration
**Goal**: Register Anthropic in provider registry and add cost tracking
**Depends on**: Phase 3
**Research**: Unlikely (internal patterns)
**Plans**: 3 plans

Plans:
- [x] 04-01: Add anthropic method to Provider::Registry
- [x] 04-02: Add anthropic to LLM concept available providers
- [x] 04-03: Add Anthropic model pricing to LlmUsage.calculate_cost

**Status**: Complete (2026-01-09)

### Phase 5: Settings Model
**Goal**: Add Anthropic settings fields with ENV fallbacks
**Depends on**: Phase 4
**Research**: Unlikely (established patterns)
**Plans**: 3 plans

Plans:
- [x] 05-01: Add anthropic_access_token and anthropic_model fields to Setting
- [x] 05-02: Add llm_provider field for provider selection (openai/anthropic)
- [x] 05-03: Add validation for Anthropic configuration

**Status**: Complete (2026-01-09)

### Phase 6: Settings UI
**Goal**: Build provider selector dropdown and Anthropic configuration form
**Depends on**: Phase 5
**Research**: Unlikely (following existing patterns)
**Plans**: 4 plans

Plans:
- [x] 06-01: Add provider selector dropdown to self-hosting settings
- [x] 06-02: Add Anthropic API key and model input fields
- [x] 06-03: Show/hide fields based on selected provider
- [x] 06-04: Add configuration validation and error messages

**Status**: Complete (2026-01-09) - All 4 plans finished

### Phase 7: Langfuse Integration
**Goal**: Ensure observability tracing works for Anthropic requests
**Depends on**: Phase 3
**Research**: Likely (observability integration)
**Research topics**: Langfuse SDK compatibility, trace format for Anthropic
**Plans**: 1 plan (consolidated from 2)

Plans:
- [x] 07-01: Adapt Langfuse tracing for Anthropic requests (VERIFICATION - already implemented in Phases 02-03)

**Status**: Complete (2026-01-10) - Verification confirmed Langfuse integration was already implemented correctly. No code changes needed.

### Phase 8: Validation & Testing
**Goal**: Verify all features work and no OpenAI regressions
**Depends on**: Phase 7, Phase 6
**Research**: Unlikely (verification)
**Plans**: 3 plans

Plans:
- [x] 08-01: Test all AI features with Anthropic provider
- [x] 08-02: Test all AI features with OpenAI provider (regression check)
- [x] 08-03: Test provider switching and settings UI

**Status**: Complete (2026-01-10) - 3/3 plans complete

### Phase 9: Resolve Anthropic Issues
**Goal**: Fix any remaining bugs or integration issues discovered during testing
**Depends on**: Phase 8
**Research**: Unlikely (bug fixing)
**Plans**: 1 plan

Plans:
- [x] 9-01: Feature sweep and issue resolution

**Status**: Complete (2026-01-10)

**Details:**
Fixed VCR test environment issue with ANTHROPIC_BASE_URL proxy. Created ISSUES.md catalog. All tests passing (69 tests, 162 assertions).

### Phase 9.1: Fix get_transactions function tool (INSERTED)

**Goal**: Fix "unknown attribute 'page' for Transaction::Search" error in AI chat function calling
**Depends on**: Phase 9
**Research**: Unlikely (bug fixing)
**Plans**: 1 plan

Plans:
- [x] 9.1-01: Handle symbol-keyed params from Anthropic in GetTransactions#call

**Status**: Complete (2026-01-10) - Fixed params.except to handle both string and symbol keys for order/page, ensuring compatibility with both OpenAI and Anthropic providers.

**Details:**
The AI chat was failing when calling the `get_transactions` function because Anthropic Claude passes `page` and `order` with symbol keys (not string keys like OpenAI). Fixed by updating `params.except("order", "page")` to `params.except("order", "page", :order, :page)` and using fallback pattern for params access.

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Foundation | v1.0 | 3/3 | Complete | 2026-01-09 |
| 2. Core Operations | v1.0 | 3/3 | Complete | 2026-01-10 |
| 3. Chat Support | v1.0 | 4/4 | Complete | 2026-01-09 |
| 4. Registry Integration | v1.0 | 3/3 | Complete | 2026-01-09 |
| 5. Settings Model | v1.0 | 3/3 | Complete | 2026-01-09 |
| 6. Settings UI | v1.0 | 4/4 | Complete | 2026-01-09 |
| 7. Langfuse Integration | v1.0 | 1/1 | Complete | 2026-01-10 |
| 8. Validation & Testing | v1.0 | 3/3 | Complete | 2026-01-10 |
| 9. Resolve Anthropic Issues | v1.0 | 1/1 | Complete | 2026-01-10 |
| 9.1. Fix get_transactions function tool | v1.0 | 1/1 | Complete | 2026-01-10 | (INSERTED)
| 10. Settings & Config | v1.1 | 1/1 | Complete | 2026-01-10 |
| 11. Import Triggers | v1.1 | 4/4 | Complete | 2026-01-10 |
| 12. Transaction UI Actions | v1.1 | 3/3 | Complete | 2026-01-10 |
| 13. Testing & Docs | v1.1 | 4/4 | Complete | 2026-01-10 |
| 14. Manual Testing | v1.1 | 1/1 | Complete | 2026-01-10 |
| 14.1. Fix AI Categorize Route | v1.1 | 1/1 | Complete | 2026-01-10 | (INSERTED) |
| 14.2. Fix Auto-Categorize Page Labels | v1.1 | 1/1 | Complete | 2026-01-10 | (INSERTED) |
| 15. Anthropic Model Autopopulate | v1.1 | 1/1 | Complete | 2026-01-10 |
| 16. Real Streaming Support | v1.2 | 1/1 | Complete | 2026-01-10 |
| 17. Auto-Categorization Test Coverage | v1.2 | 1/1 | Complete | 2026-01-10 |
| 18. Fuzzy Category & Merchant Matching | v1.2 | 1/1 | Complete | 2026-01-11 |
| 20. Extract UsageRecorder Concern | v1.2 | 1/1 | Complete | 2026-01-11 |
| 24. Env Example Updates | v1.3 | 0/? | Not started | — |
| 25. Extract JSON Parser | v1.3 | 0/? | Not started | — |
| 26. Extract Thinking Tags | v1.3 | 0/? | Not started | — |
| 27. Simplify JSON Parsing | v1.3 | 0/? | Not started | — |
| 28. Standardize Error Handling | v1.3 | 0/? | Not started | — |
| 29. Improve Categorization Prompts | v1.3 | 0/? | Not started | — |
