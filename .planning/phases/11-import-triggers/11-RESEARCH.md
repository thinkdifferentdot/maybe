# Phase 11: Import Triggers - Research

**Researched:** 2026-01-10
**Domain:** Rails backend - Import/Sync job integration with AI categorization
**Confidence:** HIGH

<research_summary>
## Summary

Researched the Sure Rails codebase for implementing AI categorization triggers during CSV imports and Lunch Money sync jobs. The codebase has established patterns for:

1. **Import/Sync Jobs**: `ImportJob` and `SyncJob` are simple wrappers that call `import.publish` and `sync.perform`
2. **AI Categorization**: `Family::AutoCategorizer` + `AutoCategorizeJob` pattern already exists for Rules-based AI categorization
3. **Enrichment System**: `Enrichable` concern with `enrich_attribute`, `lock_attr!`, and `DataEnrichment` logging
4. **Provider Integration**: Both `Provider::Openai` and `Provider::Anthropic` support `auto_categorize` with batching (max 25 transactions)

Key finding: The existing `Family::AutoCategorizer` can be reused directly. The integration points are:
- **CSV Import**: Hook into `TransactionImport#import!` after transaction creation
- **Lunchflow Sync**: Hook into `LunchflowEntry::Processor#process` after each transaction import

**Primary recommendation:** Leverage existing `Family::AutoCategorizer` and `AutoCategorizeJob` patterns. Add triggers in `TransactionImport#import!` and create a new `LunchflowAccount::PostProcessor` for batch AI categorization after sync completes.

**Learned patterns system**: Create a new `LearnedPattern` model for fuzzy matching (merchant name → category). Use substring matching and common synonyms (already implemented in provider auto-categorizers). No external fuzzy matching gem needed.
</research_summary>

<standard_stack>
## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Rails | existing | Framework | Application is built on Rails |
| Sidekiq | existing | Background jobs | Async processing via `AutoCategorizeJob` |
| Family::AutoCategorizer | existing | AI orchestration | Works with any provider via Provider::Registry |
| Provider::Openai | existing | OpenAI integration | Supports auto_categorize with batching |
| Provider::Anthropic | existing | Anthropic integration | Supports auto_categorize with batching |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Enrichable concern | existing | Attribute enrichment | Use `enrich_attribute` for AI-assigned categories |
| DataEnrichment model | existing | Enrichment logging | Tracks source: "ai" for AI categorizations |
| Account::ProviderImportAdapter | existing | Transaction import | Use `import_transaction` for consistent imports |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom fuzzy matching | fuzzy_match gem | Existing substring matching is sufficient, avoids dependency |
| New LearnedPattern model | Use Rule system | Rules are heavier-weight; learned patterns should be lighter |

**Installation:**
```bash
# No new gems needed - all infrastructure exists
```
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Recommended Project Structure
```
app/models/
├── learned_pattern.rb          # NEW: merchant/category pattern learning
├── learned_pattern_matcher.rb  # NEW: fuzzy matching service
app/models/concerns/
├── learnable.rb                 # NEW: mixin for learning from user approvals
app/jobs/
├── batch_auto_categorize_job.rb # NEW: for import/sync completion
app/models/
├── transaction_import.rb        # MODIFY: add AI categorization trigger
├── lunchflow_account/           # MODIFY: add post-processor
│   └── post_processor.rb        # NEW: batch categorize after sync
```

### Pattern 1: Reuse Family::AutoCategorizer
**What:** Use existing `Family::AutoCategorizer` for AI categorization
**When to use:** All AI categorization - it's provider-agnostic and handles batching
**Example:**
```ruby
# Source: app/models/family/auto_categorizer.rb (existing)
def auto_categorize
  llm_provider.auto_categorize(
    transactions: transactions_input,
    user_categories: categories_input,
    family: family
  )
end

# Usage in import:
family.auto_categorize_transactions_later(
  Transaction.where(id: new_transaction_ids)
)
```

