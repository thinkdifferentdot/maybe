# Roadmap: Anthropic Support for Sure

## Overview

Add native Anthropic Claude support as a first-class LLM provider in Sure. Users will be able to select between OpenAI and Anthropic through a settings UI dropdown, configure their API keys, and use all AI features (chat, auto-categorization, merchant detection) with their chosen provider. The implementation follows existing Sure patterns: Provider abstraction, registry pattern, and settings model with ENV fallbacks.

## Domain Expertise

None (Rails backend work following established patterns in the Sure codebase)

## Milestones

- 🚧 **v1.0 Anthropic Support** - Phases 1-9 (in progress, 78% complete)
- 📋 **v1.1 AI Auto-Categorization Triggers** - Phases 10-13 (planned)

## Phases

<details>
<summary>v1.0 Anthropic Support (Phases 1-9)</summary>

- [x] **Phase 1: Foundation** - Add Anthropic gem and create Provider::Anthropic class skeleton
- [x] **Phase 2: Core Operations** - Implement auto_categorize and auto_detect_merchants for Anthropic
- [x] **Phase 3: Chat Support** - Implement chat_response with Anthropic (including function/tool calling)
- [x] **Phase 4: Registry Integration** - Register Anthropic in provider registry and add LlmUsage pricing
- [x] **Phase 5: Settings Model** - Add Anthropic settings fields (API key, model, provider selection)
- [x] **Phase 6: Settings UI** - Build provider selector dropdown and configuration form
- [x] **Phase 7: Langfuse Integration** - Ensure observability tracing works for Anthropic
- [ ] **Phase 8: Validation & Testing** - Verify all features work and no regressions to OpenAI
- [ ] **Phase 9: Resolve Anthropic Issues** - Fix any remaining bugs or integration issues discovered during testing

</details>

### 📋 v1.1 AI Auto-Categorization Triggers (Planned)

**Milestone Goal:** Add multiple trigger points for AI auto-categorization beyond just Rules - import flow, individual/bulk UI actions, and sync provider integration (especially Lunch Flow).

#### Phase 10: Settings & Config

**Goal**: Add user preferences for auto-categorization behavior and cost controls
**Depends on**: v1.0 complete
**Research**: Unlikely (existing Settings patterns)
**Plans**: TBD

#### Phase 11: Import Triggers

**Goal**: Add AI categorization to CSV import and general sync jobs (Lunch Flow)
**Depends on**: None (parallel with 10, 12)
**Research**: Unlikely (existing ImportJob/SyncJob patterns)
**Plans**: TBD

#### Phase 12: Transaction UI Actions

**Goal**: Add individual and bulk "AI categorize" buttons to transaction UI
**Depends on**: None (parallel with 10, 11)
**Research**: Unlikely (existing Hotwire/UI patterns)
**Plans**: TBD

#### Phase 13: Testing & Docs

**Goal**: Verify all new trigger paths work correctly and document features
**Depends on**: Phases 10, 11, 12
**Research**: Unlikely (verification)
**Plans**: TBD

## Phase Details

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
- [ ] 08-03: Test provider switching and settings UI

**Status**: In progress (2026-01-10) - 2/3 plans complete

### Phase 9: Resolve Anthropic Issues
**Goal**: Fix any remaining bugs or integration issues discovered during testing
**Depends on**: Phase 8
**Research**: Unlikely (bug fixing)
**Plans**: TBD

Plans:
- [ ] TBD (run /gsd:plan-phase 9 to break down)

**Details:**
To be added during planning

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
| 8. Validation & Testing | v1.0 | 2/3 | In progress | 2026-01-10 |
| 9. Resolve Anthropic Issues | v1.0 | 0/0 | Not started | - |
| 10. Settings & Config | v1.1 | 0/? | Not started | - |
| 11. Import Triggers | v1.1 | 0/? | Not started | - |
| 12. Transaction UI Actions | v1.1 | 0/? | Not started | - |
| 13. Testing & Docs | v1.1 | 0/? | Not started | - |
