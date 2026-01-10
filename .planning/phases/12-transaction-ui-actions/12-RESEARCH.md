# Phase 12: Transaction UI Actions - Research

**Researched:** 2026-01-10
**Domain:** Rails Hotwire/Turbo inline UI with AI categorization
**Confidence:** HIGH

<research_summary>
## Summary

This phase adds user-triggered AI categorization to the transaction UI—both individual quick-categorize buttons and bulk batch processing. The research confirms this is a standard Rails + Hotwire pattern using existing infrastructure, not a niche domain requiring new libraries.

The existing codebase has all the building blocks:
- `Family::AutoCategorizer` handles AI categorization with both OpenAI and Anthropic
- `bulk_select_controller.js` manages multi-row selection with contextual toolbar
- Turbo Streams provide inline updates without page reloads
- `DS::Dialog` components handle modals and confirmations
- `LlmUsage.estimate_auto_categorize_cost` provides cost estimates

**Primary recommendation:** Extend existing bulk action patterns with new AI categorization endpoints. Use Turbo Streams for inline updates and confidence display. Re-use cost estimation from rules confirmation UI.
</research_summary>

<standard_stack>
## Standard Stack

### Core (Already Installed)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Rails | 7.2+ | Full-stack framework | Existing app foundation |
| Hotwire (Turbo) | Latest | Inline UI updates | Standard Rails 7+ approach |
| Stimulus | Latest | JavaScript controllers | Handles interactive UI state |
| DS::Dialog | Custom | Modal/drawer components | Existing design system |

### Supporting (Already Installed)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| bulk_select_controller.js | Custom | Multi-row selection | Reuse for bulk AI categorization |
| confirm_dialog_controller.js | Custom | Custom confirm dialogs | Low-confidence confirmations |
| LlmUsage | Existing | Cost estimation | Show API cost before bulk operations |

**No new installations required.**
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Recommended Project Structure
```
app/
├── controllers/
│   └── transactions/
│       └── ai_categorizations_controller.rb  # New: Individual + bulk endpoints
├── models/
│   └── family/
│       └── auto_categorizer.rb               # Existing: AI categorization logic
├── javascript/
│   └── controllers/
│       └── ai_categorize_controller.js       # New: Button states, loading, feedback
├── views/
│   └── transactions/
│       ├── _transaction.html.erb             # Modify: Add AI categorize button
│       └── _selection_bar.html.erb           # Modify: Add AI bulk action button
└── components/
    └── DS/
        └── dialog.rb                          # Existing: Use for confirmations
```

### Pattern 1: Turbo Stream Inline Updates
**What:** Replace DOM elements without page reload using `turbo_stream.replace`
**When to use:** Any inline UI update that needs to feel instant
**Example:**
```ruby
# From existing TransactionCategoriesController
respond_to do |format|
  format.turbo_stream do
    render turbo_stream: [
      turbo_stream.replace(
        dom_id(transaction, :category_menu),
        partial: "categories/menu",
        locals: { transaction: transaction }
      ),
      *flash_notification_stream_items
    ]
  end
end
```

### Pattern 2: Stimulus Controller for Loading States
**What:** Use Stimulus to manage button states (loading → success/error)
**When to use:** Any async action triggered from UI
**Example:**
```javascript
// Pattern from existing controllers
export default class extends Controller {
  static targets = ["button"];
  static values = { transactionId: String };

  async categorize() {
    this.setLoadingState();

    try {
      const response = await this.fetchCategorization();
      this.handleSuccess(response);
    } catch (error) {
      this.handleError(error);
    }
  }

  setLoadingState() {
    this.buttonTarget.disabled = true;
    this.buttonTarget.innerHTML = "Categorizing...";
  }
}
```

### Pattern 3: Bulk Actions with Hidden Form Inputs
**What:** Dynamically add hidden inputs to forms before submission
**When to use:** Bulk operations on selected items
**Example:**
```javascript
// From existing bulk_select_controller.js
_addHiddenFormInputsForSelectedIds(form, paramName, transactionIds) {
  this._resetFormInputs(form, paramName);

  transactionIds.forEach((id) => {
    const input = document.createElement("input");
    input.type = "hidden";
    input.name = paramName;
    input.value = id;
    form.appendChild(input);
  });
}
```