### Pattern 2: Learned Patterns for Auto-Approval
**What:** Store approved AI suggestions as patterns for future auto-approval
**When to use:** When user approves an AI-categorized transaction
**Example:**
```ruby
# After user approves AI suggestion
LearnedPattern.create!(
  family: family,
  merchant_name: transaction.merchant_name,
  normalized_merchant: normalize_for_matching(transaction.merchant_name),
  category_id: transaction.category_id
)

# Future transactions auto-approve if pattern matches
if pattern = family.learned_patterns.find_matching(transaction)
  transaction.update!(category_id: pattern.category_id)
end
```

### Pattern 3: Hook Into TransactionImport#import!
**What:** Trigger AI categorization after CSV import creates transactions
**When to use:** During CSV import when user opts in
**Example:**
```ruby
# Source: app/models/transaction_import.rb
def import!
  # ... existing transaction creation ...

  # NEW: Trigger AI categorization for uncategorized transactions
  if auto_categorize_enabled?
    uncategorized_ids = new_transactions.map(&:id)
    family.auto_categorize_transactions_later(
      Transaction.where(id: uncategorized_ids)
    )
  end
end
```

### Pattern 4: Lunchflow Post-Processor
**What:** Batch categorize after sync completes
**When to use:** After all transactions are imported
**Example:**
```ruby
# Source: app/models/lunchflow_account/post_processor.rb (NEW)
class LunchflowAccount::PostProcessor
  def initialize(lunchflow_account)
    @lunchflow_account = lunchflow_account
  end

  def process(transaction_ids)
    return unless auto_categorize_enabled?

    family.auto_categorize_transactions_later(
      Transaction.where(id: transaction_ids, category_id: nil)
    )
  end
end
```

### Anti-Patterns to Avoid
- **Synchronous AI calls during import**: Always use async `AutoCategorizeJob` to avoid blocking
- **Ignoring attribute locks**: Use `enrichable(:category_id)` scope to respect user overrides
- **Creating duplicate patterns**: Use `find_or_create_by` for learned patterns
- **Hardcoding provider**: Always use `Provider::Registry.get_provider` for provider-agnostic code
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| AI categorization orchestration | Custom API calls to OpenAI/Anthropic | `Family::AutoCategorizer` | Handles batching, errors, provider switching |
| Fuzzy matching algorithm | Custom Levenshtein distance | Substring matching + synonym hash | Simpler, faster, good enough for merchant names |
| Attribute enrichment tracking | Custom audit tables | `Enrichable` concern + `DataEnrichment` | Existing infrastructure tracks source: "ai" |
| Job queuing | Custom job creation | `AutoCategorizeJob` | Established pattern, handles rule runs |
| Provider selection | if/else on provider name | `Provider::Registry.get_provider` | Provider-agnostic, supports both OpenAI and Anthropic |
| Pattern normalization | Custom string cleaning | Borrow from `AutoCategorizer#find_fuzzy_category_match` | Existing synonym mappings work well |

**Key insight:** The Rails app has 3+ years of production patterns. Auto-categorization, enrichment, and job infrastructure are mature. Don't reinvent—extend.
</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

### Pitfall 1: Blocking Imports with Synchronous AI Calls
**What goes wrong:** CSV import takes 30+ seconds waiting for AI response
**Why it happens:** Calling AI provider directly in `import!` method
**How to avoid:** Always use `family.auto_categorize_transactions_later` for async processing
**Warning signs:** Import job takes longer than a few seconds

### Pitfall 2: Categorizing User-Edited Transactions
**What goes wrong:** AI overwrites user's manual category changes
**Why it happens:** Not checking `enrichable(:category_id)` scope or `locked_attributes`
**How to avoid:** Always use `scope.enrichable(:category_id)` before categorization
**Warning signs:** User reports "AI changed my category back"

### Pitfall 3: Exceeding Provider Batch Limits
**What goes wrong:** API errors when sending 100+ transactions at once
**Why it happens:** Provider limit is 25 transactions per request
**How to avoid:** Use `.in_batches(of: 25)` like `Rule::ActionExecutor::AutoCategorize`
**Warning signs:** "Request too large" or "Too many tokens" errors

