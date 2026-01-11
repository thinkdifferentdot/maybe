# Anthropic Support for Sure

## What This Is

Add native Anthropic Claude support to Sure (self-hosted financial tracking app). Users will be able to use their Anthropic API key directly instead of OpenAI, with provider selection via a dropdown in the settings UI. Both providers are supported simultaneously—users choose which to use.

## Current State

**Shipped:** v1.3 Codebase Health (2026-01-11)

The v1.3 milestone focused on reducing technical debt and establishing clean patterns for future feature work. Eliminated ~450 lines of duplicate code through shared concerns (JsonParser, ErrorHandler, FewShotExamples). Standardized error handling across all AI providers. Implemented few-shot examples system to improve AI categorization accuracy. Added comprehensive test coverage (50+ new tests).

## Core Value

**Smooth UX configuration** — Users select their AI provider (OpenAI or Anthropic) through a settings dropdown and enter the corresponding API key. The system validates the configuration and uses the selected provider for all AI features (chat, auto-categorization, merchant detection).

## Requirements

### Validated

- ✓ Add Anthropic as a first-class LLM provider alongside OpenAI — v1.0
- ✓ Create `Provider::Anthropic` class following the same interface as `Provider::Openai` — v1.0
- ✓ Register Anthropic in the provider registry for LLM concept — v1.0
- ✓ Add settings fields for Anthropic API key and model selection — v1.0
- ✓ Implement provider selector UI in settings (dropdown to choose OpenAI/Anthropic) — v1.0
- ✓ Support all AI operations with Anthropic: chat_response, auto_categorize, auto_detect_merchants — v1.0
- ✓ Add Anthropic model pricing to `LlmUsage` for cost tracking — v1.0
- ✓ Ensure Langfuse tracing works for Anthropic requests — v1.0
- ✓ Real streaming support for Anthropic chat responses — v1.2
- ✓ Fuzzy category/merchant matching for Anthropic (feature parity with OpenAI) — v1.2
- ✓ Shared UsageRecorder concern for DRY code across providers — v1.2
- ✓ Shared JsonParser concern eliminating ~390 lines of duplicate code — v1.3
- ✓ Shared ErrorHandler concern with consistent error handling across all providers — v1.3
- ✓ FewShotExamples concern to improve AI categorization accuracy — v1.3
- ✓ Environment documentation complete (ANTHROPIC_* in .env.example) — v1.3

### Active

- [ ] Documentation updates — Update `docs/hosting/ai.md` to reflect Anthropic provider option

### Out of Scope

- **Multi-provider routing** — Using OpenAI for some features and Anthropic for others; users select one provider globally
- **Model comparison/testing tools** — Just make it work, not optimize model selection
- **Flexible JSON parsing** — Deferred to v1.3 technical debt work (Phase 19)

## Context

**Target codebase:** Sure (Rails app) at `/Users/andrewbewernick/GitHub/sure`

**Current AI architecture:**
- `Provider::Openai` (`app/models/provider/openai.rb`) — Uses `ruby-openai` gem v8.1.0
- `Provider::Anthropic` (`app/models/provider/anthropic.rb`) — Uses `anthropic` gem v1.16.3 (added in v1.0)
- `Provider::Registry` (`app/models/provider/registry.rb`) — Manages provider discovery for both `openai` and `anthropic` for LLM concept
- `Provider::Concerns::UsageRecorder` (`app/models/provider/concerns/usage_recorder.rb`) — Shared concern for usage recording (added in v1.2)
- `Provider::Anthropic::ChatStreamParser` (`app/models/provider/anthropic/chat_stream_parser.rb`) — Parses Anthropic streaming events (added in v1.2)
- `Setting` model (`app/models/setting.rb`) — Stores configuration with ENV fallbacks for both providers
- `LlmUsage` model — Tracks token usage and costs per model for both providers
- Langfuse integration for observability (works for both providers)

