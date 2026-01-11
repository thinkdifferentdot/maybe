# Phase 18: Fuzzy Category & Merchant Matching - Research

**Researched:** 2025-01-11
**Domain:** String similarity algorithms for Ruby (category/merchant matching)
**Confidence:** HIGH

<research_summary>
## Summary

Researched fuzzy string matching approaches for porting OpenAI's `fuzzy_name_match` and `find_fuzzy_category_match` methods to Anthropic's AutoCategorizer. The current OpenAI implementation uses a custom rules-based approach with hardcoded synonyms and substring matching.

The research revealed:
1. **No external gem dependency required** - Ruby has sufficient built-in string operations for the current use case
2. **Industry-standard algorithms** - Levenshtein distance and Dice's coefficient are the most common approaches
3. **Best practices** - Use normalized similarity ratios (not absolute distances), typically 80-90% threshold
4. **Available Ruby gems** - `amatch` (C-extension, fast), `fuzzy_match` (pure Ruby, Dice's coefficient)

**Primary recommendation:** Port the existing OpenAI implementation to Anthropic first, then consider adding a proper Levenshtein distance calculation for threshold-based matching as an improvement. The current rules-based approach works for the hardcoded synonyms but doesn't handle arbitrary typos.
</research_summary>

<standard_stack>
## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Ruby stdlib | Built-in | String operations | No external dependency needed for basic fuzzy matching |
| `amatch` | 0.3.1 | Levenshtein distance (C extension) | Fast, production-tested, pure C implementation |
| `fuzzy_match` | 1.4.0 | Dice's coefficient matching | Pure Ruby, uses Dice's Coefficient with Levenshtein tiebreaker |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| PostgreSQL `pg_trgm` | Extension | Database-level trigram matching | When searching large datasets at DB level |
| `string-similarity` | 2.1.0 | Cosine similarity + Levenshtein | When you need multiple similarity algorithms |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom rules | `amatch` gem | Custom rules work for known synonyms; Levenshtein handles arbitrary typos |
| Custom rules | `fuzzy_match` gem | `fuzzy_match` uses Dice's Coefficient which works well for variable-length strings |
| Pure Ruby | C extensions | C extensions faster but require native compilation |

**Installation (if adding gems):**
```bash
# For Levenshtein distance (C extension, fast)
gem "amatch", "~> 0.3.1"

# For Dice's coefficient (pure Ruby)
gem "fuzzy_match", "~> 1.0"
```
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Current OpenAI Implementation

The existing `Provider::Openai::AutoCategorizer` has two fuzzy matching methods:

**1. `find_fuzzy_category_match` (lines 294-312)**
```ruby
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
```

**2. `fuzzy_name_match?` (lines 314-340)**
```ruby
def fuzzy_name_match?(input, category)
  variations = {
    "gas" => [ "gas & fuel", "gas and fuel", "fuel", "gasoline" ],
    "restaurants" => [ "restaurant", "dining", "food" ],
    "groceries" => [ "grocery", "supermarket", "food store" ],
    # ... more mappings
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

### Recommended: Levenshtein-Based Matching (Improvement)

```ruby
# Simple pure-Ruby Levenshtein implementation
def levenshtein_distance(str1, str2)
  str1 = str1.downcase
  str2 = str2.downcase

  matrix = Array.new(str2.length + 1) { |i| Array.new(str1.length + 1) { |j| j } }
  matrix.each_with_index { |row, i| row[0] = i }

  str2.chars.each_with_index do |char2, i|
    str1.chars.each_with_index do |char1, j|
      cost = char1 == char2 ? 0 : 1
      matrix[i + 1][j + 1] = [
        matrix[i][j + 1] + 1,     # deletion
        matrix[i + 1][j] + 1,     # insertion
        matrix[i][j] + cost       # substitution
      ].min
    end
  end

  matrix[str2.length][str1.length]
end

# Similarity ratio (0-1 scale)
def similarity_ratio(str1, str2)
  max_len = [str1.length, str2.length].max
  return 1.0 if max_len == 0

  distance = levenshtein_distance(str1, str2)
  1.0 - (distance.to_f / max_len)
end

# Use with threshold (typically 0.80-0.90)
def find_fuzzy_category_match(category_name, threshold: 0.85)
  input_str = category_name.to_s.downcase

  user_categories.each do |cat|
    cat_name = cat[:name].to_s.downcase

    # Try exact match first
    return cat[:name] if input_str == cat_name

    # Try substring match
    if input_str.include?(cat_name) || cat_name.include?(input_str)
      return cat[:name]
    end

    # Try Levenshtein similarity
    similarity = similarity_ratio(input_str, cat_name)
    return cat[:name] if similarity >= threshold
  end

  nil
end
```

### Pattern 2: Using `amatch` Gem (Performance)
```ruby
require 'amatch'

def find_fuzzy_category_match(category_name, threshold: 0.85)
  m = Amatch::Levenshtein.new(category_name.to_s.downcase)

  user_categories.each do |cat|
    cat_name = cat[:name].to_s.downcase
    distance = m.match(cat_name)
    max_len = [category_name.length, cat_name.length].max

    similarity = 1.0 - (distance.to_f / max_len)
    return cat[:name] if similarity >= threshold
  end

  nil
end
```

### Anti-Patterns to Avoid
- **Absolute distance thresholds:** Don't use fixed distance (e.g., "within 2 edits") - normalize by string length
- **Too-low thresholds:** Below 70% causes many false positives
- **Too-high thresholds:** Above 95% misses legitimate variations
- **Ignoring case/punctuation:** Always normalize before comparing
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Levenshtein distance | Custom recursive implementation | `amatch` gem (C extension) or pure Ruby iterative | C extension 10-100x faster; iterative avoids stack overflow |
| Complex similarity | Jaro-Winkler from scratch | `fuzzy_match` or `string-similarity` gems | Edge cases in transposition handling |
| Large dataset matching | Ruby-side iteration | PostgreSQL `pg_trgm` extension | Database-level matching with indexes |
| Multiple algorithms | Your own library | Existing gems with battle-tested implementations | They've solved edge cases you haven't thought of |

**Key insight:** The current OpenAI implementation IS hand-rolled rules-based matching. It works for the hardcoded synonyms but fails on arbitrary typos. Adding proper Levenshtein distance would improve it significantly.
</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

### Pitfall 1: Non-Normalized Thresholds
**What goes wrong:** Using absolute Levenshtein distance (e.g., "within 2 characters") treats "cat" vs "cart" (distance 1) same as "category" vs "categories" (distance 1)
**Why it happens:** Levenshtein distance grows with string length
**How to avoid:** Always use normalized similarity ratio: `1 - (distance / max_length)`
**Warning signs:** Short words always match, long words never match

### Pitfall 2: Too Many False Positives
**What goes wrong:** Threshold too low causes "restaurants" to match "restroom" (high overlap)
**Why it happens:** Substring matching and low thresholds (~70%) match coincidental character sequences
**How to avoid:** Use 80-90% threshold for categories, consider word boundaries
**Warning signs:** Users reporting wrong categorizations

### Pitfall 3: Ignoring Common Variations
**What goes wrong:** "Coffee Shop" doesn't match "coffee shop" or "coffee  shop" (double space)
**Why it happens:** Case sensitivity, extra spaces, punctuation not normalized
**How to avoid:** Always `downcase.strip.squeeze(" ")` before comparing
**Warning signs:** Exact matches failing

### Pitfall 4: Performance on Large Category Lists
**What goes wrong:** O(n×m) comparisons slow down when users have 50+ categories
**Why it happens:** Ruby-side iteration over all categories for each transaction
**How to avoid:** Consider early exit on high-confidence matches, pre-filter by first letter/length
**Warning signs:** Categorization API slow response times
</common_pitfalls>

<code_examples>
## Code Examples

### Normalization Before Matching
```ruby
# Source: OpenAI AutoCategorizer pattern
def normalize_for_matching(str)
  str.to_s.downcase.gsub(/[^a-z0-9]/, "")
end
```

### Current OpenAI Synonym Matching
```ruby
# Source: app/models/provider/openai/auto_categorizer.rb:314-340
variations = {
  "gas" => ["gas & fuel", "gas and fuel", "fuel", "gasoline"],
  "restaurants" => ["restaurant", "dining", "food"],
  "groceries" => ["grocery", "supermarket", "food store"],
  "streaming" => ["streaming services", "streaming service"],
  "rideshare" => ["ride share", "ride-share", "uber", "lyft"],
  "coffee" => ["coffee shops", "coffee shop", "cafe"],
  "fast food" => ["fastfood", "quick service"],
  "gym" => ["gym & fitness", "fitness", "gym and fitness"],
  "flights" => ["flight", "airline", "airlines", "airfare"],
  "hotels" => ["hotel", "lodging", "accommodation"]
}
```

### Levenshtein Similarity with Threshold
```ruby
# Source: Standard algorithm implementation
def similar_enough?(str1, str2, threshold: 0.85)
  return true if str1 == str2

  # Normalize
  s1 = str1.to_s.downcase.gsub(/[^a-z0-9]/, "")
  s2 = str2.to_s.downcase.gsub(/[^a-z0-9]/, "")

  # Substring check (fast path)
  return true if s1.include?(s2) || s2.include?(s1)

  # Length check - strings too different can't be similar
  max_len = [s1.length, s2.length].max
  return false if (s1.length - s2.length).abs > max_len * (1 - threshold)

  # Levenshtein distance
  distance = levenshtein_distance(s1, s2)
  similarity = 1.0 - (distance.to_f / max_len)

  similarity >= threshold
end
```

### Integration with normalize_category_name
```ruby
# Source: OpenAI AutoCategorizer pattern (lines 273-292)
def normalize_category_name(category_name)
  normalized = category_name.to_s.strip
  return nil if normalized.empty? || normalized == "null"

  # Try exact match first
  exact_match = user_categories.find { |c| c[:name] == normalized }
  return exact_match[:name] if exact_match

  # Try case-insensitive match
  case_insensitive_match = user_categories.find { |c| c[:name].to_s.downcase == normalized.downcase }
  return case_insensitive_match[:name] if case_insensitive_match

  # Try partial/fuzzy match (for common variations)
  fuzzy_match = find_fuzzy_category_match(normalized)
  return fuzzy_match if fuzzy_match

  # Return normalized string if no match found (will be treated as uncategorized)
  normalized
end
```
</code_examples>

<sota_updates>
## State of the Art (2024-2025)

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Pure custom rules | Hybrid: rules + Levenshtein | Ongoing | Levenshtein handles arbitrary typos; rules handle known synonyms |
| Absolute distance | Normalized similarity ratio | Industry standard | Consistent behavior across string lengths |

**New tools/patterns to consider:**
- **Hybrid matching:** Combine substring matching (fast) with Levenshtein (accurate)
- **Two-pass approach:** Quick exact/substring match first, then expensive Levenshtein only for remaining
- **Configurable thresholds:** Let users tune sensitivity per their data quality

**Deprecated/outdated:**
- **Pure recursive Levenshtein:** Causes stack overflow on long strings; use iterative
</sota_updates>

<open_questions>
## Open Questions

1. **Threshold value**
   - What we know: Industry standard is 80-90% for general string matching
   - What's unclear: What threshold works best for Sure's specific category names
   - Recommendation: Start with 85%, add configuration option for tuning

2. **Performance impact**
   - What we know: Levenshtein is O(n×m) per comparison
   - What's unclear: Whether current category list sizes (typically 10-30) make this a problem
   - Recommendation: Profile before optimizing; early exit on high-confidence matches helps

3. **Gem dependency**
   - What we know: `amatch` provides fast C implementation, `fuzzy_match` provides pure Ruby
   - What's unclear: Whether the improvement justifies adding a dependency
   - Recommendation: Port pure Ruby implementation first, add gem only if needed for performance
</open_questions>

<sources>
## Sources

### Primary (HIGH confidence)
- [flori/amatch](https://github.com/flori/amatch) - C extension Levenshtein implementation for Ruby
- [seamusabshere/fuzzy_match](https://github.com/seamusabshere/fuzzy_match) - Pure Ruby fuzzy matching using Dice's Coefficient
- [Amatch Levenshtein Documentation](https://rubydoc.info/gems/amatch/0.3.1/Amatch/Levenshtein) - Official documentation

### Secondary (MEDIUM confidence)
- [Stack Overflow: Fast fuzzy search in Ruby](https://stackoverflow.com/questions/20012873/fast-fuzzy-approximate-search-in-ruby) - Trigrams + Levenshtein hybrid approach
- [Stack Overflow: Threshold for similar strings](https://stackoverflow.com/questions/3340551/how-can-i-create-a-threshold-for-similar-strings-using-levenshtein-distance-and) - Threshold selection discussion
- [Rails with Postgres - Fuzzy Searches](https://btihen.dev/posts/ruby/rails_7_2_fuzzy_search/) - PostgreSQL pg_trgm integration
- [Baeldung: String Similarity Metrics](https://www.baeldung.com/cs/string-similarity-edit-distance) - Algorithm comparison

### Tertiary (LOW confidence - needs validation)
- [Wikipedia: Levenshtein distance](https://en.wikipedia.org/wiki/Levenshtein_distance) - Algorithm definition
- [Medium: Introduction to Fuzzy String Matching](https://medium.com/@julientregoat/an-introduction-to-fuzzy-string-matching-178805cca2ab) - Overview of algorithms
</sources>

<metadata>
## Metadata

**Research scope:**
- Core technology: Ruby string matching algorithms
- Ecosystem: `amatch`, `fuzzy_match`, Ruby stdlib
- Patterns: Levenshtein distance, Dice's coefficient, substring matching
- Pitfalls: Threshold tuning, normalization, performance

**Confidence breakdown:**
- Standard stack: HIGH - Verified gems are stable and well-documented
- Architecture: HIGH - Analyzed existing OpenAI implementation code
- Pitfalls: HIGH - Cross-referenced multiple sources on best practices
- Code examples: HIGH - Based on actual existing code in the codebase

**Research date:** 2025-01-11
**Valid until:** 2025-02-11 (30 days - stable algorithms, unlikely to change)
</metadata>

---

*Phase: 18-fuzzy-category-merchant-matching*
*Research completed: 2025-01-11*
*Ready for planning: yes*