### Pitfall 4: Cost Overruns on Large Imports
**What goes wrong:** 1000 transaction import costs $10+ in AI tokens
**Why it happens:** No cost limiting or user opt-in
**How to avoid:** Require opt-in checkbox for imports, implement per-family cost limits (Phase 10)
**Warning signs:** Unexpected AI costs on invoice
</common_pitfalls>

<code_examples>
## Code Examples

### Existing AutoCategorizer Pattern
```ruby
# Source: app/models/family/auto_categorizer.rb
class Family::AutoCategorizer
  def initialize(family, transaction_ids: [])
    @family = family
    @transaction_ids = transaction_ids
  end

  def auto_categorize
    llm_provider = Provider::Registry.get_provider(:openai)
    result = llm_provider.auto_categorize(
      transactions: transactions_input,
      user_categories: categories_input,
      family: family
    )

    scope.each do |transaction|
      auto_categorization = result.data.find { |c| c.transaction_id == transaction.id }
      category_id = categories_input.find { |c| c[:name] == auto_categorization&.category_name }&.dig(:id)

      if category_id.present?
        transaction.enrich_attribute(:category_id, category_id, source: "ai")
        transaction.lock_attr!(:category_id)
      end
    end
  end

  def scope
    family.transactions.where(id: transaction_ids, category_id: nil)
                       .enrichable(:category_id)
  end
end
```

### Existing Fuzzy Matching Pattern
```ruby
# Source: app/models/provider/openai/auto_categorizer.rb
def find_fuzzy_category_match(category_name)
  input_str = category_name.to_s
  normalized_input = input_str.downcase.gsub(/[^a-z0-9]/, "")

  user_categories.each do |cat|
    cat_name_str = cat[:name].to_s
    normalized_cat = cat_name_str.downcase.gsub(/[^a-z0-9]/, "")

    # Check if one contains the other
    return cat[:name] if normalized_input.include?(normalized_cat) || normalized_cat.include?(normalized_input)

    # Check common abbreviations/variations
    return cat[:name] if fuzzy_name_match?(input_str, cat_name_str)
  end

  nil
end

def fuzzy_name_match?(input, category)
  variations = {
    "gas" => ["gas & fuel", "gas and fuel", "fuel", "gasoline"],
    "restaurants" => ["restaurant", "dining", "food"],
    "groceries" => ["grocery", "supermarket", "food store"],
    # ... more variations
  }

  input_lower = input.to_s.downcase
  category_lower = category.to_s.downcase

  variations.each do |_key, synonyms|
    if synonyms.include?(input_lower) && synonyms.include?(category_lower)
      return true
    end
  end

  false
end
```

### Enrichable Pattern
```ruby
# Source: app/models/concerns/enrichable.rb
module Enrichable
  def enrich_attribute(attr, value, source:, metadata: {})
    return false if locked?(attr)

    self.send("#{attr}=", value)
    log_enrichment(attribute_name: attr, attribute_value: value, source: source, metadata: metadata)
    save
  end

  def locked?(attr)
    locked_attributes[attr.to_s].present?
  end

  def lock_attr!(attr)
    update!(locked_attributes: locked_attributes.merge(attr.to_s => Time.current))
  end
end
```

### Trigger Pattern for Import
```ruby
# Proposed: app/models/transaction_import.rb
def import!
  # ... existing transaction creation ...

  # NEW: Collect IDs of uncategorized transactions
  uncategorized_ids = new_transactions.select { |t| t.category_id.nil? }.map(&:id)

  # Trigger AI categorization if enabled
  if auto_categorize_enabled? && uncategorized_ids.any?
    family.auto_categorize_transactions_later(
      Transaction.where(id: uncategorized_ids)
    )
  end
end

private

def auto_categorize_enabled?
  # Will be implemented in Phase 10 (Settings)
  # For now, can use a simple flag or ENV variable
  family.settings&.dig(:enable_auto_categorize_import) || false
end
```
</code_examples>

