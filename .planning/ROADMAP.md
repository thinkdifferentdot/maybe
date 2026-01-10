# Roadmap: Anthropic Support for Sure

## Overview

Add native Anthropic Claude support as a first-class LLM provider in Sure. Users will be able to select between OpenAI and Anthropic through a settings UI dropdown, configure their API keys, and use all AI features (chat, auto-categorization, merchant detection) with their chosen provider. The implementation follows existing Sure patterns: Provider abstraction, registry pattern, and settings model with ENV fallbacks.

## Domain Expertise

None (Rails backend work following established patterns in the Sure codebase)

## Phases

- [ ] **Phase 1: Foundation** - Add Anthropic gem and create Provider::Anthropic class skeleton
- [ ] **Phase 2: Core Operations** - Implement auto_categorize and auto_detect_merchants for Anthropic
- [ ] **Phase 3: Chat Support** - Implement chat_response with Anthropic (including function/tool calling)
- [ ] **Phase 4: Registry Integration** - Register Anthropic in provider registry and add LlmUsage pricing
- [ ] **Phase 5: Settings Model** - Add Anthropic settings fields (API key, model, provider selection)
- [ ] **Phase 6: Settings UI** - Build provider selector dropdown and configuration form
- [ ] **Phase 7: Langfuse Integration** - Ensure observability tracing works for Anthropic
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
- [ ] 01-02: Create Provider::Anthropic class skeleton inheriting from Provider
- [ ] 01-03: Implement client initialization and error handling

### Phase 2: Core Operations
**Goal**: Implement auto_categorize and auto_detect_merchants with Anthropic
**Depends on**: Phase 1
**Research**: Likely (new API)
**Research topics**: Anthropic Messages API, tool/function calling format, JSON mode for structured outputs
**Plans**: 3 plans

Plans:
- [ ] 02-01: Implement auto_categorize method using Anthropic Messages API
- [ ] 02-02: Implement auto_detect_merchants method using Anthropic Messages API
- [ ] 02-03: Handle JSON responses and error cases for both operations

### Phase 3: Chat Support
**Goal**: Implement chat_response with Anthropic including function/tool calling
**Depends on**: Phase 2
**Research**: Likely (complex integration)
**Research topics**: Anthropic streaming vs non-streaming, Claude tool calling format
**Plans**: 4 plans

Plans:
- [ ] 03-01: Implement basic chat_response without tools
- [ ] 03-02: Add tool/function calling support for chat
- [ ] 03-03: Handle function results and multi-turn conversations
- [ ] 03-04: Add streaming support (if feasible, otherwise defer)

### Phase 4: Registry Integration
**Goal**: Register Anthropic in provider registry and add cost tracking
**Depends on**: Phase 3
**Research**: Unlikely (internal patterns)
**Plans**: 3 plans

Plans:
- [ ] 04-01: Add anthropic method to Provider::Registry
- [ ] 04-02: Add anthropic to LLM concept available providers
- [ ] 04-03: Add Anthropic model pricing to LlmUsage.calculate_cost

### Phase 5: Settings Model
**Goal**: Add Anthropic settings fields with ENV fallbacks
**Depends on**: Phase 4
**Research**: Unlikely (established patterns)
**Plans**: 3 plans

Plans:
- [ ] 05-01: Add anthropic_access_token and anthropic_model fields to Setting
- [ ] 05-02: Add llm_provider field for provider selection (openai/anthropic)
- [ ] 05-03: Add validation for Anthropic configuration

### Phase 6: Settings UI
**Goal**: Build provider selector dropdown and Anthropic configuration form
**Depends on**: Phase 5
**Research**: Unlikely (following existing patterns)
**Plans**: 4 plans

Plans:
- [ ] 06-01: Add provider selector dropdown to self-hosting settings
- [ ] 06-02: Add Anthropic API key and model input fields
- [ ] 06-03: Show/hide fields based on selected provider
- [ ] 06-04: Add configuration validation and error messages

### Phase 7: Langfuse Integration
**Goal**: Ensure observability tracing works for Anthropic requests
**Depends on**: Phase 3
**Research**: Likely (observability integration)
**Research topics**: Langfuse SDK compatibility, trace format for Anthropic
**Plans**: 2 plans

Plans:
- [ ] 07-01: Adapt Langfuse tracing for Anthropic requests
- [ ] 07-02: Verify token usage and cost tracking in Langfuse

### Phase 8: Validation & Testing
**Goal**: Verify all features work and no OpenAI regressions
**Depends on**: Phase 7, Phase 6
**Research**: Unlikely (verification)
**Plans**: 3 plans

Plans:
- [ ] 08-01: Test all AI features with Anthropic provider
- [ ] 08-02: Test all AI features with OpenAI provider (regression check)
- [ ] 08-03: Test provider switching and settings UI

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 1/3 | In progress | 2025-01-09 |
| 2. Core Operations | 0/3 | Not started | - |
| 3. Chat Support | 0/4 | Not started | - |
| 4. Registry Integration | 0/3 | Not started | - |
| 5. Settings Model | 0/3 | Not started | - |
| 6. Settings UI | 0/4 | Not started | - |
| 7. Langfuse Integration | 0/2 | Not started | - |
| 8. Validation & Testing | 0/3 | Not started | - |
