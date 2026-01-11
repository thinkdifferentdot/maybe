---
phase: 28-standardize-error-handling
plan: 01
subsystem: ai-providers
tags: [anthropic, openai, error-handling, langfuse, faraday]

# Dependency graph
requires:
  - phase: 25-extract-json-parser
    provides: Provider::Concerns namespace pattern
  - phase: 20-extract-usage-recorder-concern
    provides: ActiveSupport::Concern pattern for provider modules
provides:
  - Provider::Concerns::ErrorHandler module with standardized error handling
  - Consistent error messages across all AI provider classes
  - Langfuse span error logging with level: "ERROR"
affects: [any future AI provider integrations]

# Tech tracking
tech-stack:
  added: []
  patterns: [with_anthropic_error_handler, with_openai_error_handler, error translation to Provider::*::Error]

key-files:
  created: [app/models/provider/concerns/error_handler.rb]
  modified: [
    app/models/provider/anthropic/auto_categorizer.rb,
    app/models/provider/anthropic/auto_merchant_detector.rb,
    app/models/provider/openai/auto_categorizer.rb,
    app/models/provider/openai/auto_merchant_detector.rb
  ]

key-decisions:
  - "ErrorHandler provides with_anthropic_error_handler and with_openai_error_handler wrapper methods"
  - "OpenAI Faraday::BadRequestError fallback logic remains inline (specific to JSON mode retry)"
  - "Error messages are descriptive and include original error context"
  - "All errors logged to Langfuse spans with level: ERROR"

patterns-established:
  - "Provider::Concerns pattern: Extract shared provider behavior to concerns"
  - "Error handler wrapper pattern: with_provider_error_handler(span:, operation:) { }"
  - "Span error logging: span&.end(output: { error: ... }, level: 'ERROR')"

issues-created: []

# Metrics
duration: 15min
completed: 2026-01-11T19:32:30Z
---

# Phase 28 Plan 1: Standardize Error Handling Summary

**Created shared Provider::Concerns::ErrorHandler module and refactored all 4 provider classes to use consistent error handling patterns.**

## Performance

- **Duration:** 15 min
- **Started:** 2026-01-11T19:17:00Z
- **Completed:** 2026-01-11T19:32:30Z
- **Tasks:** 6
- **Files modified:** 5

## Accomplishments
- Created shared Provider::Concerns::ErrorHandler with provider-specific error translation
- Refactored Anthropic::AutoCategorizer to use ErrorHandler (improved error specificity)
- Refactored Anthropic::AutoMerchantDetector to use ErrorHandler (simplified from 22 lines to wrapper)
- Refactored OpenAI::AutoCategorizer to use ErrorHandler
- Refactored OpenAI::AutoMerchantDetector to use ErrorHandler
- All 210 provider tests passing with no regressions

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Provider::Concerns::ErrorHandler module** - `5fb7eb5b` (feat)
2. **Task 2: Refactor Anthropic::AutoCategorizer to use ErrorHandler** - `648ba856` (refactor)
3. **Task 3: Update Anthropic::AutoMerchantDetector to use ErrorHandler** - `61c3c1ac` (refactor)
4. **Task 4: Refactor OpenAI::AutoCategorizer to use ErrorHandler** - `f6a9177d` (refactor)
5. **Task 5: Refactor OpenAI::AutoMerchantDetector to use ErrorHandler** - `06f69794` (refactor)
6. **Task 6: Run tests and verify no regressions** - (verified 210 tests passing)

**Plan metadata:** (docs commit to follow)

_Note: Each task was committed immediately after completion._

## Files Created/Modified
- `app/models/provider/concerns/error_handler.rb` - NEW: Shared concern with standardized error handling for Anthropic and OpenAI providers
- `app/models/provider/anthropic/auto_categorizer.rb` - MODIFIED: Uses ErrorHandler, improved error specificity from generic rescue to comprehensive Anthropic SDK error handling
- `app/models/provider/anthropic/auto_merchant_detector.rb` - MODIFIED: Refactored to use ErrorHandler, reduced 22 lines of rescue blocks to wrapper call
- `app/models/provider/openai/auto_categorizer.rb` - MODIFIED: Uses ErrorHandler, preserved Faraday::BadRequestError fallback logic
- `app/models/provider/openai/auto_merchant_detector.rb` - MODIFIED: Uses ErrorHandler, preserved Faraday::BadRequestError fallback logic

## Decisions Made
- ErrorHandler provides `with_anthropic_error_handler(span:, operation:)` and `with_openai_error_handler(span:, operation:)` wrapper methods
- OpenAI Faraday::BadRequestError fallback logic remains inline (specific to JSON mode retry logic at provider level)
- Error messages are descriptive and include original error context for debugging
- All errors logged to Langfuse spans with `level: "ERROR"` for observability

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None - all refactoring was straightforward and tests passed on first run.

## Next Phase Readiness

Phase 28 complete - ready for Phase 29: Improve Categorization Prompts.

Error handling is now consistent across all AI provider classes. The ErrorHandler concern follows the established pattern from JsonParser and UsageRecorder, making it easy to extend to future provider integrations.

---
*Phase: 28-standardize-error-handling*
*Completed: 2026-01-11*
