---
phase: 01-foundation
plan: 02
type: execute
domain: rails
---

<objective>
Create the Provider::Anthropic class skeleton with proper inheritance and module inclusion.

Purpose: Establish the class structure that mirrors Provider::Openai. This skeleton defines the class, includes required modules, defines error handling, and declares the interface methods (as NotImplementedError stubs). No API calls will be made - this is purely structural setup.

Output: app/models/provider/anthropic.rb with complete class skeleton
</objective>

<execution_context>
~/.claude/get-shit-done/workflows/execute-phase.md
./summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/phases/1-foundation/1-CONTEXT.md
@.planning/phases/1-foundation/1-RESEARCH.md
@app/models/provider.rb
@app/models/provider/openai.rb
@app/models/provider/llm_concept.rb
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create Provider::Anthropic class skeleton</name>
  <files>app/models/provider/anthropic.rb</files>
  <action>Create a new file app/models/provider/anthropic.rb with the following structure:

```ruby
class Provider::Anthropic < Provider
  include LlmConcept

  # Subclass so errors caught in this provider are raised as Provider::Anthropic::Error
  Error = Class.new(Provider::Error)

  # Supported Anthropic model prefixes (e.g., "claude-sonnet", "claude-opus", etc.)
  DEFAULT_ANTHROPIC_MODEL_PREFIXES = %w[claude-]
  DEFAULT_MODEL = "claude-sonnet-4-5-20250929"

  def initialize(access_token, model: nil)
    raise NotImplementedError, "Client initialization to be implemented in plan 1-03"
  end

  def provider_name
    "Anthropic"
  end

  def supports_model?(model)
    DEFAULT_ANTHROPIC_MODEL_PREFIXES.any? { |prefix| model.start_with?(prefix) }
  end

  def supported_models_description
    "models starting with: #{DEFAULT_ANTHROPIC_MODEL_PREFIXES.join(', ')}"
  end
end
```

Note: initialize raises NotImplementedError because client creation happens in plan 1-03. The LlmConcept module methods (auto_categorize, auto_detect_merchants, chat_response) will raise NotImplementedError from the module definition - no need to redeclare them here.</action>
  <verify>File exists at app/models/provider/anthropic.rb; ruby -c shows no syntax errors; Rails can autoload the class</verify>
  <done>Provider::Anthropic class created with proper inheritance, Error subclass, model constants, and provider_name/supports_model? methods</done>
</task>

<task type="auto">
  <name>Task 2: Verify class loads correctly in Rails</name>
  <files>(none - verification only)</files>
  <action>Run `bin/rails runner "puts Provider::Anthropic.name"` to verify the class can be autoloaded by Rails. This confirms the file is in the correct location and follows Rails naming conventions. Also verify `Provider::Anthropic::Error` is correctly defined as a subclass of `Provider::Error`.</action>
  <verify>bin/rails runner command prints "Provider::Anthropic" without errors; Provider::Anthropic::Error.is_a?(Class) returns true</verify>
  <done>Class autloads successfully, inheritance chain correct (Provider::Anthropic < Provider), Error subclass properly defined</done>
</task>

</tasks>

<verification>
Before declaring plan complete:
- [ ] File exists at app/models/provider/anthropic.rb
- [ ] `ruby -c app/models/provider/anthropic.rb` shows no syntax errors
- [ ] `bin/rails runner "puts Provider::Anthropic.name"` succeeds
- [ ] `bin/rails runner "puts Provider::Anthropic.superclass.name"` returns "Provider"
- [ ] `bin/rails runner "puts Provider::Anthropic::Provider"` returns "Anthropic"
</verification>

<success_criteria>

- Provider::Anthropic class created with proper structure
- Inherits from Provider, includes LlmConcept
- Error subclass defined for provider-specific errors
- Model constants defined (DEFAULT_MODEL, DEFAULT_ANTHROPIC_MODEL_PREFIXES)
- provider_name and supports_model? methods implemented
- Class autloads in Rails without errors
</success_criteria>

<output>
After completion, create `.planning/phases/1-foundation/1-02-SUMMARY.md`:

# Phase 1 Plan 2: Create Provider::Anthropic Skeleton Summary

**Created Provider::Anthropic class skeleton mirroring Provider::Openai structure**

## Accomplishments

- Created app/models/provider/anthropic.rb with proper Provider inheritance
- Included LlmConcept module for LLM provider interface
- Defined Error subclass for provider-specific error handling
- Added model constants (DEFAULT_MODEL, DEFAULT_ANTHROPIC_MODEL_PREFIXES)
- Implemented provider_name and supports_model? methods

## Files Created/Modified

- `app/models/provider/anthropic.rb` - New provider class skeleton (full structure, no client yet)

## Decisions Made

- DEFAULT_MODEL set to "claude-sonnet-4-5-20250929" (latest Sonnet 4.5 as of research)
- Model prefix matching uses start_with? for flexibility (matches claude-sonnet, claude-opus, etc.)
- initialize raises NotImplementedError temporarily until plan 1-03

## Issues Encountered

None

## Next Step

Ready for 1-03-PLAN.md - Implement client initialization and error handling
</output>
