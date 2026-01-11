# Phase 29: Improve Categorization Prompts - Research

**Researched:** 2026-01-11
**Domain:** Few-shot prompt engineering for LLM transaction classification
**Confidence:** HIGH

<research_summary>
## Summary

Research focused on few-shot learning techniques for improving AI transaction categorization. The codebase currently has >50% null categorization results. Adding few-shot examples to prompts is a proven technique for improving classification accuracy without fine-tuning.

**Primary findings:**
1. **OpenAI Cookbook example** confirms transaction categorization benefits significantly from few-shot examples
2. **Static examples** should be diverse, representative, and cover common transaction types
3. **Dynamic examples** from LearnedPattern model provide personalization without retraining
4. **Example selection strategy:** Diversity > similarity — avoid clustering similar examples
5. **3-5 examples** is optimal for few-shot; more examples = more tokens but diminishing returns

**Primary recommendation:** Implement a two-tier few-shot system: static baseline examples (3-5 hardcoded) + optional LearnedPattern examples (up to 3) for personalization.
</research_summary>

<standard_stack>
## Standard Stack

### Core
| Library/Tool | Version | Purpose | Why Standard |
|-------------|---------|---------|--------------|
| OpenAI Responses API | latest | Native structured outputs | JSON schema, strict mode |
| Anthropic Messages API | latest | Tool use for structured output | Alternative to OpenAI |
| Ruby on Rails | 7.2 | Application framework | Existing codebase |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| LearnedPattern model | existing | User's historical categorization patterns | Already in codebase |
| Provider::Concerns::JsonParser | existing | Flexible JSON parsing | Handles multiple LLM output formats |
| Provider::Concerns::ErrorHandler | existing | Consistent error handling | Already integrated |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Few-shot prompts | Fine-tuning | Fine-tuning requires training, ongoing maintenance. Few-shot works immediately. |
| Static examples | RAG/dynamic retrieval | RAG adds complexity. Static + LearnedPattern is simpler and effective. |

**Installation:** No new dependencies required.
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Recommended Project Structure
```
app/models/provider/
├── concerns/
│   └── few_shot_examples.rb  # NEW: Shared few-shot example builder
├── openai/
│   └── auto_categorizer.rb    # MODIFY: Add few-shot to developer_message
└── anthropic/
    └── auto_categorizer.rb    # MODIFY: Add few-shot to developer_message
```

### Pattern 1: Two-Tier Few-Shot Construction
**What:** Build examples from two sources: static baseline + user-specific LearnedPattern
**When to use:** All categorization requests
**Example:**
```ruby
# In Provider::Concerns::FewShotExamples
def build_few_shot_examples(user_categories, family)
  examples = []

  # Tier 1: Static baseline examples (3-5 hardcoded)
  examples.concat(static_examples)

  # Tier 2: User's LearnedPattern examples (0-3, if available)
  if family
    examples.concat(learned_pattern_examples(family, max: 3))
  end

  examples
end

private

def static_examples
  [
    {
      transaction: { id: "example-1", description: "WHOLEFDS MARKET", amount: 85.42, classification: "expense" },
      category: "Groceries",
      explanation: "Whole Foods is a grocery store"
    },
    {
      transaction: { id: "example-2", description: "SHELL OIL STA 1234", amount: 45.00, classification: "expense" },
      category: "Gas & Fuel",
      explanation: "Shell is a gas station"
    },
    {
      transaction: { id: "example-3", description: "STARBUCKS COFFEE", amount: 6.50, classification: "expense" },
      category: "Coffee Shops",
      explanation: "Starbucks is a coffee chain"
    }
    # ... 2-3 more covering restaurants, subscriptions, etc.
  ]
end
```

### Pattern 2: Example Selection from LearnedPattern
**What:** Query diverse examples from user's historical categorizations
**When to use:** When family has LearnedPattern records
**Example:**
```ruby
def learned_pattern_examples(family, max: 3)
  # Get diverse category examples (not all from same category)
  patterns_by_category = family.learned_patterns.includes(:category).group_by(&:category)

  # Select one example per category for diversity
  examples = patterns_by_category.values.flat_map do |patterns|
    pattern = patterns.first
    {
      transaction: {
        id: "example-#{pattern.id}",
        description: pattern.merchant_name,
        amount: 0, # Amount not stored in LearnedPattern
        classification: pattern.category.expense? ? "expense" : "income"
      },
      category: pattern.category.name,
      explanation: "You've categorized #{pattern.merchant_name} as #{pattern.category.name} before"
    }
  end

  examples.take(max)
end
```