### Anti-Patterns to Avoid
- **Page redirects for inline updates:** Use Turbo Streams instead
- **Direct DOM manipulation:** Go through Turbo/Stimulus patterns
- **Complex client-side state:** Keep state on server, use Turbo for updates
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| AI categorization logic | Custom API calls | `Family::AutoCategorizer` | Handles both OpenAI/Anthropic, records usage |
| Bulk selection state | Custom checkbox management | `bulk_select_controller.js` | Handles groups, pages, state sync |
| Modal dialogs | Custom HTML/CSS | `DS::Dialog` component | Accessibility, keyboard support, animations |
| Cost estimation | Manual token math | `LlmUsage.estimate_auto_categorize_cost` | Uses actual pricing data |
| Confirmation dialogs | `window.confirm()` | `confirm_dialog_controller.js` | Customizable, branded UX |
| Category menu | New dropdown | Existing `categories/menu` partial | Consistent UX |

**Key insight:** The existing infrastructure handles 90% of what's needed. Focus on wiring it together, not building new systems.
</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

### Pitfall 1: Not Handling Confidence Thresholds
**What goes wrong:** AI applies low-confidence categories that are wrong
**Why it happens:** Accepting all AI responses without filtering
**How to avoid:** Enforce confirmation for low-confidence suggestions (<60%)
**Warning signs:** Users complaining about bad categorizations

### Pitfall 2: Blocking Bulk Operations on Errors
**What goes wrong:** One failed transaction stops entire batch
**Why it happens:** Not wrapping individual operations in try/catch
**How to avoid:** Process each transaction independently, summarize failures at end
**Warning signs:** "Some transactions couldn't be categorized" messages needed

### Pitfall 3: No Loading Feedback
**What goes wrong:** Users click multiple times thinking it's not working
**Why it happens:** Not disabling buttons during async operations
**How to avoid:** Immediately disable and show loading state on button click
**Warning signs:** Duplicate API calls for same transaction

### Pitfall 4: Ignoring Existing Attribute Locks
**What goes wrong:** Re-categorizing locked transactions
**Why it happens:** Not checking `enrichable(:category_id)` scope
**How to avoid:** Always use `enrichable(:category_id)` before allowing AI changes
**Warning signs:** Users complaining AI changes their manual edits

### Pitfall 5: Forgetting Cost Transparency
**What goes wrong:** Users surprised by API costs
**Why it happens:** Not showing estimated cost before bulk operations
**How to avoid:** Display cost estimate in bulk toolbar (like rules confirmation UI)
**Warning signs:** Large unexpected LLM usage bills
</common_pitfalls>

<code_examples>
## Code Examples

### Controller Pattern: Individual AI Categorization
```ruby
# New: Transactions::AiCategorizationsController
class Transactions::AiCategorizationsController < ApplicationController
  def create
    @entry = Current.family.entries.transactions.find(params[:transaction_id])
    transaction = @entry.entryable

    categorizer = Family::AutoCategorizer.new(Current.family, transaction_ids: [transaction.id])
    modified_count = categorizer.auto_categorize

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(dom_id(transaction, :category_menu), ...),
          turbo_stream.replace("confidence_#{transaction.id}", ...),
          *flash_notification_stream_items
        ]
      end
    end
  rescue Family::AutoCategorizer::Error => e
    render turbo_stream: flash_error_stream(e.message)
  end
end
```

### Controller Pattern: Bulk AI Categorization
```ruby
# New: Transactions::BulkAiCategorizationsController
class Transactions::BulkAiCategorizationsController < ApplicationController
  def create
    transaction_ids = params[:bulk_ai_categorize][:entry_ids]
    categorizer = Family::AutoCategorizer.new(Current.family, transaction_ids: transaction_ids)

    @results = categorizer.auto_categorize_with_confidence

    respond_to do |format|
      format.turbo_stream do
        # Update each transaction row
        @results.each do |result|
          turbo_stream.replace(dom_id(result.transaction, :category_menu), ...)
        end
        # Show summary modal
        turbo_stream.append("dom_id", partial: "bulk_summary")
      end
    end
  end
end
```

### Stimulus Controller: Button Loading States
```javascript
// New: ai_categorize_controller.js
export default class extends Controller {
  static targets = ["button", "icon", "confidence"];
  static values = { transactionId: String };

  async categorize(event) {
    event.preventDefault();
    this.setLoading();

    try {
      const response = await fetch(this.url, {
        method: "POST",
        headers: { "X-CSRF-Token": this.csrfToken },
        body: JSON.stringify({ transaction_id: this.transactionIdValue })
      });

      if (!response.ok) throw new Error("Categorization failed");

      // Turbo will handle the DOM update via turbo_stream response
      this.setSuccess();
    } catch (error) {
      this.setError(error.message);
    }
  }

  setLoading() {
    this.buttonTarget.disabled = true;
    this.buttonTarget.classList.add("opacity-75", "cursor-not-allowed");
    this.iconTarget.innerHTML = `<svg class="animate-spin">...</svg>`;
  }

  setSuccess() {
    this.buttonTarget.classList.add("text-green-600");
    setTimeout(() => this.reset(), 2000);
  }
}
```

