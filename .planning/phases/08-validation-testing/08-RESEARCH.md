# Phase 8: Validation & Testing - Research

**Researched:** 2026-01-09
**Domain:** Rails testing (Minitest, fixtures, VCR)
**Confidence:** HIGH

<research_summary>
## Summary

Phase 8 is standard Rails testing work following established project patterns. No external ecosystem research required - the codebase already has comprehensive test infrastructure in place using Minitest, fixtures, and VCR cassettes.

The research identified existing test patterns for LLM providers via `Provider::OpenaiTest` which serves as a complete reference. The project uses shared test interfaces (`LLMInterfaceTest`, `ProviderAdapterTestInterface`) and test helpers (`ProviderTestHelper`) that should be leveraged for Anthropic tests.

**Primary recommendation:** Mirror `Provider::OpenaiTest` structure for `Provider::AnthropicTest`, create VCR cassettes for all Anthropic API calls, and verify OpenAI tests still pass (regression check). No new libraries or patterns needed.
</research_summary>

<standard_stack>
## Standard Stack

The project uses established Rails testing patterns - no changes needed.

### Core (Already in Project)
| Library/Tool | Version | Purpose | Why Standard |
|--------------|---------|---------|--------------|
| Minitest | Bundled with Rails | Test framework | Rails default, no setup needed |
| Fixtures | Bundled with Rails | Test data | Rails default, files in `test/fixtures/` |
| VCR | (via webmock gem) | API recording/replay | Prevents real API calls during tests |
| Mocha | (via mocha gem) | Mocking/stubbing | Rails convention for mocks |

### Project-Specific Test Infrastructure
| File/Module | Purpose |
|-------------|---------|
| `test/interfaces/llm_interface_test.rb` | Shared LLM test interface |
| `test/support/provider_test_helper.rb` | Provider test helpers (`provider_success_response`, `provider_error_response`) |
| `test/support/provider_adapter_test_interface.rb` | Shared provider adapter interface tests |
| `test/vcr_cassettes/openai/` | Reference cassettes for VCR structure |

### Installation
No installation needed - all dependencies already in project.
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Test File Structure (Following Existing Pattern)
```
test/
├── models/
│   └── provider/
│       ├── openai_test.rb          # Reference implementation
│       └── anthropic_test.rb       # NEW: To be created
├── vcr_cassettes/
│   ├── openai/                     # Reference cassettes
│   │   ├── chat/
│   │   ├── auto_categorize.yml
│   │   └── auto_detect_merchants.yml
│   └── anthropic/                  # NEW: To be created
│       ├── chat/
│       ├── auto_categorize.yml
│       └── auto_detect_merchants.yml
```

### Pattern 1: LLM Provider Test Structure
**What:** Mirror `Provider::OpenaiTest` structure for Anthropic tests
**When to use:** All Anthropic provider tests
**Example:**
```ruby
require "test_helper"

class Provider::AnthropicTest < ActiveSupport::TestCase
  include LLMInterfaceTest

  setup do
    @subject = Provider::Anthropic.new(ENV.fetch("ANTHROPIC_API_KEY", "test-key"))
    @subject_model = "claude-sonnet-4-5-20250929"
  end

  test "auto categorizes transactions" do
    VCR.use_cassette("anthropic/auto_categorize") do
      # Test implementation matching OpenAI structure
    end
  end

  # ... additional tests matching OpenAI pattern
end
```

### Pattern 2: VCR Cassette Usage
**What:** Wrap all API calls in `VCR.use_cassette` blocks
**When to use:** Every test that makes an external API call
**Example:**
```ruby
test "chat response with function calls" do
  VCR.use_cassette("anthropic/chat/function_calls") do
    # Test code that calls Anthropic API
    # First call will record, subsequent calls replay
  end
end
```

### Pattern 3: Regression Testing (OpenAI Verification)
**What:** Re-run existing OpenAI tests to ensure no regressions
**When to use:** After Anthropic implementation complete
**Example:**
```bash
# Run only OpenAI provider tests
bin/rails test test/models/provider/openai_test.rb

# Should all pass - no behavior changes for OpenAI users
```

### Anti-Patterns to Avoid
- **Don't use RSpec factories** - Project uses fixtures, not FactoryBot
- **Don't skip VCR cassettes** - All API calls must be recorded for reproducible tests
- **Don't test implementation details** - Test inputs/outputs, not internal code paths
- **Don't use real API keys in tests** - Use VCR recordings or test tokens
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Test data fixtures | Manual object creation | Rails fixtures in `test/fixtures/*.yml` | Existing pattern, consistent across project |
| API mocking | Manual stubs | VCR cassettes | Real recordings, not fake mocks |
| Test helpers | Custom helper code | `ProviderTestHelper` module | Already exists, use `provider_success_response`, `provider_error_response` |
| Shared interface tests | Custom test methods | `LLMInterfaceTest` module | Include this module for shared LLM tests |

**Key insight:** The test infrastructure is already battle-tested. Don't invent new patterns - follow what `Provider::OpenaiTest` already does.
</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

### Pitfall 1: VCR Cassette Mismatch
**What goes wrong:** Tests fail because VCR cassette doesn't match API request signature
**Why it happens:** API params changed, cassette outdated, or cassette for wrong endpoint
**How to avoid:**
- Name cassettes descriptively: `anthropic/chat/function_calls`
- Re-record cassettes if API behavior changes
- Match cassette structure to OpenAI's pattern
**Warning signs:** VCR errors about "no cassette handled request", "unhandled request"

