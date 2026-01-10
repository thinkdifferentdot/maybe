# Roadmap: Anthropic Support for Sure

## Overview

Add native Anthropic Claude support as a first-class LLM provider in Sure. Users will be able to select between OpenAI and Anthropic through a settings UI dropdown, configure their API keys, and use all AI features (chat, auto-categorization, merchant detection) with their chosen provider. The implementation follows existing Sure patterns: Provider abstraction, registry pattern, and settings model with ENV fallbacks.

## Domain Expertise

None (Rails backend work following established patterns in the Sure codebase)

## Milestones

- ✅ **[v1.0 Anthropic Support](milestones/v1.0-ROADMAP.md)** - Phases 1-9 + 9.1 (shipped 2026-01-10)
- ✅ **[v1.1 AI Auto-Categorization Triggers](milestones/v1.1-ROADMAP.md)** - Phases 10-14 (shipped 2026-01-10)

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

### 📋 v1.1 AI Auto-Categorization Triggers (Planned)

**Milestone Goal:** Add multiple trigger points for AI auto-categorization beyond just Rules - import flow, individual/bulk UI actions, and sync provider integration (especially Lunch Flow).

#### Phase 10: Settings & Config

**Goal**: Add user preferences for auto-categorization behavior and cost controls
**Depends on**: v1.0 complete
**Research**: Unlikely (existing Settings patterns)
**Plans**: 1 plan
- [x] 10-01: Add AI trigger settings to Settings model and UI (2026-01-10)

#### Phase 11: Import Triggers

**Goal**: Add AI categorization to CSV import and general sync jobs (Lunch Flow)
**Depends on**: None (parallel with 10, 12)
**Research**: Complete
**Plans**: 4 plans
- [x] 11-01: Add LearnedPattern model and matcher for AI categorization (2026-01-10)
- [x] 11-02: Add AI categorization trigger to CSV import (2026-01-10)
- [x] 11-03: Add AI categorization trigger to Lunchflow sync (2026-01-10)
- [x] 11-04: Bulk review workflow (2026-01-10)

**Status**: Complete (4/4 plans complete - 2026-01-10)

#### Phase 12: Transaction UI Actions

**Goal**: Add individual and bulk "AI categorize" buttons to transaction UI
**Depends on**: None (parallel with 10, 11)
**Research**: Unlikely (existing Hotwire/UI patterns)
**Plans**: 3 plans
- [x] 12-01: Backend Provider Selection & Confidence (2026-01-10)
- [x] 12-02: Individual AI categorize button in UI (2026-01-10)
- [x] 12-03: Bulk AI categorize workflow (2026-01-10)

**Status**: Complete (3/3 plans complete - 2026-01-10)

#### Phase 13: Testing & Docs

**Goal**: Verify all new trigger paths work correctly and document features
**Depends on**: Phases 10, 11, 12
**Research**: Unlikely (verification)
**Plans**: 4 plans
- [x] 13-01: LearnedPattern model and matcher tests (2026-01-10)
- [x] 13-02: AI categorization controllers tests (2026-01-10)
- [x] 13-03: Settings & confidence integration tests (2026-01-10)
- [x] 13-04: Full AI regression tests (2026-01-10)

**Status**: Complete (4/4 plans complete - 2026-01-10)

#### Phase 14: Manual Testing

**Goal**: User performs manual QA testing of all implemented v1.1 features
**Depends on**: Phase 13
**Research**: Unlikely (manual testing)
**Plans**: 1 plan
- [x] 14-01: Manual testing checklist and verification (2026-01-10)

**Status**: Complete (1/1 plan complete - 2026-01-10)

### Phase 14.1: Fix AI Categorize Route (INSERTED)

**Goal**: Fix 404 error when clicking individual AI categorize button
**Depends on**: Phase 14
**Research**: Unlikely (bug fixing)
**Plans**: 1 plan

Plans:
- [x] 14.1-01: Fix AI categorize route 404 error (2026-01-10)

**Status**: Complete (1/1 plan complete - 2026-01-10)

**Details:**
Urgent bug discovered during manual testing: POST to `/transactions/ai_categorization` returns 404. Root cause was view sending `transaction.id` instead of `entry.id` (different UUIDs in delegated_type pattern). Fixed by correcting the view and adding controller-level rescue_from for proper error handling.

### Phase 14.2: Fix Auto-Categorize Page Labels (INSERTED)

**Goal**: Fix missing option labels on auto-categorization settings page
**Depends on**: Phase 14.1
**Research**: Unlikely (UI bug fixing)
**Plans**: 1 plan

Plans:
- [x] 14.2-01: Add label support to DS::Toggle component (2026-01-10)

**Status**: Complete (1/1 plan complete - 2026-01-10)

**Details:**
Urgent bug discovered during manual testing: The auto-categorization settings page was not showing the option labels. Root cause was DS::Toggle component not accepting or displaying label parameter. Fixed by adding label attribute to component and updating template to render label text conditionally.

### Phase Details

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