**Key patterns established:**
- Providers inherit from `Provider` base class and include `LlmConcept` module
- Implement `auto_categorize`, `auto_detect_merchants`, `chat_response` methods
- Use `with_provider_response` wrapper for error handling
- Support Langfuse tracing via `create_langfuse_trace` and `log_langfuse_generation`
- Record usage via shared `Provider::Concerns::UsageRecorder` (format-detecting for Hash/BaseModel)
- Anthropic-specific: ChatConfig/ChatParser pattern for API format conversion, token field mapping (input/output_tokens -> prompt/completion_tokens)
- Anthropic streaming: ChatStreamParser converts MessageStream events to ChatStreamChunk format
- Fuzzy matching: normalize_category_name applies exact → case-insensitive → fuzzy → raw fallback

**Technical notes:**
- Anthropic SDK returns BaseModel objects with symbol keys (not string keys like OpenAI)
- Anthropic requires `max_tokens` parameter (4096 default)
- Anthropic uses separate "system" parameter for instructions (not in messages array)
- Anthropic's tool calling format differs: "input_schema" not "parameters", "id" serves as both id and call_id
- Tool_result blocks must come FIRST in user message content array (Anthropic requirement)

## Constraints

- ✓ **Architecture match** — Must follow existing Sure patterns: Provider abstraction, registry pattern, settings model (validated in v1.0)
- ✓ **No breaking changes** — OpenAI support must continue working exactly as before (validated in v1.0: 56 OpenAI tests passing)
- ✓ **All AI features** — Chat, auto-categorization, and merchant detection must all work with Anthropic (validated in v1.0)
- ✓ **Settings UI** — Configuration through the web interface, not just environment variables (validated in v1.0)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Single provider selection (not multi-provider routing) | Simpler UX and implementation; users pick one provider for all AI features | ✓ Good — Working as designed in v1.0 |
| Add official `anthropic` gem to Gemfile | Native Ruby support is more reliable than OpenAI-compatible proxy approach | ✓ Good — gem version 1.16.3, Ruby 3.4.7 compatible |
| Follow OpenAI provider structure closely | Proven patterns, easier to maintain, consistent with existing code | ✓ Good — Provider::Anthropic follows same patterns |
| Use `claude-sonnet-4-5-20250929` as default model | Balanced model for categorization/merchant detection tasks | ✓ Good — Effective model for use cases |
| Use symbol keys for Anthropic BaseModel access | Anthropic SDK returns BaseModel with symbolized keys from to_h | ✓ Good — Fixed ChatParser and extract methods |
| System parameter for instructions (Anthropic) | Anthropic convention uses separate "system" parameter, not in messages array | ✓ Good — Follows Anthropic best practices |
| ANTHROPIC_API_KEY ENV variable name | Matches official gem convention | ✓ Good — Consistent with documentation |
| Default provider is "openai" | Backward compatibility for existing installations | ✓ Good — No breaking changes for existing users |
| Real streaming for Anthropic (v1.2) | Users expect progressive text output, not all-at-once responses | ✓ Good — ChatStreamParser handles all event types |
| Shared UsageRecorder concern (v1.2) | DRY principle — eliminate 160+ lines of duplicate code | ✓ Good — Format detection handles both Hash and BaseModel |
| Port fuzzy matching from OpenAI (v1.2) | Feature parity — Anthropic should match OpenAI's normalization capabilities | ✓ Good — Synonym and substring matching working |
| Shared JsonParser concern (v1.3) | DRY principle — eliminate 390+ lines of duplicate JSON parsing code | ✓ Good — 4-strategy parsing with dual tag format support |
| Shared ErrorHandler concern (v1.3) | Consistent error handling patterns across all providers | ✓ Good — Provider-specific error translation with Langfuse logging |
| Few-shot examples for categorization (v1.3) | Reduce >50% null categorization results by providing concrete examples | ✓ Pending — Two-tier system (static + dynamic) implemented |
| Simplify parse_json_flexibly (v1.3) | 85-line method too complex for maintainability | ✓ Good — Extracted 5 focused helper methods with unit tests |

---
*Last updated: 2026-01-11 after v1.3 milestone*