### Pitfall 2: Testing Implementation Details
**What goes wrong:** Tests break when refactoring code, even if behavior unchanged
**Why it happens:** Testing internal methods instead of public interfaces
**How to avoid:**
- Test only public methods (`auto_categorize`, `chat_response`, etc.)
- Assert on response structure (`response.data`, `response.success?`)
- Don't test private methods directly
**Warning signs:** Tests need updating after code refactoring

### Pitfall 3: OpenAI Regressions
**What goes wrong:** Anthropic changes break existing OpenAI functionality
**Why it happens:** Shared code modified without running OpenAI tests
**How to avoid:**
- Run OpenAI tests after each Anthropic change
- Keep provider code isolated (no shared state)
- Use `bin/rails test test/models/provider/openai_test.rb` as regression check
**Warning signs:** OpenAI tests start failing after Anthropic work

### Pitfall 4: Missing Error Cases
**What goes wrong:** Tests only pass happy path, production errors unhandled
**Why it happens:** Focusing on normal flow, forgetting edge cases
**How to avoid:**
- Test API errors (invalid keys, rate limits, invalid models)
- Test malformed responses
- Test network timeouts (via VCR or mocks)
**Warning signs:** Production errors that weren't caught in tests
</common_pitfalls>

<code_examples>
## Code Examples

Verified patterns from existing codebase:

### Basic Test Structure (from Provider::OpenaiTest)
```ruby
# Source: test/models/provider/openai_test.rb
require "test_helper"

class Provider::AnthropicTest < ActiveSupport::TestCase
  include LLMInterfaceTest

  setup do
    @subject = Provider::Anthropic.new(ENV.fetch("ANTHROPIC_API_KEY", "test-key"))
    @subject_model = "claude-sonnet-4-5-20250929"
  end

  test "auto categorizes transactions" do
    VCR.use_cassette("anthropic/auto_categorize") do
      response = @subject.auto_categorize(
        transactions: [...],
        user_categories: [...]
      )

      assert response.success?
      assert_equal expected_count, response.data.size
    end
  end
end
```

### Provider Test Helper Usage
```ruby
# Source: test/support/provider_test_helper.rb
require "test_helper"

class Provider::AnthropicTest < ActiveSupport::TestCase
  include ProviderTestHelper

  test "returns success response" do
    data = { result: "success" }
    response = provider_success_response(data)

    assert response.success?
    assert_equal data, response.data
  end
end
```

### VCR Cassette Structure (Reference)
```yaml
# Source: test/vcr_cassettes/openai/chat/basic_response.yml
http_interactions:
- request:
    method: post
    uri: https://api.openai.com/v1/chat/completions
    body:
      encoding: UTF-8
      string: '{"model":"gpt-4.1","messages":[{"role":"user","content":"..."}]}'
    headers:
      Content-Type:
      - application/json
      Authorization:
      - Bearer sk-test-token
  response:
    status:
      code: 200
      message: OK
    body:
      encoding: UTF-8
      string: '{"id":"chatcmpl-...","choices":[...],"usage":{...}}'
    headers:
      Content-Type:
      - application/json
recorded_with: VCR 6.1.0
```
</code_examples>

<sota_updates>
## State of the Art (2024-2025)

No updates needed - Rails testing patterns are stable and mature.

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| TestUnit | Minitest | Rails 3+ | Minitest is Rails default |
| RSpec (in some projects) | Minitest (in this project) | Project start | Consistent with Rails conventions |

**Project-specific conventions:**
- **Fixtures not factories** - Project uses `test/fixtures/*.yml`, not FactoryBot
- **VCR for API tests** - All external API calls recorded as cassettes
- **Minitest not RSpec** - Follow project convention, don't introduce RSpec
</sota_updates>

<open_questions>
## Open Questions

None. All testing patterns are well-established in the codebase.
</open_questions>

<sources>
## Sources

### Primary (HIGH confidence)
- `test/models/provider/openai_test.rb` - Complete reference implementation for LLM provider tests
- `test/interfaces/llm_interface_test.rb` - Shared LLM test interface module
- `test/support/provider_test_helper.rb` - Provider test helper methods
- `test/vcr_cassettes/openai/` - Reference VCR cassette structure and organization

### Secondary (MEDIUM confidence)
- `CLAUDE.md` - Project testing philosophy (minimal, critical paths only, fixtures not factories)
- `test/support/provider_adapter_test_interface.rb` - Shared provider adapter interface tests

### Tertiary (LOW confidence - needs validation)
- None - all findings verified against codebase
</sources>

<metadata>
## Metadata

**Research scope:**
- Core technology: Rails testing (Minitest, fixtures, VCR)
- Ecosystem: None needed (project-specific patterns only)
- Patterns: Test file structure, VCR usage, regression testing
- Pitfalls: VCR mismatches, implementation testing, regressions

**Confidence breakdown:**
- Standard stack: HIGH - verified in codebase (Gemfile, existing tests)
- Architecture: HIGH - from `Provider::OpenaiTest` reference implementation
- Pitfalls: HIGH - common Rails testing issues, documented in CLAUDE.md
- Code examples: HIGH - directly from existing codebase

**Research date:** 2026-01-09
**Valid until:** 2026-07-09 (180 days - Rails testing patterns stable)

**Assessment:** Research confirms Phase 08 does NOT require external ecosystem research. All patterns exist in codebase. Proceed directly to planning.
</metadata>

---

*Phase: 08-validation-testing*
*Research completed: 2026-01-09*
*Ready for planning: yes*