### Pattern 3: Few-Shot Prompt Formatting
**What:** Insert examples before the task in the developer_message
**When to use:** In both OpenAI and Anthropic auto_categorizer
**Example:**
```ruby
def developer_message
  examples = build_few_shot_examples(user_categories, family)

  <<~MESSAGE.strip_heredoc
    You are a transaction categorization assistant. Here are examples of how to categorize:

    #{format_examples(examples)}

    Now categorize these transactions using the same approach:

    AVAILABLE CATEGORIES: #{user_categories.map { |c| c[:name] }.join(", ")}

    TRANSACTIONS TO CATEGORIZE:
    #{format_transactions_simply}
  MESSAGE
end

def format_examples(examples)
  examples.map do |ex|
    <<~EXAMPLE
      Example:
      Transaction: #{ex[:transaction][:description]} (#{ex[:transaction][:classification]})
      Category: #{ex[:category]}

    EXAMPLE
  end.join("\n")
end
```

### Anti-Patterns to Avoid
- **Too many examples:** >10 examples bloats tokens without significant gains
- **Similar examples:** All 5 examples from "Groceries" teaches nothing about other categories
- **Stale examples:** Using old patterns that user has since corrected
- **Hardcoded user data:** Including real user transaction data in static examples (privacy concern)
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Example selection algorithm | Custom scoring | Category-based grouping + random selection | Simpler, more predictable |
| Example formatting | String interpolation | Template/heredoc patterns | Cleaner, easier to maintain |
| Token counting | Manual counting | Rails.logger.info("Prompt size: #{prompt.length}") | Monitor during implementation |
| Similarity detection | Custom embedding-based clustering | Category-based diversity is sufficient | LearnedPattern already categorized |

**Key insight:** For transaction categorization, category diversity matters more than semantic similarity. Selecting examples from different categories is more effective than finding "similar" transactions to the input.
</dont_hand_roll>

<common_pitfalls>
## Pitfall 1: Token Bloat
**What goes wrong:** Adding too many examples explodes token usage and cost
**Why it happens:** "More examples = better" intuition doesn't account for diminishing returns
**How to avoid:** Limit to 3-5 static + 0-3 dynamic examples. Monitor token counts.
**Warning signs:** Categorization cost increases 3-5x with minimal accuracy gain

## Pitfall 2: Example Homogeneity
**What goes wrong:** All examples are from the same category or similar transaction types
**Why it happens:** LearnedPatterns may be skewed toward frequent categories (e.g., lots of coffee shops)
**How to avoid:** Select at most one example per category for dynamic examples
**Warning signs:** Model consistently predicts same category for diverse inputs

## Pitfall 3: Generic Static Examples
**What goes wrong:** Static examples use merchant names like "STORE 123" that don't map to real categories
**Why it happens:** Trying to avoid privacy concerns by using fake data
**How to avoid:** Use recognizable real-world brands (Starbucks, Shell, Whole Foods) as examples
**Warning signs:** Zero-shot baseline outperforms few-shot

## Pitfall 4: Prompt Format Inconsistency
**What goes wrong:** Examples are formatted differently from the actual task input
**Why it happens:** Examples use full transaction objects, task uses simplified string format
**How to avoid:** Match example format to actual task format exactly
**Warning signs:** Model ignores examples and reverts to zero-shot behavior

## Pitfall 5: Including Explanations
**What goes wrong:** Examples include verbose explanations ("This is coffee because...")
**Why it happens:** Following general few-shot tutorials rather than classification best practices
**How to avoid:** Keep examples minimal: transaction description → category
**Warning signs:** Model starts generating explanations instead of categories
</common_pitfalls>

<code_examples>
## Code Examples

