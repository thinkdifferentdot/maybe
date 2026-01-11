---
phase: 20-extract-usage-recorder-concern
plan: 01
subsystem: api
tags: llm, usage-tracking, concerns, refactoring

# Dependency graph
requires:
  - phase: 19-flexible-json-parsing
    provides: parse_json_flexibly pattern for Anthropic providers
provides:
  - Shared Provider::Concerns::UsageRecorder module for all LLM providers
  - DRY usage recording code across OpenAI and Anthropic providers
  - Format-detecting extract_tokens helper for Hash and BaseModel usage data
affects: []
tech-stack:
  added: []
  patterns: shared concern module, format detection via respond_to?
key-files:
  created:
    - app/models/provider/concerns/usage_recorder.rb
  modified:
    - app/models/provider/anthropic/auto_categorizer.rb
    - app/models/provider/anthropic/auto_merchant_detector.rb
    - app/models/provider/openai/concerns/usage_recorder.rb
key-decisions:
  - Used top-level Provider::Concerns namespace for maximum portability
  - Format detection via respond_to?(:input_tokens) handles both formats
  - Preserved OpenAI concern as backward-compatible alias
patterns-established:
  - "Concern pattern: Shared behavior module at top-level namespace"
  - "Format detection: Duck-typing via respond_to? for provider-agnostic handling"
issues-created: []

# Metrics
duration: 8 min
completed: 2026-01-11
---

# Phase 20 Plan 1: Extract UsageRecorder Concern Summary

**Extracted duplicated usage recording code into a shared concern module, eliminating ~160 lines of duplicate code across provider classes while preserving backward compatibility.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-01-11T14:40:00Z
- **Completed:** 2026-01-11T14:48:00Z
- **Tasks:** 5
- **Files modified:** 4

## Accomplishments

- Created `Provider::Concerns::UsageRecorder` shared module (112 lines) with format-detecting `extract_tokens` helper
- Refactored `Provider::Anthropic::AutoCategorizer` to include shared concern, removed 34-line duplicate method
- Refactored `Provider::Anthropic::AutoMerchantDetector` to include shared concern, removed 34-line duplicate method
- Converted `Provider::Openai::Concerns::UsageRecorder` to backward-compatible alias (97 lines → 7 lines)
- All 26 provider tests passing with no regressions

## Task Commits

Each task was committed atomically:

1. **Task 1: Create shared Provider::Concerns::UsageRecorder module** - `50898422` (feat)
2. **Task 2: Refactor AutoCategorizer to use shared concern** - `7b80ff80` (refactor)
3. **Task 3: Refactor AutoMerchantDetector to use shared concern** - `9637f303` (refactor)
4. **Task 4: Alias OpenAI concern to shared concern** - `8d7841d5` (refactor)
5. **Task 5: Run tests and verify no regressions** - `bfb79051` (test)

**Plan metadata:** Next commit will include SUMMARY + STATE + ROADMAP

_Note: Refactoring tasks each eliminate duplicate code while preserving behavior_

## Files Created/Modified

- `app/models/provider/concerns/usage_recorder.rb` - NEW: Shared concern with record_usage, extract_tokens, record_usage_error, extract_http_status_code
- `app/models/provider/anthropic/auto_categorizer.rb` - MODIFIED: Added include, removed duplicate record_usage method (-34 lines)
- `app/models/provider/anthropic/auto_merchant_detector.rb` - MODIFIED: Added include, removed duplicate record_usage method (-34 lines)
- `app/models/provider/openai/concerns/usage_recorder.rb` - MODIFIED: Converted to alias for backward compatibility (-90 lines)

**Net change: -158 lines of duplicate code eliminated**

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None — straightforward refactoring following existing patterns.

## Next Phase Readiness

✅ **v1.2 Milestone COMPLETE!**

Phase 20 complete — this was the final phase of v1.2: Anthropic Feature Parity.

All 5 phases of v1.2 are now complete:
- Phase 16: Real Streaming Support ✅
- Phase 17: Auto-Categorization Test Coverage ✅
- Phase 18: Fuzzy Category & Merchant Matching ✅
- Phase 19: Flexible JSON Parsing ✅
- Phase 20: Extract UsageRecorder Concern ✅

All usage recording code now centralized in a single concern module that:
- Handles both Hash (OpenAI) and BaseModel (Anthropic) formats automatically
- Provides error recording capability for all providers
- Maintains backward compatibility with existing OpenAI includes
- Is plug-and-play for future providers

---

*Phase: 20-extract-usage-recorder-concern*
*Completed: 2026-01-11*
