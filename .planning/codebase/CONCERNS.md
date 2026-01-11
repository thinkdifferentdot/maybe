# Codebase Concerns

**Analysis Date:** 2026-01-11

## Tech Debt

**Code Duplication - JSON Parsing Methods:**
- Issue: `parse_json_flexibly` method duplicated across 4 files
- Files:
  - `app/models/provider/anthropic/auto_categorizer.rb` (~85 lines, 292-377)
  - `app/models/provider/anthropic/auto_merchant_detector.rb`
  - `app/models/provider/openai/auto_categorizer.rb`
  - `app/models/provider/openai/auto_merchant_detector.rb`
- Why: Each provider implementation has its own copy
- Impact: Maintenance burden - bugs must be fixed in 4 places
- Fix approach: Extract to shared module in `app/models/provider/concerns/json_parser.rb`

**Code Duplication - Thinking Tag Stripping:**
- Issue: `strip_thinking_tags` method duplicated across same 4 files
- Files: Same as above
- Why: Each provider needs to handle Claude thinking tags
- Impact: Same maintenance burden
- Fix approach: Extract to shared concern

**Complex JSON Parsing Logic:**
- Issue: Overly complex JSON parsing with multiple fallback strategies
- File: `app/models/provider/anthropic/auto_categorizer.rb:292-377` (85 lines)
- Why: LLM output varies, requires flexible parsing
- Impact: Difficult to debug parsing failures
- Fix approach: Simplify with smaller helper methods, add unit tests

## Known Bugs

**Categorization Accuracy Issues:**
- Symptoms: AI returns >50% null values sometimes
- Trigger: When transactions don't clearly match categories
- Files:
  - `app/models/provider/openai/auto_categorizer.rb:15` (fallback logic)
  - `app/models/provider/anthropic/auto_categorizer.rb:78` (60% confidence threshold)
- Workaround: System retries with strict mode when high null ratio
- Root cause: LLM uncertainty about categorization
- Fix: Improve prompts, add few-shot examples

**Inconsistent Error Handling:**
- Symptoms: Different error handling patterns across similar code
- Files:
  - `app/models/provider/anthropic/auto_merchant_detector.rb:54-74` (detailed error handling)
  - `app/models/provider/anthropic/auto_categorizer.rb:55-58` (generic rescue)
- Impact: Poor debugging experience for categorization errors
- Fix approach: Standardize error handling across all auto-* methods

## Security Considerations

**Good Security Practices:**
- ✅ API keys passed through constructor, not hardcoded
- ✅ Environment variables for configuration
- ✅ Error messages don't expose sensitive information
- ✅ Active Record Encryption for stored API keys
- ✅ VCR sensitive data filtering in tests

**Potential Prompt Injection:**
- Risk: User transaction names could contain malicious prompts
- Files: Various instruction methods in AI providers
- Current mitigation: None explicitly detected
- Recommendations: Add input sanitization, prompt injection guards

**Missing .env.example Entries:**
- Risk: Users don't know required AI configuration variables
- File: `.env.example`
- Missing: `ANTHROPIC_API_KEY`, `ANTHROPIC_MODEL` variables
- Fix approach: Add missing variables to `.env.example`

## Performance Bottlenecks

**No Rate Limiting for AI Calls:**
- Problem: No protection against excessive AI API calls
- File: No AI-specific rate limiting detected
- Measurement: Not applicable
- Cause: Not implemented
- Improvement path: Add Rack::Attack rules for AI endpoints

**No Caching of AI Results:**
- Problem: Repeated categorization of same transactions re-calls AI
- File: Categorization logic in `Family::AutoCategorizer`
- Measurement: Each call takes 1-5 seconds
- Cause: No caching layer
- Improvement path: Cache results by transaction hash (name + amount + date)