### Example 1: Static Few-Shot Examples (from OpenAI Cookbook)
```ruby
# Source: https://github.com/openai/openai-cookbook/blob/main/examples/Multiclass_classification_for_transactions.ipynb
# Adapted for Ruby codebase

STATIC_EXAMPLES = [
  {
    transaction: { id: "ex-1", description: "WHOLE FOODS MARKET", amount: 85.42, classification: "expense" },
    category: "Groceries",
    reason: "Whole Foods is a grocery store chain"
  },
  {
    transaction: { id: "ex-2", description: "SHELL SERVICE STATION", amount: 45.00, classification: "expense" },
    category: "Gas & Fuel",
    reason: "Shell is a gas station"
  },
  {
    transaction: { id: "ex-3", description: "STARBUCKS COFFEE", amount: 6.50, classification: "expense" },
    category: "Coffee Shops",
    reason: "Starbucks is a coffee chain"
  },
  {
    transaction: { id: "ex-4", description: "NETFLIX SUBSCRIPTION", amount: 15.99, classification: "expense" },
    category: "Streaming Services",
    reason: "Netflix is a streaming subscription"
  },
  {
    transaction: { id: "ex-5", description: "CHIPOTLE MEXICAN GRILL", amount: 12.75, classification: "expense" },
    category: "Restaurants",
    reason: "Chipotle is a fast-casual restaurant"
  }
].freeze
```

### Example 2: Integrating into OpenAI AutoCategorizer
```ruby
# In app/models/provider/openai/auto_categorizer.rb

def developer_message_for_generic
  few_shot_text = build_few_shot_examples

  <<~MESSAGE.strip_heredoc
    #{few_shot_text}

    AVAILABLE CATEGORIES: #{user_categories.map { |c| c[:name] }.join(", ")}

    TRANSACTIONS TO CATEGORIZE:
    #{format_transactions_simply}

    CATEGORIZATION GUIDELINES:
    - Prefer specific subcategories over general parent categories when confident
    - Food delivery services should be categorized based on the underlying merchant type
    - Square payments (SQ *) should be inferred from the merchant name after the prefix
    - Warehouse/club stores should be categorized based on their primary purpose
    - Return "null" for generic transactions (e.g., POS terminals, wire transfers, checks, ATM withdrawals)

    IMPORTANT:
    - Use EXACT category names from the list above
    - Return "null" (as a string) if you cannot confidently match a category
    - Match expense transactions only to expense categories
    - Match income transactions only to income categories
    - Do NOT include any explanation or reasoning - only output JSON

    Respond with ONLY this JSON (no markdown code blocks, no other text):
    {"categorizations": [{"transaction_id": "...", "category_name": "..."}]}
  MESSAGE
end

def build_few_shot_examples
  return "" unless few_shot_enabled?

  examples = Provider::Concerns::FewShotExamples.new(
    user_categories: user_categories,
    family: family
  ).build

  return "" if examples.empty?

  "EXAMPLES:\n\n" + examples.map { |ex| format_example(ex) }.join("\n")
end

def format_example(example)
  "Transaction: #{example[:description]} → Category: #{example[:category]}"
end
```

### Example 3: LearnedPattern Query for Dynamic Examples
```ruby
# In app/models/provider/concerns/few_shot_examples.rb

class Provider::Concerns::FewShotExamples
  def initialize(user_categories:, family: nil)
    @user_categories = user_categories
    @family = family
  end

  def build
    examples = static_examples

    if @family && @family.learned_patterns.exists?
      examples.concat(dynamic_examples)
    end

    examples
  end

  private

  def static_examples
    # Return 3-5 hardcoded examples covering common categories
    [
      { description: "WHOLE FOODS MARKET", category: "Groceries" },
      { description: "SHELL SERVICE STATION", category: "Gas & Fuel" },
      { description: "STARBUCKS", category: "Coffee Shops" },
      { description: "NETFLIX", category: "Streaming Services" },
      { description: "CHIPOTLE", category: "Fast Food" }
    ].select { |ex| category_exists?(ex[:category]) }
  end

  def dynamic_examples
    # Get one example per category for diversity
    @family.learned_patterns
      .includes(:category)
      .group_by(&:category)
      .values
      .sample(3) # Randomly select 3 categories
      .map(&:first) # Take first pattern from each category
      .map { |pattern| { description: pattern.merchant_name, category: pattern.category.name } }
  end

  def category_exists?(name)
    @user_categories.any? { |c| c[:name] == name }
  end
end
```

### Example 4: Minimal Example Format (Recommended)
```ruby
# Keep examples concise - transaction → category mapping only

# GOOD: Minimal format
"Transaction: WHOLE FOODS MARKET → Category: Groceries"

# AVOID: Verbose explanations
"Transaction: WHOLE FOODS MARKET is a grocery store chain so the category is Groceries"
```
</code_examples>

