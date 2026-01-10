# Phase 10: Settings & Config - Research

**Researched:** 2026-01-10
**Domain:** Rails settings patterns with rails-settings-cached gem
**Confidence:** HIGH

<research_summary>
## Summary

Researched Rails application settings patterns for implementing auto-categorization toggles. The Sure codebase uses `rails-settings-cached` (v2.x), a well-maintained gem with 1.1k+ stars and 2.3k+ dependent repositories. The codebase already has established patterns for boolean settings, form handling, and settings UI.

Key finding: The codebase has all necessary infrastructure — `DS::Toggle` component, `StyledFormBuilder` with toggle method, and proven patterns from v1.0 Anthropic integration. New settings should follow the exact same patterns: declare boolean fields in `Setting.rb`, use `styled_form_with` with `form.toggle`, and handle updates in the controller.

**Primary recommendation:** Use existing `rails-settings-cached` patterns from v1.0. Add three boolean fields with default: false, create dedicated settings partial, add nav item, and update controller. No new dependencies needed.
</research_summary>

<standard_stack>
## Standard Stack

The established libraries/tools for Rails settings in the Sure codebase:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| rails-settings-cached | 2.9.6 | Global settings storage | Proven gem with caching, validations, field types |
| Rails | 7.x | Framework settings patterns | Standard ActiveRecord patterns |
| Hotwire (Turbo) | Built-in | Form handling | Server-side rendering with turbo frames |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| DS::Toggle | Custom | Boolean toggle component | All boolean field UI |
| StyledFormBuilder | Custom | Form builder with toggle method | All settings forms |
| auto-submit-form controller | Custom | Auto-save on blur | Optional for immediate save UX |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| rails-settings-cached | Anyway Config | rails-settings-cached is already integrated |
| DS::Toggle | Primer ToggleSwitch | DS::Toggle matches existing design system |
| Custom controller | ActiveModel::Validations | Current pattern works well |

**Installation:**
```bash
# Already installed - Gemfile includes:
gem "rails-settings-cached", "~> 2.9"
```
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Recommended Project Structure
```
app/
├── models/
│   └── setting.rb              # Add new boolean fields here
├── controllers/
│   └── settings/
│       └── auto_categorization_controller.rb  # NEW controller
├── views/
│   └── settings/
│       ├── auto_categorization/
│       │   └── show.html.erb    # NEW settings page
│       ├── _settings_nav.html.erb  # UPDATE: add nav item
│       └── auto_categorization/  # NEW partials directory
│           └── _settings.html.erb
config/
└── locales/
    └── views/
        └── settings/
            └── auto_categorization/
                └── en.yml        # NEW locale file
```

### Pattern 1: Boolean Field Declaration
**What:** Declare boolean settings with default: false in Setting model
**When to use:** Any on/off toggle setting
**Example:**
```ruby
# Source: app/models/setting.rb (existing pattern)
class Setting < RailsSettings::Base
  cache_prefix { "v1" }

  # Existing pattern from v1.0
  field :require_email_confirmation, type: :boolean, default: false

  # New fields for Phase 10
  field :ai_categorize_on_import, type: :boolean, default: false
  field :ai_categorize_on_sync, type: :boolean, default: false
  field :ai_categorize_on_ui_action, type: :boolean, default: false
end
```

### Pattern 2: Settings Controller with Update Action
**What:** Controller that handles setting updates with permit and assignment
**When to use:** Any settings form submission
**Example:**
```ruby
# Source: app/controllers/settings/hostings_controller.rb (existing pattern)
class Settings::AutoCategorizationController < ApplicationController
  layout "settings"

  before_action :ensure_admin

  def show
    @breadcrumbs = [
      ["Home", root_path],
      ["Auto-Categorization", nil]
    ]
  end

  def update
    if auto_categorization_params.key?(:ai_categorize_on_import)
      Setting.ai_categorize_on_import = auto_categorization_params[:ai_categorize_on_import]
    end

    if auto_categorization_params.key?(:ai_categorize_on_sync)
      Setting.ai_categorize_on_sync = auto_categorization_params[:ai_categorize_on_sync]
    end

    if auto_categorization_params.key?(:ai_categorize_on_ui_action)
      Setting.ai_categorize_on_ui_action = auto_categorization_params[:ai_categorize_on_ui_action]
    end

    redirect_to settings_auto_categorization_path, notice: t(".success")
  end

  private
    def auto_categorization_params
      params.require(:setting).permit(:ai_categorize_on_import, :ai_categorize_on_sync, :ai_categorize_on_ui_action)
    end

    def ensure_admin
      redirect_to settings_auto_categorization_path, alert: t(".not_authorized") unless Current.user.admin?
    end
end
```