**Synchronous API Calls:**
- Problem: AI operations block request handling
- Files: Controllers call providers synchronously
- Measurement: 2-10 second response times for bulk categorization
- Cause: No background job for on-demand categorization
- Improvement path: Always use background jobs for AI operations (job exists but not always used)

## Fragile Areas

**JSON Parsing:**
- File: `app/models/provider/anthropic/auto_categorizer.rb:292-377`
- Why fragile: Many edge cases, complex fallback logic
- Common failures: Malformed JSON, unexpected response format
- Safe modification: Add unit tests for each parsing branch before changing
- Test coverage: Partial - needs more edge case tests

**Provider Selection Logic:**
- File: `app/models/provider/registry.rb`
- Why fragile: Multiple fallback paths, complex logic
- Common failures: No provider configured returns unexpected results
- Safe modification: Test with no provider configured
- Test coverage: Needs improvement

**Langfuse Integration:**
- Files: Multiple provider files call `create_langfuse_trace`
- Why fragile: Langfuse failure could break AI operations
- Common failures: Network issues, invalid API keys
- Safe modification: Wrap Langfuse calls in rescue blocks
- Test coverage: Needs tests for Langfuse failure scenarios

## Scaling Limits

**AI API Rate Limits:**
- Current capacity: Limited by provider rate limits
- Anthropic: ~50 requests/minute (tier-dependent)
- OpenAI: ~500 requests/minute (tier-dependent)
- Limit: Exceeding rate limits causes failures
- Symptoms at limit: 429 rate limit errors
- Scaling path: Implement request queuing with rate limit awareness

**Batch Size Limits:**
- Current capacity: 25 transactions per AI request
- Limit: Hardcoded in both providers
- File: `app/models/provider/*/auto_categorizer.rb`
- Symptoms at limit: Error for batches > 25
- Scaling path: Implement automatic batching for larger sets

## Dependencies at Risk

**anthropic gem:**
- Risk: Version pinned to ~> 1.16.0, may miss updates
- Impact: New model features not available
- Migration plan: Periodically review and update version constraint

**langfuse-ruby gem:**
- Risk: Version pinned to ~> 0.1.4, relatively new project
- Impact: Potential breaking changes on update
- Migration plan: Watch for stable releases, test upgrades thoroughly

**ruby-openai gem:**
- Risk: Active development, frequent changes
- Impact: Possible breaking changes
- Migration plan: Pin to specific versions, test upgrades

## Missing Critical Features

**AI Cost Monitoring:**
- Problem: No per-family cost limits or alerts
- Current workaround: Manual review of LlmUsage table
- Blocks: Cost control for managed deployments
- Implementation complexity: Low (add daily/monthly limits)

**Categorization Feedback Loop:**
- Problem: No way for users to provide feedback on AI categorization
- Current workaround: Users manually re-categorize (but this doesn't improve AI)
- Blocks: Continuous improvement of AI accuracy
- Implementation complexity: Medium (feedback UI + retraining pipeline)

**Evaluation Framework:**
- Problem: `Eval::Runners` classes exist but no automated evaluation
- Current workaround: Manual testing
- Blocks: Measuring AI improvements over time
- Implementation complexity: Low (automate existing runners)

## Test Coverage Gaps

**JSON Parsing Edge Cases:**
- What's not tested: Various malformed JSON formats, thinking tags, markdown blocks
- Risk: Parsing failures in production
- Priority: High
- Difficulty to test: Medium (need various malformed examples)

**Langfuse Failure Scenarios:**
- What's not tested: What happens when Langfuse is unreachable
- Risk: AI operations could fail if Langfuse errors propagate
- Priority: Medium
- Difficulty to test: Medium (need to simulate network failures)

**Error Handling Paths:**
- what's not tested: Generic rescue clauses in auto-categorizers
- Risk: Errors are silently swallowed or poorly reported
- Priority: High
- Difficulty to test: Low (can mock error responses)

---

*Concerns audit: 2026-01-11*
*Update as issues are fixed or new ones discovered*
