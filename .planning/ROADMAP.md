# Roadmap: Anthropic Support for Sure

## Overview

Add native Anthropic Claude support as a first-class LLM provider in Sure. Users will be able to select between OpenAI and Anthropic through a settings UI dropdown, configure their API keys, and use all AI features (chat, auto-categorization, merchant detection) with their chosen provider. The implementation follows existing Sure patterns: Provider abstraction, registry pattern, and settings model with ENV fallbacks.

## Domain Expertise

None (Rails backend work following established patterns in the Sure codebase)

## Milestones

- ✅ **[v1.0 Anthropic Support](milestones/v1.0-ROADMAP.md)** - Phases 1-9 + 9.1 (shipped 2026-01-10)
- ✅ **[v1.1 AI Auto-Categorization Triggers](milestones/v1.1-ROADMAP.md)** - Phases 10-15 (shipped 2026-01-10)
- 🚧 **v1.2 Anthropic Feature Parity** - Phases 16-21 (in progress, 2026-01-10)

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

### 🚧 v1.2 Anthropic Feature Parity (In Progress)

**Milestone Goal:** Achieve feature parity between OpenAI and Anthropic provider implementations. OpenAI has ~1,880 lines across 8 files vs Anthropic's ~1,034 lines across 5 files. Key gaps include real streaming, test coverage, fuzzy matching, flexible JSON parsing, and code organization improvements.

#### Phase 16: Real Streaming Support

**Goal**: Implement true streaming for Anthropic chat responses, matching OpenAI's streaming behavior
**Depends on**: Phase 15
**Research**: Likely (Anthropic streaming API patterns)
**Research topics**: Anthropic messages.stream API, stream.text.each helper, chunk types
**Status**: Complete (2026-01-10)

Plans:
- [x] 16-01: Create ChatStreamParser and update chat_response for streaming

#### Phase 17: Auto-Categorization Test Coverage

**Goal**: Add missing auto-categorization test to match OpenAI test coverage
**Depends on**: Phase 16
**Research**: Unlikely (test patterns established)
**Plans**: TBD

Plans:
- [ ] 17-01: Add auto_categorize test with VCR cassette (run /gsd:plan-phase 17 to break down)

#### Phase 18: Fuzzy Category & Merchant Matching

**Goal**: Add fuzzy name matching for better category/merchant normalization
**Depends on**: Phase 17
**Research**: Unlikely (porting existing patterns)
**Plans**: TBD

Plans:
- [ ] 18-01: Port fuzzy_name_match and find_fuzzy_category_match from OpenAI (run /gsd:plan-phase 18 to break down)

#### Phase 19: Flexible JSON Parsing

**Goal**: Handle LLM output quirks (thinking tags, unclosed markdown, multiple JSON formats)
**Depends on**: Phase 18
**Research**: Unlikely (porting existing patterns)
**Plans**: TBD

Plans:
- [ ] 19-01: Port parse_json_flexibly method from OpenAI (run /gsd:plan-phase 19 to break down)

#### Phase 20: Extract UsageRecorder Concern

**Goal**: DRY up usage recording code by extracting to a concern module (refactor)
**Depends on**: Phase 19
**Research**: Unlikely (code organization)
**Plans**: TBD

Plans:
- [ ] 20-01: Create concerns/usage_recorder and refactor auto-categorizer/merchant-detector (run /gsd:plan-phase 20 to break down)

#### Phase 21: Custom Provider Support

**Goal**: Allow Anthropic-compatible APIs (local models, proxies, custom endpoints)
**Depends on**: Phase 20
**Research**: Likely (Anthropic gem custom URL support)
**Research topics**: Anthropic Ruby gem custom base_url support, generic chat patterns
**Plans**: TBD

Plans:
- [ ] 21-01: Add custom provider support with base_url parameter (run /gsd:plan-phase 21 to break down)

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
| 17. Auto-Categorization Test Coverage | v1.2 | 0/? | Not started | — |
| 18. Fuzzy Category & Merchant Matching | v1.2 | 0/? | Not started | — |
| 19. Flexible JSON Parsing | v1.2 | 0/? | Not started | — |
| 20. Extract UsageRecorder Concern | v1.2 | 0/? | Not started | — |
| 21. Custom Provider Support | v1.2 | 0/? | Not started | — |