### Pattern 3: Form with Toggle Component
**What:** Use styled_form_with and DS::Toggle for boolean settings
**When to use:** Settings page with toggle switches
**Example:**
```erb
<%# Source: app/views/settings/auto_categorization/show.html.erb %>
<div class="space-y-6">
  <div>
    <h1 class="text-2xl font-bold"><%= t(".page_title") %></h1>
    <p class="text-secondary mt-1"><%= t(".page_subtitle") %></p>
  </div>

  <%= styled_form_with model: Setting.new,
                       url: settings_auto_categorization_path,
                       method: :patch,
                       class: "space-y-4" do |form| %>

    <%= form.toggle :ai_categorize_on_import,
                    label: t(".import_label"),
                    checked: Setting.ai_categorize_on_import? %>

    <%= form.toggle :ai_categorize_on_sync,
                    label: t(".sync_label"),
                    checked: Setting.ai_categorize_on_sync? %>

    <%= form.toggle :ai_categorize_on_ui_action,
                    label: t(".ui_action_label"),
                    checked: Setting.ai_categorize_on_ui_action? %>

    <%= form.submit t(".save_button") %>
  <% end %>
</div>
```

### Pattern 4: Navigation Integration
**What:** Add nav item to settings sections
**When to use:** New settings page
**Example:**
```erb
<%# Source: app/views/settings/_settings_nav.html.erb %>
<%
# Add to "transactions_section" items array:
{ label: t(".auto_categorization_label"), path: settings_auto_categorization_path, icon: "sparkles" }
%>
```

### Anti-Patterns to Avoid
- **Using checkboxes instead of toggles:** DS::Toggle provides better UX for boolean settings
- **Skipping permission checks:** All settings changes should require admin privileges
- **Not using styled_form_with:** Breaks design system consistency
- **Ignoring ENV variable support:** Settings should always fallback to ENV (future-proofing)
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Settings storage | Custom table/model | rails-settings-cached | Handles caching, type conversion, validations |
| Boolean UI | Custom checkbox/toggle | DS::Toggle component | Matches design system, accessible |
| Form builder | Standard Rails form helpers | StyledFormBuilder | Consistent styling, built-in toggle method |
| Validation logic | Custom validation methods | Rails validations + Setting::ValidationError | Follows Rails conventions, already used in codebase |

**Key insight:** The rails-settings-cached gem handles the complex parts: caching, type conversion (string to boolean), validations, and default values. Building custom settings logic introduces bugs with race conditions, cache invalidation, and type coercion.
</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

### Pitfall 1: Boolean Handling with Strings
**What goes wrong:** HTML forms send "1"/"0" strings, but Rails expects true/false
**Why it happens:** Web browsers don't send boolean values
**How to avoid:** rails-settings-cached auto-converts "1"/"0" to true/false for type: :boolean fields
**Warning signs:** Settings always return true or stored as strings

### Pitfall 2: Missing Question Mark Predicate
**What goes wrong:** Calling `Setting.some_boolean` returns 1/0 instead of true/false
**Why it happens:** Forgetting the `?` predicate method
**How to avoid:** Always use `Setting.ai_categorize_on_import?` for boolean checks
**Warning signs:** Conditional logic behaves unexpectedly

### Pitfall 3: Cache Invalidation
**What goes wrong:** Settings changes don't take effect until cache expires
**Why it happens:** rails-settings-cached caches values for performance
**How to avoid:** Gem auto-clears cache on update. Use `Setting.clear_cache` in tests.
**Warning signs:** Old values returned after update

### Pitfall 4: Accessibility with Toggles
**What goes wrong:** Toggle switches aren't keyboard accessible or screen reader friendly
**Why it happens:** Using divs instead of proper form elements
**How to avoid:** DS::Toggle uses proper checkbox + label pattern with sr-only class
**Warning signs:** Can't tab to toggle, screen reader doesn't announce state

### Pitfall 5: Permission Bypass
**What goes wrong:** Non-admin users can change settings
**Why it happens:** Forgetting before_action :ensure_admin
**How to avoid:** Always include admin check in settings controllers
**Warning signs:** Settings changed unexpectedly
</common_pitfalls>

<code_examples>
## Code Examples

Verified patterns from Sure codebase:

### Accessing Boolean Settings
```ruby
# Source: app/models/setting.rb (existing pattern)
Setting.require_email_confirmation  # Returns true/false
Setting.require_email_confirmation? # Preferred boolean predicate
Setting.require_email_confirmation = true  # Set to true
Setting.require_email_confirmation = "0"   # Converts to false
```

