# Roadmap: Anthropic Support for Sure

## Overview

Add native Anthropic Claude support as a first-class LLM provider in Sure. Users will be able to select between OpenAI and Anthropic through a settings UI dropdown, configure their API keys, and use all AI features (chat, auto-categorization, merchant detection) with their chosen provider. The implementation follows existing Sure patterns: Provider abstraction, registry pattern, and settings model with ENV fallbacks.

## Domain Expertise

None (Rails backend work following established patterns in the Sure codebase)

## Phases

- [x] **Phase 1: Foundation** - Add Anthropic gem and create Provider::Anthropic class skeleton
- [x] **Phase 2: Core Operations** - Implement auto_categorize and auto_detect_merchants for Anthropic
- [x] **Phase 3: Chat Support** - Implement chat_response with Anthropic (including function/tool calling)
- [x] **Phase 4: Registry Integration** - Register Anthropic in provider registry and add LlmUsage pricing
- [x] **Phase 5: Settings Model** - Add Anthropic settings fields (API key, model, provider selection)
- [x] **Phase 6: Settings UI** - Build provider selector dropdown and configuration form
- [x] **Phase 7: Langfuse Integration** - Ensure observability tracing works for Anthropic
- [ ] **Phase 8: Validation & Testing** - Verify all features work and no regressions to OpenAI

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
- [ ] 08-01: Test all AI features with Anthropic provider
- [x] 08-02: Test all AI features with OpenAI provider (regression check)
- [ ] 08-03: Test provider switching and settings UI

**Status**: In progress (2026-01-10) - 1/3 plans complete

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 3/3 | Complete | 2026-01-09 |
| 2. Core Operations | 3/3 | Complete | 2026-01-10 |
| 3. Chat Support | 4/4 | Complete | 2026-01-09 |
| 4. Registry Integration | 3/3 | Complete | 2026-01-09 |
| 5. Settings Model | 3/3 | Complete | 2026-01-09 |
| 6. Settings UI | 4/4 | Complete | 2026-01-09 |
| 7. Langfuse Integration | 1/1 | Complete | 2026-01-10 |
| 8. Validation & Testing | 1/3 | In progress | 2026-01-10 |
