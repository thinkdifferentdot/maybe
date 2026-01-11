---
phase: 15-anthropic-model-autopopulate
plan: 01
subsystem: ui
tags: [stimulus, anthropic, api, select-dropdown, hotwire]

# Dependency graph
requires:
  - phase: 04-llm-chat-integration
    provides: anthropic settings UI, model configuration
provides:
  - dynamic Anthropic model selection via API
  - user-friendly dropdown with custom option fallback
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Backend proxy for external API (avoid exposing API keys to frontend)
    - Stimulus controller with loading states and error handling
    - CSRF token inclusion in fetch requests

key-files:
  created:
    - app/javascript/controllers/anthropic_model_select_controller.js
  modified:
    - config/routes.rb
    - app/controllers/settings/hostings_controller.rb
    - app/views/settings/hostings/_anthropic_settings.html.erb
    - config/locales/views/settings/hostings/en.yml
    - test/controllers/settings/hostings_controller_test.rb

key-decisions:
  - Used backend proxy pattern instead of direct API calls from frontend (security)
  - Filtered models to only include claude- prefixed models (system requirement)
  - Added "Custom..." option to preserve flexibility for future models
  - Used mocha stubs instead of VCR for tests (simpler, more reliable)

patterns-established:
  - "Model fetch API: GET endpoint returning {models: [...], error: \"...\"}"
  - "Stimulus loading pattern: show spinner during fetch, populate on success, show error on failure"
  - "Custom option pattern: select dropdown with text input fallback for unlisted values"

issues-created: []

# Metrics
duration: 35min
completed: 2025-01-10
---

# Phase 15 Plan 1: Anthropic Model Autopopulate Summary

**Converted Anthropic model field from text input to select dropdown with dynamic model fetching from Anthropic API**

## Performance

- **Duration:** 35 min
- **Started:** 2025-01-10T12:00:00Z
- **Completed:** 2025-01-10T12:35:00Z
- **Tasks:** 5
- **Files modified:** 6

## Accomplishments

- Created `/settings/hosting/anthropic_models` backend endpoint that proxies requests to Anthropic's `/v1/models` API
- Implemented `anthropic-model-select` Stimulus controller for fetching models and managing selection UI
- Updated Anthropic settings view to use select dropdown with "Custom..." fallback for manual entry
- Added comprehensive locale strings for model selection, loading states, and error messages
- Added full test coverage for the models endpoint with mocked API responses

## Task Commits

Each task was committed atomically:

1. **Task 1: Create backend endpoint for Anthropic models** - `2b901021` (feat)
2. **Task 2: Create Stimulus controller for model fetching** - `8d6dd67e` (feat)
3. **Task 3: Update Anthropic settings view to use select dropdown** - `ed7fe4fe` (feat)
4. **Task 4: Update locale strings in en.yml** - `e1e6216f` (feat)
5. **Task 5: Add tests for models endpoint with VCR** - `417ca21e` (feat)

**Plan metadata:** [pending final metadata commit]

## Files Created/Modified

### Created
- `app/javascript/controllers/anthropic_model_select_controller.js` - Stimulus controller that fetches models on connect, populates select dropdown, manages custom option display, handles loading states and errors

### Modified
- `config/routes.rb` - Added `get :anthropic_models` route under `settings/hosting` resource
- `app/controllers/settings/hostings_controller.rb` - Added `anthropic_models` action that proxies to Anthropic API, filters for claude- models, handles errors gracefully, requires admin auth
- `app/views/settings/hostings/_anthropic_settings.html.erb` - Replaced text input with select dropdown controlled by `anthropic-model-select`, added loading spinner, custom input wrapper, error message display
- `config/locales/views/settings/hostings/en.yml` - Added translation keys for custom_model_option, custom_model_label, custom_model_help, models_loading, models_fetch_error_* variants
- `test/controllers/settings/hostings_controller_test.rb` - Added 6 new tests covering valid API key, no API key, invalid API key, ENV fallback, model filtering, and generic error handling

## Decisions Made

1. **Backend proxy pattern** - Chose to proxy API requests through backend instead of calling Anthropic directly from frontend. This avoids exposing API keys to browser and maintains consistent authentication.

2. **Model filtering** - Filter response to only include claude- prefixed models since that's what the system validates against. Non-claude models from the API response are silently excluded.

3. **"Custom..." option** - Added a "Custom..." option at the end of the dropdown that reveals a text input. This preserves flexibility for users who want to use models not yet in the API response or custom model names.

4. **Mocha stubs over VCR** - Initially planned to use VCR cassettes for API mocking, but switched to mocha stubs for simpler, more reliable tests that don't require actual API responses.

5. **Error class correction** - Discovered during implementation that Anthropic gem error classes are under `Anthropic::Errors::` namespace, not directly under `Anthropic::`. Updated rescue clauses accordingly.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed error class references**
- **Found during:** Task 5 (Adding tests)
- **Issue:** Controller used `Anthropic::NotFoundError` and `Anthropic::UnauthorizedError` but actual classes are `Anthropic::Errors::NotFoundError` and `Anthropic::Errors::AuthenticationError`
- **Fix:** Updated rescue clauses to use correct namespace `Anthropic::Errors::`
- **Files modified:** app/controllers/settings/hostings_controller.rb
- **Verification:** All tests pass with proper error handling
- **Committed in:** 417ca21e (Task 5 commit)

**2. [Rule 1 - Bug] Fixed locale key naming**
- **Found during:** Task 5 (Adding tests)
- **Issue:** Controller referenced `models_fetch_error` with interpolation but locale file only had specific variants
- **Fix:** Added generic `models_fetch_error` key with `%{error}` interpolation placeholder
- **Files modified:** config/locales/views/settings/hostings/en.yml
- **Verification:** Generic error message displays correctly with error details
- **Committed in:** 417ca21e (Task 5 commit)

### Deferred Enhancements

None.

---

**Total deviations:** 2 auto-fixed (2 bugs), 0 deferred
**Impact on plan:** Both auto-fixes were necessary for functionality. No scope creep.

## Issues Encountered

1. **VCR cassette complexity** - Initially tried to use VCR for API mocking but the cassette format was complex and sensitive to exact API key matching. Switched to mocha stubs which are simpler and more reliable for unit testing controller logic.

2. **Setting persistence in tests** - Tests were picking up values from previous test runs due to RailsSettings caching. Fixed by using `Setting.where(...).destroy_all` + `Setting.clear_cache` pattern and wrapping tests in `with_env_overrides` to control ENV variable fallback.

3. **Error class initialization** - Anthropic gem's `AuthenticationError` requires specific keyword arguments (url, status, headers, etc.). Had to construct the error object properly in tests.

## Next Phase Readiness

- Phase 15 complete
- Anthropic model selection is now user-friendly with automatic population
- No blockers or concerns
- Ready for next phase or milestone v1.1 final verification

---
*Phase: 15-anthropic-model-autopopulate*
*Completed: 2025-01-10*
