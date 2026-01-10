# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2025-01-09)

**Core value:** Smooth UX configuration — Users select AI provider through settings dropdown
**Current focus:** Phase 8 — Validation & Testing

## Current Position

Phase: 10 of 13 (Settings & Config)
Plan: Not started
Status: Ready to plan
Last activity: 2026-01-10 — Milestone v1.1 created

Progress: ░░░░░░░░░░░░░░░░░░░░ 0% (0/? plans complete for v1.1)

**Note:** v1.0 (Anthropic Support) at 78% - Phases 8-9 remain to complete that milestone.

## Performance Metrics

**Velocity:**
- Total plans completed: 18
- Average duration: 4.4 min
- Total execution time: ~80 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1 (Foundation) | 3 | 9 min | 3 min |
| 2 (Core Operations) | 3 | 14 min | 4.7 min |
| 3 (Chat Support) | 4 | 17 min | 4.3 min |
| 4 (Registry Integration) | 1 | 3 min | 3 min |
| 5 (Settings Model) | 1 | 12 min | 12 min |
| 6 (Settings UI) | 3 | 8 min | 2.7 min |
| 7 (Langfuse Integration) | 1 | 5 min | 5 min |
| 8 (Validation & Testing) | 2 | 40 min | 20 min |

**Recent Trend:**
- Last 5 plans: 6-04 (Config Validation), 7-01 (Langfuse Verification), 8-02 (OpenAI Regression), 8-01 (Anthropic Tests)
- Trend: Phase 8 in progress, 1 plan remaining (08-03 Integration Smoke)

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- **Phase 1-01**: Used official anthropic gem (not community ruby-anthropic) for long-term support; Version constraint ~> 1.16.0 allows patch/bugfix updates but breaks on major/minor changes; Confirmed Ruby 3.4.7 compatibility (SDK requires 3.2+)
- **Phase 1-02**: DEFAULT_MODEL set to "claude-sonnet-4-5-20250929"; Model prefix matching uses start_with? for flexibility
- **Phase 2-01**: Client initialization pattern with private attr_reader; effective_model class method with ANTHROPIC_MODEL ENV fallback
- **Phase 2-02**: Used structured outputs beta (2025-11-13) for JSON schema compliance; Content extraction from response.content array (Anthropic-specific); Reused OpenAI's categorization prompts
- **Phase 2-03**: AutoMerchantDetector with Messages API; Merchant detection returns business_name and business_url (both nullable); Comprehensive Anthropic error handling (APIConnectionError, RateLimitError, etc.)
- **Phase 3-01**: ChatConfig/ChatParser pattern for API format conversion; Token field mapping: input_tokens -> prompt_tokens, output_tokens -> completion_tokens; System instructions via separate "system" parameter (Anthropic convention); max_tokens required (4096 default); Langfuse tracing with "anthropic.chat_response" name
- **Phase 3-02**: Anthropic uses "input_schema" not "parameters" for tool definitions; Anthropic's id serves as both id and call_id (unlike OpenAI); Anthropic's input is already a Hash (not JSON string); Parallel tool use supported (iterate all tool_use blocks)
- **Phase 3-03**: Tool_result blocks MUST come FIRST in user message content array (Anthropic requirement); Assistant message with tool_use blocks is reconstructed from function_results; Caller manages conversation history (no previous_response_id like OpenAI); ChatConfig.build_input handles full multi-turn conversation structure
- **Phase 4-01**: Registered Anthropic in Provider::Registry with cost tracking; Uses Setting method calls (not bracket notation) for consistency
- **Phase 5-01**: Used ANTHROPIC_API_KEY ENV (not ACCESS_TOKEN) to match official gem convention
- **Phase 5-02**: Provider selection is global (single llm_provider field, not per-feature)
- **Phase 5-03**: Simple validation for llm_provider using validate_llm_provider! method
- **Phase 6-01**: Provider selector dropdown follows existing pattern with styled_form_with; Auto-submit on blur for instant feedback
- **Phase 6-02**: Anthropic settings partial matches OpenAI structure exactly; ENV key is ANTHROPIC_API_KEY (not ACCESS_TOKEN) per Anthropic convention; Redaction placeholder "********" prevents accidental overwrite
- **Phase 6-03**: Provider visibility controller uses hidden class for show/hide; data-provider attributes on settings sections for targeting; Initial provider value from @llm_provider instance variable; Change event triggers immediate visibility update
- **Phase 6-04**: Anthropic config validation uses claude- prefix check; validate_anthropic_config! follows OpenAI pattern; Help text provides inline guidance; Placeholder shows valid model example
- **Phase 7-01**: Langfuse integration verified - was already implemented in Phases 02-03; No code changes needed; Token field mapping (input/output_tokens -> prompt/completion_tokens) confirmed correct
- **Phase 8-02**: OpenAI regression verified - 56 tests passing across 4 test files; LlmUsage test file created for comprehensive pricing coverage; No code changes needed (ideal outcome)
- **Phase 8-01**: Fixed ChatParser to use symbol keys (:id, :content, :type) - Anthropic SDK returns BaseModel with symbolized keys from to_h
- **Phase 8-01**: Fixed extract methods to check if parsed.is_a?(Array) before calling dig - API returns direct arrays in some cases
- **Phase 8-01**: Fixed test function_results format for Anthropic - must include name and arguments, not just call_id and output (Anthropic requires full conversation history)

### Deferred Issues

None yet.

### Roadmap Evolution

- **Phase 9 added**: Resolve Anthropic Issues (2026-01-10) - New phase to address any bugs or integration issues discovered during testing
- **Milestone v1.1 created**: AI Auto-Categorization Triggers (2026-01-10) - 4 phases (10-13) focused on adding import triggers, UI actions, and settings for AI categorization beyond Rules

### Blockers/Concerns

None yet.

## Session Continuity

Last session: 2026-01-10
Stopped at: Milestone v1.1 initialization
Resume file: None
