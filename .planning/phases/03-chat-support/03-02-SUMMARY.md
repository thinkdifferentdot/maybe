---
phase: 03-chat-support
plan: 02
subsystem: api
tags: anthropic, tools, function-calling, chat, tool-use

# Dependency graph
requires:
  - phase: 03-01 (Basic Chat Support)
    provides: ChatConfig, ChatParser, chat_response method, Anthropic Messages API integration
provides:
  - Tool/function calling support for Anthropic chat_response
  - ChatConfig.tools conversion from Sure format to Anthropic format
  - ChatParser.function_requests extraction from tool_use blocks
  - Support for parallel tool use (multiple tools in one response)
affects:
  - 03-03 (Function Results) - builds on tool_use handling to add tool_result blocks
  - 03-04 (Streaming) - tools may work with streaming responses

# Tech tracking
tech-stack:
  added: []
  patterns: Tool format conversion (input_schema vs parameters), parallel tool use handling

key-files:
  created: []
  modified:
    - app/models/provider/anthropic/chat_config.rb
    - app/models/provider/anthropic/chat_parser.rb
    - app/models/provider/anthropic.rb

key-decisions:
  - Anthropic uses "input_schema" instead of OpenAI's "parameters" for tool definitions
  - Anthropic's id serves as both id and call_id (unlike OpenAI's separate fields)
  - Anthropic's input is already a Hash (not JSON string like OpenAI's arguments)
  - Parallel tool use is supported (iterate all tool_use blocks in response)

patterns-established:
  - Pattern: ChatConfig.tools converts functions to provider-specific format
  - Pattern: ChatParser.function_requests extracts tool_use blocks from response.content
  - Pattern: Provider-specific differences in tool format (input_schema vs parameters)

issues-created: []

# Metrics
duration: ~5 min
completed: 2026-01-10
---

# Phase 3 Plan 2: Tool Calling Support Summary

**Added tool/function calling support to Anthropic chat_response with proper format conversion between Sure's functions format and Anthropic's tools format, plus parallel tool use handling**

## Performance

- **Duration:** 5 min
- **Started:** 2026-01-10T02:42:00Z (approx)
- **Completed:** 2026-01-10T02:47:00Z (approx)
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- Updated ChatConfig to convert Sure's functions format to Anthropic's tools format (input_schema)
- Updated ChatParser to extract tool_use blocks from Anthropic responses
- Updated chat_response to pass tools parameter to Anthropic Messages API
- Added support for parallel tool use (multiple tools in one response)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add tools conversion to ChatConfig** - `3d8d0ab3` (feat)
2. **Task 2: Add tool_use parsing to ChatParser** - `eccc64af` (feat)
3. **Task 3: Update chat_response to pass tools to API** - `aa27d004` (feat)

**Plan metadata:** TBD (docs commit after summary)

## Files Created/Modified

- `app/models/provider/anthropic/chat_config.rb` - Added tools method that converts functions to Anthropic format: {name, description, input_schema}
- `app/models/provider/anthropic/chat_parser.rb` - Added function_requests method that extracts tool_use blocks from response.content array
- `app/models/provider/anthropic.rb` - Updated chat_response to pass tools parameter when tools.present?

## Decisions Made

- **input_schema vs parameters:** Anthropic uses `input_schema` instead of OpenAI's `parameters` for tool definitions
- **id/call_id mapping:** Anthropic uses the same `id` for both id and call_id (unlike OpenAI's separate fields)
- **input format:** Anthropic's `input` field is already a Hash (not JSON string like OpenAI's `arguments`)
- **Parallel tool use:** Anthropic may call multiple tools in one response - iterate all tool_use blocks
- **strict parameter:** Anthropic doesn't support the "strict" parameter, so we ignore `fn[:strict]`

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## Next Phase Readiness

- Tool definitions are correctly converted to Anthropic format
- Tool_use blocks are correctly extracted from responses
- ChatFunctionRequest objects have correct structure (id, call_id, function_name, function_args)
- No blockers or concerns
- Ready for 03-03 (Function Results and Multi-Turn Conversations)

---

*Phase: 03-chat-support*
*Completed: 2026-01-10*