### Toggle in Form (StyledFormBuilder)
```erb
<%# Source: app/helpers/styled_form_builder.rb:47-63 %>
<%# The toggle method renders DS::Toggle component %>
<%= form.toggle :field_name,
                label: "Display Label",
                checked: Setting.field_name? %>

<%# Optional: add auto-save behavior %>
<%= form.toggle :field_name,
                label: "Display Label",
                checked: Setting.field_name?,
                data: {
                  controller: "auto-submit-form",
                  "auto-submit-form-trigger-event-value": "change"
                } %>
```

### DS::Toggle Component Direct Usage
```erb
<%# Source: app/components/DS/toggle.rb and .html.erb %>
<%= render DS::Toggle.new(
  id: "unique-id",
  name: "setting[field_name]",
  checked: true,
  disabled: false
) %>
```

### Settings Nav Structure
```erb
<%# Source: app/views/settings/_settings_nav.html.erb %>
<%
nav_sections = [
  {
    header: t(".transactions_section_title"),
    items: [
      { label: t(".categories_label"), path: categories_path, icon: "shapes" },
      { label: t(".auto_categorization_label"), path: settings_auto_categorization_path, icon: "sparkles" },
      # ... more items
    ]
  }
]
%>
```
</code_examples>

<sota_updates>
## State of the Art (2024-2025)

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual settings table | rails-settings-cached 2.x | 2023 | Built-in caching, validations, type conversion |
| Scoped settings removed | Use serialize on models | 2.x redesign | Simpler architecture for per-user settings |
| No validations | Built-in Rails validations | 2.3+ | Can validate settings directly |

**New tools/patterns to consider:**
- **Validations in field declaration:** `field :name, validates: { presence: true }` (2.3+)
- **Readonly fields:** Prevent UI from changing critical settings
- **Custom field types:** Can define custom types like `type: :yes_no` (2.9.0+)

**Deprecated/outdated:**
- **Scoped settings (0.x):** Removed in 2.x, use ActiveRecord::AttributeMethods::Serialization instead
- **Manual cache clearing:** Gem handles this automatically on updates
</sota_updates>

<open_questions>
## Open Questions

1. **Route naming**
   - What we know: Settings pages use `settings_{feature}_path` pattern
   - What's unclear: Should route be `settings_auto_categorization` or `settings_ai_categorization`?
   - Recommendation: Use `auto_categorization` for clarity and consistency with user-facing language

2. **Admin-only vs per-user**
   - What we know: Existing settings (hosting) are admin-only
   - What's unclear: Should these toggles be family-wide (admin) or per-user preferences?
   - Recommendation: Family-wide (admin-only) for v1.1. Auto-categorization costs money and affects all transactions.

3. **Navigation placement**
   - What we know: Settings has sections: General, Transactions, Advanced, More
   - What's unclear: Should Auto-Categorization be in Transactions or Advanced section?
   - Recommendation: Transactions section — it's transaction-related functionality
</open_questions>

<sources>
## Sources

### Primary (HIGH confidence)
- [huacnlee/rails-settings-cached GitHub](https://github.com/huacnlee/rails-settings-cached) - Full gem documentation, usage patterns
- [rails-settings-cached CHANGELOG](https://github.com/huacnlee/rails-settings-cached/blob/main/CHANGELOG.md) - Version history and features
- Sure codebase - app/models/setting.rb, app/helpers/styled_form_builder.rb, app/components/DS/toggle.rb

### Secondary (MEDIUM confidence)
- [Easy toggleable boolean in Ruby on Rails](https://dev.to/gon/easy-toggleable-boolean-in-ruby-on-rails-56kd) - Verified pattern matches codebase
- [ToggleSwitch Guidelines (NNGroup)](https://www.nngroup.com/articles/toggle-switch-guidelines/) - UX best practices
- [Primer ToggleSwitch component](https://primer.style/product/getting-started/rails/components/toggle_switch) - Verified DS::Toggle follows similar patterns

### Tertiary (LOW confidence - needs validation)
- None - all findings verified against codebase or official sources
</sources>

<metadata>
## Metadata

**Research scope:**
- Core technology: rails-settings-cached 2.x, Rails 7 settings patterns
- Ecosystem: DS::Toggle, StyledFormBuilder, Hotwire/Turbo forms
- Patterns: Boolean field declaration, settings controller, navigation structure
- Pitfalls: Boolean conversion, caching, accessibility

**Confidence breakdown:**
- Standard stack: HIGH - gem is well-documented and integrated
- Architecture: HIGH - patterns verified in codebase from v1.0
- Pitfalls: HIGH - documented in gem docs and Rails issues
- Code examples: HIGH - taken directly from Sure codebase

**Research date:** 2026-01-10
**Valid until:** 2026-02-10 (30 days - stable Rails/gem ecosystem)
</metadata>

---

*Phase: 10-settings-config*
*Research completed: 2026-01-10*
*Ready for planning: yes*
