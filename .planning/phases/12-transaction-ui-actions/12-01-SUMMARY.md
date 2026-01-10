# Phase 12 Plan 1: Backend Provider Selection & Confidence Summary

**AutoCategorizer now supports dynamic provider selection and confidence tracking**

## Accomplishments

- Updated AutoCategorizer to use family's configured LLM provider (openai/anthropic)
- Added AutoCategorizer::Result struct with transaction_id, category_name, confidence
- Confidence scores stored in transaction.extra["ai_categorization_confidence"]
- Tests verify provider selection and confidence tracking work correctly

## Files Created/Modified

- `app/models/family/auto_categorizer.rb` - Dynamic provider selection, Result struct, confidence storage
- `test/models/family/auto_categorizer_test.rb` - Tests for provider selection and confidence

## Decisions Made

- Confidence stored in transaction.extra metadata for simplicity (no new table)
- Default confidence of 1.0 for now until providers return actual confidence scores
- Provider selection uses Setting.llm_provider with "openai" fallback
- Uses `Provider::Registry.for_concept(:llm).get_provider(name)` pattern for dynamic provider selection

## Implementation Details

### Dynamic Provider Selection
Changed from hardcoded `Provider::Registry.get_provider(:openai)` to:
```ruby
def llm_provider
  provider_name = Setting.llm_provider.presence || "openai"
  Provider::Registry.for_concept(:llm).get_provider(provider_name)
end
```

### Result Struct
Added `Family::AutoCategorizer::Result` Data define with:
- `transaction_id` - ID of the categorized transaction
- `category_name` - Name of the assigned category
- `confidence` - Float between 0.0 and 1.0, defaults to 1.0

### Confidence Storage
Confidence is persisted in `transaction.extra["ai_categorization_confidence"]` using `update_column` to bypass validations and callbacks after `enrich_attribute` succeeds.

## Issues Encountered

None

## Next Step

Ready for 12-02-PLAN.md (Individual AI categorize button in UI)