### Cost Estimation Display
```ruby
# From existing LlmUsage model
estimated_cost = LlmUsage.estimate_auto_categorize_cost(
  transaction_count: selected_count,
  category_count: Current.family.categories.count,
  model: Current.family.llm_provider
)

# Display in UI (similar to rules confirmation)
<div class="p-3 bg-blue-50 border border-blue-200 rounded-lg">
  <p class="text-sm">
    Estimated cost: ~$<%= sprintf("%.4f", estimated_cost) %>
  </p>
</div>
```
</code_examples>

<sota_updates>
## State of the Art (2024-2025)

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Rails UJS/Turbolinks | Hotwire (Turbo + Stimulus) | Rails 7 | Declarative UI, less JavaScript |
| Remote: true forms | Turbo Frames/Streams | Rails 7 | Better UX, no full page reloads |
| Client-side cost estimation | Server-side with LlmUsage model | v1.0 milestone | Centralized pricing data |

**New tools/patterns to consider:**
- **Turbo Power:** Not needed—standard Turbo Streams sufficient
- **HotwireCombobox:** Not relevant—using existing category menu

**Deprecated/outdated:**
- **Rails UJS (`remote: true`):** Use Turbo Streams instead
- **Turbolinks:** Replaced by Turbo in Rails 7+
</sota_updates>

<open_questions>
## Open Questions

1. **Confidence Threshold Value**
   - What we know: CONTEXT.md suggests ~60% threshold
   - What's unclear: Exact threshold for confirmation vs. auto-apply
   - Recommendation: Use 60% as stated, allow setting config in Phase 10

2. **Confidence Score Storage**
   - What we know: Current `AutoCategorization` returns `category_name` only
   - What's unclear: Where to store confidence score for display
   - Recommendation: Add `confidence` field to `AutoCategorization` Data, store as transaction metadata or separate table

3. **Re-categorization on Already-Categorized Transactions**
   - What we know: CONTEXT.md says button should work for re-categorization
   - What's unclear: Should this bypass `enrichable(:category_id)` check?
   - Recommendation: Yes—explicit user action should override locks, but show warning
</open_questions>

<sources>
## Sources

### Primary (HIGH confidence)
- `/app/models/family/auto_categorizer.rb` - Existing AI categorization implementation
- `/app/javascript/controllers/bulk_select_controller.js` - Bulk selection patterns
- `/app/views/transactions/_transaction.html.erb` - Transaction row structure
- `/app/views/transactions/_selection_bar.html.erb` - Bulk action bar
- `/app/controllers/transaction_categories_controller.rb` - Category update pattern
- `/app/models/llm_usage.rb` - Cost estimation logic

### Secondary (MEDIUM confidence)
- `/app/components/DS/dialog.rb` - Design system dialog component
- `/app/javascript/controllers/confirm_dialog_controller.js` - Confirmation pattern
- `/app/views/rules/confirm.html.erb` - Cost display UI reference

### Tertiary (LOW confidence - needs validation)
- Hotwire docs (https://hotwired.dev) - Standard patterns, verify against existing codebase usage
</sources>

<metadata>
## Metadata

**Research scope:**
- Core technology: Rails 7.2+ with Hotwire (Turbo + Stimulus)
- Ecosystem: Existing Sure patterns (bulk actions, Turbo Streams, DS components)
- Patterns: Inline updates, loading states, bulk operations, cost estimation
- Pitfalls: Error handling, confidence thresholds, state management

**Confidence breakdown:**
- Standard stack: HIGH - All components already exist in codebase
- Architecture: HIGH - Following established patterns from bulk updates
- Pitfalls: HIGH - Identified from existing error handling patterns
- Code examples: HIGH - Derived from actual codebase patterns

**Research date:** 2026-01-10
**Valid until:** 2026-02-10 (30 days - stable Rails/Hotwire patterns)
</metadata>

---

*Phase: 12-transaction-ui-actions*
*Research completed: 2026-01-10*
*Ready for planning: yes*
