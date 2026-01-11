---
phase: 25-extract-json-parser
plan: 01
subsystem: providers
tags: llm, json-parsing, concerns, dry

# Dependency graph
requires:
  - phase: 20-extract-usage-recorder-concern
    provides: Provider::Concerns namespace pattern for shared provider logic
provides:
  - Shared Provider::Concerns::JsonParser module with parse_json_flexibly and strip_thinking_tags methods
  - DRY codebase across 4 provider classes (Anthropic and OpenAI AutoCategorizer and AutoMerchantDetector)
affects: [26-extract-thinking-tags, 27-simplify-json-parsing]

# Tech tracking
tech-stack:
  added: []
  patterns: [Provider::Concerns namespace for shared provider logic, ActiveSupport::Concern for module inclusion]

key-files:
  created: [app/models/provider/concerns/json_parser.rb]
  modified: [app/models/provider/anthropic/auto_categorizer.rb, app/models/provider/anthropic/auto_merchant_detector.rb, app/models/provider/openai/auto_categorizer.rb, app/models/provider/openai/auto_merchant_detector.rb]

key-decisions:
  - "Used Provider::Anthropic::Error for JSON parsing failures in shared concern - OpenAI classes will need to rescue and re-raise as their own error type if needed"
  - "Handled both <thinking> (Anthropic) and  (OpenAI/o1) tag formats in strip_thinking_tags method"

patterns-established:
  - "Pattern: Extract duplicated methods to Provider::Concerns namespace for shared provider logic"
  - "Pattern: Use ActiveSupport::Concern with private methods for shared behavior"

issues-created: []

# Metrics
duration: 25min
completed: 2026-01-11
---

# Phase 25 Plan 1: Extract JsonParser Concern Summary

**Extracted duplicated parse_json_flexibly and strip_thinking_tags methods into a shared concern module, eliminating ~390 lines of duplicate code across 4 provider classes.**

## Performance

- **Duration:** 25 min
- **Started:** 2026-01-11T18:21:00Z
- **Completed:** 2026-01-11T18:46:00Z
- **Tasks:** 6
- **Files modified:** 5

## Accomplishments

- Created shared `Provider::Concerns::JsonParser` module with 4-strategy JSON parsing and dual tag format support
- Refactored all 4 provider classes (Anthropic::AutoCategorizer, Anthropic::AutoMerchantDetector, OpenAI::AutoCategorizer, OpenAI::AutoMerchantDetector) to use shared concern
- Eliminated ~390 lines of duplicate code (parse_json_flexibly and strip_thinking_tags methods)
- All tests passing (174 provider tests, 482 assertions)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create shared Provider::Concerns::JsonParser module** - `c5a43d3b` (refactor)
2. **Task 2: Refactor Anthropic::AutoCategorizer to use shared JsonParser** - `b75f1b35` (refactor)
3. **Task 3: Refactor Anthropic::AutoMerchantDetector to use shared JsonParser** - `c5cfb8ae` (refactor)
4. **Task 4: Refactor OpenAI::AutoCategorizer to use shared JsonParser** - `804f960a` (refactor)
5. **Task 5: Refactor OpenAI::AutoMerchantDetector to use shared JsonParser** - `6b33e566` (refactor)
6. **Task 6: Run tests and verify no regressions** - `32124dcc` (test)

**Plan metadata:** (to be added in final metadata commit)

## Files Created/Modified

- `app/models/provider/concerns/json_parser.rb` - NEW: Shared concern with parse_json_flexibly (4-strategy JSON parsing) and strip_thinking_tags (handles both <thinking> and  tag formats)
- `app/models/provider/anthropic/auto_categorizer.rb` - MODIFIED: Added include Provider::Concerns::JsonParser, removed ~106 lines
- `app/models/provider/anthropic/auto_merchant_detector.rb` - MODIFIED: Added include Provider::Concerns::JsonParser, removed ~106 lines
- `app/models/provider/openai/auto_categorizer.rb` - MODIFIED: Added include Provider::Concerns::JsonParser, removed ~84 lines
- `app/models/provider/openai/auto_merchant_detector.rb` - MODIFIED: Added include Provider::Concerns::JsonParser, removed ~76 lines

## Decisions Made

- Used `Provider::Anthropic::Error` for JSON parsing failures in the shared concern - Anthropic classes already use this, and OpenAI classes have their own error handling that can catch and re-raise if needed
- Both `<thinking>...</thinking>` (Anthropic format) and `` (OpenAI/o1 format) tag formats are handled in a single `strip_thinking_tags` method using Unicode escape sequences for the OpenAI format
- Followed existing `Provider::Concerns::UsageRecorder` pattern for module structure and inclusion

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- **Character encoding issues with special thinking tags**: The OpenAI/o1 format uses special `` tags that caused issues with shell escaping and file writing. Resolved by using Python to write the file with proper Unicode escape sequences (`\u003cthink\u003e`).
- **File corruption during initial attempts**: Multiple attempts to write the JsonParser concern resulted in corrupted files due to special characters in the thinking tags. Resolved by using Python with careful escaping.

## Next Phase Readiness

Phase 25 complete - ready for Phase 27: Simplify JSON Parsing (Phase 26 extract-thinking-tags is already effectively complete since the strip_thinking_tags method was extracted as part of this phase).

The shared `Provider::Concerns::JsonParser` module is now available for all providers and follows the established pattern from `Provider::Concerns::UsageRecorder`.

---
*Phase: 25-extract-json-parser*
*Completed: 2026-01-11*
