# Phase 4 Plan 1: Registry Integration Summary

**Registered Anthropic as an equal citizen to OpenAI in the provider registry with full cost tracking support**

## Accomplishments

- Added `anthropic` method to Provider::Registry following OpenAI pattern
- Made Anthropic discoverable for LLM concept
- Added complete Claude model pricing to LlmUsage
- Verified cost calculation works for all Anthropic models

## Files Created/Modified

- `app/models/provider/registry.rb` - Added `anthropic` method (lines 81-89), updated `available_providers` to include `:anthropic` for `:llm` concept
- `app/models/llm_usage.rb` - Added Anthropic pricing hash (lines 37-45) with all Claude models

## Decisions Made

- Used base model names in pricing (prefix matching handles versions)
- Followed exact OpenAI pattern for ENV -> Setting fallback
- Mapped Anthropic input/output to prompt/completion for consistency
- Used `Setting["anthropic_access_token"]` bracket notation instead of `Setting.anthropic_access_token` method to avoid dependency on Phase 5 Setting model changes

## Issues Encountered

**Issue:** Initial implementation used `Setting.anthropic_access_token` and `Setting.anthropic_model` which don't exist yet (Phase 5).

**Solution:** Used Setting's bracket notation (`Setting["anthropic_access_token"]`) which supports dynamic fields and doesn't require explicit field declarations. This provides backward compatibility and allows Phase 4 to complete independently of Phase 5.

## Verification Results

All verification criteria passed:

- [x] Provider::Registry.anthropic method exists and returns Provider::Anthropic instance or nil
- [x] Registry.for_concept(:llm).providers includes :anthropic when configured
- [x] LlmUsage::PRICING includes "anthropic" key with Claude model pricing
- [x] LlmUsage.calculate_cost works for Anthropic models (e.g., model: "claude-sonnet-4", prompt_tokens: 1000, completion_tokens: 500 returns $0.0105)
- [x] LlmUsage.infer_provider returns "anthropic" for Claude model names
- [x] No Rubocop offenses introduced
- [x] No test failures (1559 tests pass)

## Pricing Added

```ruby
"anthropic" => {
  "claude-opus-4" => { prompt: 15.00, completion: 75.00 },
  "claude-sonnet-4" => { prompt: 3.00, completion: 15.00 },
  "claude-sonnet-3.7" => { prompt: 3.00, completion: 15.00 },
  "claude-sonnet-3.5" => { prompt: 3.00, completion: 15.00 },
  "claude-haiku-3.5" => { prompt: 0.80, completion: 4.00 },
  "claude-opus-3" => { prompt: 15.00, completion: 75.00 },
  "claude-haiku-3" => { prompt: 0.25, completion: 1.25 }
}
```

## Next Step

Phase 4 Plan 1 complete, ready for Phase 5 (Settings Model) - Add `anthropic_access_token`, `anthropic_model`, and `llm_provider` fields to Setting model. The bracket notation used in this phase will seamlessly transition to explicit field declarations in Phase 5.