<sota_updates>
## State of the Art (2024-2025)

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| OpenAI-only | Provider::Registry with OpenAI + Anthropic | v1.0 (2026-01-10) | Must use registry for provider-agnostic code |
| Direct provider calls | Family::AutoCategorizer wrapper | v1.0 | Simplified API, handles errors and usage tracking |
| Manual attribute tracking | Enrichable concern + DataEnrichment | Existing pattern | Use `enrich_attribute` for all AI categorizations |

**New tools/patterns to consider:**
- **Provider::Registry**: Always use for provider lookup - supports both OpenAI and Anthropic
- **Langfuse tracing**: Automatically tracked by providers - no manual instrumentation needed
- **enrichable scope**: Use `transactions.enrichable(:category_id)` to respect user locks

**Deprecated/outdated:**
- **Direct Provider::Openai instantiation**: Use `Provider::Registry.get_provider(:openai)` instead
- **Setting category without enrich_attribute**: Use `transaction.enrich_attribute(:category_id, value, source: "ai")`
</sota_updates>

<open_questions>
## Open Questions

1. **Learned Pattern Storage**
   - What we know: Need `LearnedPattern` model with merchant_name, normalized_merchant, category_id
   - What's unclear: Whether to store patterns at family level or global level
   - Recommendation: Family-scoped only (per CONTEXT.md), no sharing across users

2. **Bulk Review Workflow**
   - What we know: Need a way for users to approve/reject AI suggestions in bulk
   - What's unclear: Whether to store suggestions in a separate table or use status on transactions
   - Recommendation: Add `suggested_category_id` to Transaction model, status enum for pending/accepted/rejected

3. **Cost Control Timing**
   - What we know: Phase 10 will implement cost limits and settings
   - What's unclear: Whether to implement basic opt-in now or wait for Phase 10
   - Recommendation: Implement simple opt-in checkbox now, defer full cost controls to Phase 10
</open_questions>

<sources>
## Sources

### Primary (HIGH confidence)
- app/models/family/auto_categorizer.rb - AutoCategorizer implementation
- app/models/transaction_import.rb - CSV import flow
- app/models/lunchflow_account/processor.rb - Sync orchestration
- app/models/lunchflow_entry/processor.rb - Individual transaction import
- app/models/concerns/enrichable.rb - Enrichment pattern
- app/models/provider/openai/auto_categorizer.rb - Fuzzy matching implementation
- app/models/rule/action_executor/auto_categorize.rb - Batch processing pattern (20 per batch)
- app/jobs/auto_categorize_job.rb - Async job wrapper

### Secondary (MEDIUM confidence)
- app/models/import.rb - Import.publish pattern
- app/models/family.rb - auto_categorize_transactions_later method
- app/models/data_enrichment.rb - Enrichment logging with source: "ai"
- app/models/account/provider_import_adapter.rb - Transaction import adapter

### Tertiary (LOW confidence - needs validation)
- None - all findings verified from actual codebase
</sources>

<metadata>
## Metadata

**Research scope:**
- Core technology: Rails + Sidekiq + existing AI infrastructure
- Ecosystem: Family::AutoCategorizer, Enrichable concern, Provider::Registry
- Patterns: Async jobs, enrichment with source tracking, fuzzy matching via substring
- Pitfalls: Blocking imports, ignoring locks, batch limits, cost overruns

**Confidence breakdown:**
- Standard stack: HIGH - existing infrastructure verified in codebase
- Architecture: HIGH - patterns are well-established and production-tested
- Pitfalls: HIGH - based on existing code patterns and documented issues
- Code examples: HIGH - extracted directly from codebase

**Research date:** 2026-01-10
**Valid until:** 2026-02-10 (30 days - patterns are stable, internal codebase)
</metadata>

---

*Phase: 11-import-triggers*
*Research completed: 2026-01-10*
*Ready for planning: yes*