<sota_updates>
## State of the Art (2024-2025)

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Zero-shot only | Few-shot (3-5 examples) | 2023-2024 | Significant accuracy improvement |
| Custom fine-tuning | Few-shot + fine-tuning | 2024 | Few-shot sufficient for most cases |
| Generic examples | Domain-specific examples | Ongoing | Transaction-specific examples work better |

**New tools/patterns to consider:**
- **OpenAI Responses API (2024):** Native JSON schema support replaces older chat completions format
- **Anthropic Tool Use:** Alternative to OpenAI's structured outputs

**Deprecated/outdated:**
- **Fine-tuning for categorization (simple cases):** Few-shot is now sufficient for most classification tasks
- **Embedding-based classification:** For this use case, few-shot prompts are simpler and equally effective
</sota_updates>

<open_questions>
## Open Questions

1. **Optimal example count for this specific domain**
   - What we know: Research suggests 3-5 examples, but transaction categorization may differ
   - What's unclear: Whether 5 static + 3 dynamic examples provides better results than 3 static + 3 dynamic
   - Recommendation: Start with 3 static + up to 3 dynamic, iterate based on results

2. **LearnedPattern quality filtering**
   - What we know: LearnedPattern stores all user-confirmed categorizations
   - What's unclear: Whether some patterns are "better" examples than others (e.g., frequently used vs. recent)
   - Recommendation: Use random selection across categories for now, add recency weighting if needed

3. **Feature flag for few-shot**
   - What we know: Need to test accuracy improvement
   - What's unclear: Whether to make few-shot opt-in via Setting or default-on
   - Recommendation: Implement as default-on, add Setting model flag if rollback needed
</open_questions>

<sources>
## Sources

### Primary (HIGH confidence)
- [OpenAI Cookbook - Multiclass Classification for Transactions](https://github.com/openai/openai-cookbook/blob/main/examples/Multiclass_classification_for_transactions.ipynb) - Official example notebook for transaction categorization with zero-shot and few-shot approaches
- [OpenAI Prompt Engineering Guide](https://platform.openai.com/docs/guides/prompt-engineering) - Official prompt engineering strategies
- [Few-Shot Prompting - Prompting Guide](https://www.promptingguide.ai/techniques/fewshot) - Comprehensive few-shot techniques

### Secondary (MEDIUM confidence)
- [DigitalOcean - Few-Shot Prompting Techniques](https://www.digitalocean.com/community/tutorials/_few-shot-prompting-techniques-examples-best-practices) - Best practices for few-shot setups (April 2025)
- [Few-Shot Prompting Techniques & Best Practices](https://www.vktr.com/ai-upskilling/a-guide-to-few-shot-prompting/) - Example selection strategies

### Tertiary (LOW confidence - needs validation)
- [Skill-Based Few-Shot Selection for In-Context Learning](https://aclanthology.org/anthology-files/pdf/emnlp/2023.emnlp-main.831.pdf) - Research on diversity vs. similarity trade-off (verified against OpenAI Cookbook approach)
- [Investigation of Few-Shot Selection Strategies in LLM](https://arxiv.org/html/2410.10756v1) - Recent research on example selection (October 2024)

### Codebase Analysis
- `app/models/provider/openai/auto_categorizer.rb` - Current OpenAI implementation (instructions, developer_message, json_schema)
- `app/models/provider/anthropic/auto_categorizer.rb` - Current Anthropic implementation (parallel structure)
- `app/models/learned_pattern.rb` - LearnedPattern model structure
- `app/models/family.rb` - Family API for learned_patterns has_many association
- `app/models/family/auto_categorizer.rb` - AutoCategorizer integration point
</sources>

<metadata>
## Metadata

**Research scope:**
- Core technology: Few-shot prompt engineering for LLM classification
- Ecosystem: OpenAI Responses API, Anthropic Messages API, LearnedPattern model
- Patterns: Two-tier example construction, example selection, prompt formatting
- Pitfalls: Token bloat, example homogeneity, format inconsistency

**Confidence breakdown:**
- Standard stack: HIGH - verified with OpenAI Cookbook and official docs
- Architecture: HIGH - based on existing codebase patterns and proven few-shot approaches
- Pitfalls: HIGH - documented in research and observable in similar implementations
- Code examples: HIGH - adapted from official OpenAI Cookbook and existing codebase

**Research date:** 2026-01-11
**Valid until:** 2025-02-11 (30 days - LLM prompt patterns stable but evolving)
</metadata>

---

*Phase: 29-improve-categorization-prompts*
*Research completed: 2026-01-11*
*Ready for planning: yes*
