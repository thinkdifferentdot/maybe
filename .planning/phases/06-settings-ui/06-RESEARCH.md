# Phase 6: Settings UI - Research

**Researched:** 2026-01-09
**Domain:** Rails settings UI following internal patterns
**Confidence:** HIGH

<research_summary>
## Summary

Phase 6 is a standard Rails web UI task that follows established patterns in the Sure codebase. No external library research is needed - the implementation must mirror existing OpenAI settings patterns.

The research focused on understanding the internal UI patterns used in Sure's settings pages:
1. How settings forms are structured (styled_form_with, auto-submit-form)
2. How provider selection works (exchange rate/securities provider pattern)
3. How ENV vs database settings are handled
4. How API keys are masked and preserved
5. What localization keys to use

**Primary recommendation:** Follow the existing OpenAI settings partial exactly, creating an anthropic_settings partial and adding a provider selector dropdown at the top of the AI section.
</research_summary>

<standard_stack>
## Standard Stack (Internal Patterns)

### Core UI Components
| Component | Location | Purpose | Usage Pattern |
|-----------|----------|---------|---------------|
| StyledFormBuilder | `app/helpers/styled_form_builder.rb` | Custom form builder with consistent styling | All settings forms use `styled_form_with` |
| auto-submit-form | `app/javascript/controllers/auto_submit_form_controller.js` | Auto-submits forms on field change | Applied via `data: { controller: "auto-submit-form" }` |
| DS::Button | `app/components/DS/button.rb` | Design system button component | Used for form submits in StyledFormBuilder |
| DS::Toggle | `app/components/DS/toggle.rb` | Design system toggle component | Used for boolean settings via `form.toggle` |

### Form Field Helpers
| Helper | Pattern | Example |
|--------|---------|---------|
| `text_field` | Standard text input with label wrapper | `form.text_field :openai_model, label: "...", value: Setting.openai_model` |
| `password_field` | Password input with masking | `form.password_field :openai_access_token, value: "********"` |
| `select` | Dropdown with options | `form.select :openai_json_mode, options_for_select([...]), { label: "..." }` |
| `toggle` | Boolean toggle switch | `form.toggle :require_email_confirmation` |

### Settings Pattern
| File | Pattern |
|------|---------|
| Partial | `app/views/settings/hostings/_openai_settings.html.erb` |
| Controller | `app/controllers/settings/hostings_controller.rb` (already handles anthropic fields) |
| Locale | `config/locales/views/settings/hostings/en.yml` |

**Installation:** N/A (uses existing codebase patterns)
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Settings Page Structure
```
app/views/settings/hostings/show.html.erb
├── settings_section "General"
│   ├── _openai_settings.html.erb      # Current OpenAI settings
│   ├── _anthropic_settings.html.erb   # NEW: Anthropic settings
│   └── _brand_fetch_settings.html.erb
└── settings_section "Financial Data Providers"
    └── _provider_selection.html.erb   # Reference for dropdown pattern
```

### Pattern 1: Settings Partial Structure
**What:** A self-contained partial with its own form for each provider
**When to use:** Isolated settings sections that can be updated independently
**Example:**
```erb
<!-- _openai_settings.html.erb -->
<div class="space-y-4">
  <h2 class="font-medium mb-1"><%= t(".title") %></h2>
  <% if ENV["OPENAI_ACCESS_TOKEN"].present? %>
    <p class="text-sm text-secondary"><%= t(".env_configured_message") %></p>
  <% else %>
    <p class="text-secondary text-sm mb-4"><%= t(".description") %></p>
  <% end %>

  <%= styled_form_with model: Setting.new,
                       url: settings_hosting_path,
                       method: :patch,
                       data: { controller: "auto-submit-form" } do |form| %>
    <%= form.password_field :openai_access_token,
                            label: t(".access_token_label"),
                            value: (Setting.openai_access_token.present? ? "********" : nil),
                            data: { "auto-submit-form-target": "auto" } %>
    <!-- ... more fields ... -->
  <% end %>
</div>
```

### Pattern 2: Provider Selection Dropdown
**What:** A dropdown that controls which settings sections are visible
**When to use:** When users need to choose between mutually exclusive options
**Reference:** `app/views/settings/hostings/_provider_selection.html.erb`
**Example:**
```erb
<%= styled_form_with model: Setting.new,
                     url: settings_hosting_path,
                     method: :patch do |form| %>
  <%= form.select :exchange_rate_provider,
                  options_for_select([
                    [t(".providers.yahoo_finance"), "yahoo_finance"],
                    [t(".providers.twelve_data"), "twelve_data"]
                  ], Setting.exchange_rate_provider),
                  { label: t(".exchange_rate_provider_label") },
                  { data: { "auto-submit-form-target": "auto" } } %>
<% end %>
```

### Pattern 3: ENV Override Handling
**What:** Fields are disabled when ENV is set, showing a message that configuration is via environment variables
**When to use:** For any setting that can be overridden by ENV
**Example:**
```erb
<% if ENV["OPENAI_ACCESS_TOKEN"].present? %>
  <p class="text-sm text-secondary"><%= t(".env_configured_message") %></p>
<% end %>

<%= form.text_field :openai_model,
                    disabled: ENV["OPENAI_MODEL"].present? %>
```

### Pattern 4: API Key Masking
**What:** Existing keys are shown as "********" to prevent accidental exposure
**When to use:** Any password/token field
**Example:**
```erb
<%= form.password_field :openai_access_token,
                        value: (Setting.openai_access_token.present? ? "********" : nil) %>
```

Controller handling:
```ruby
if hosting_params.key?(:openai_access_token)
  token_param = hosting_params[:openai_access_token].to_s.strip
  # Ignore blanks and redaction placeholders
  unless token_param.blank? || token_param == "********"
    Setting.openai_access_token = token_param
  end
end
```

### Anti-Patterns to Avoid
- **Creating new form helpers:** Use StyledFormBuilder, don't create custom form helpers
- **Hardcoded labels:** Always use `t(".key")` for i18n
- **Skipping ENV checks:** Must handle ENV overrides for all settings
- **Multiple forms in one partial:** Each settings section has its own form
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Form styling | Custom CSS classes | StyledFormBuilder | Consistent design system, handles labels/wrapping |
| Form submission | Manual submit buttons | auto-submit-form controller | Matches existing UX, instant save on blur |
| Toggle switches | Custom checkbox + CSS | DS::Toggle component | Accessible, tested, consistent |
| Form layout | Grid/flexbox | space-y-4 utility | Vertical stacking is the pattern |
| API key masking | Custom redaction logic | "********" placeholder + controller check | Existing pattern, user understands it |

**Key insight:** The settings UI is a solved problem in this codebase. Follow the OpenAI settings partial exactly for Anthropic - same field order, same styling, same behavior.
</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

### Pitfall 1: Not Following Existing Partial Structure
**What goes wrong:** Creating a different form structure than OpenAI settings
**Why it happens:** Wanting to "improve" the existing pattern
**How to avoid:** Copy `_openai_settings.html.erb` exactly and change only what's necessary
**Warning signs:** Form looks different from OpenAI settings

### Pitfall 2: Missing ENV Override Logic
**What goes wrong:** Fields are editable even when ENV is set
**Why it happens:** Forgetting to add the ENV check
**How to avoid:** Check `ENV["ANTHROPIC_API_KEY"]` for each field, add disabled attribute
**Warning signs:** No `env_configured_message` when ENV is present

### Pitfall 3: Incorrect Locale Key Structure
**What goes wrong:** Translations not found or keys don't match the pattern
**Why it happens:** Not following the existing locale structure
**How to avoid:** Use `settings.hostings.anthropic_settings.*` keys following `openai_settings` pattern
**Warning signs:** Translation keys showing raw values in UI

### Pitfall 4: Provider Selector Not Showing/Hiding Sections
**What goes wrong:** Both OpenAI and Anthropic fields shown simultaneously
**Why it happens:** Missing the conditional display logic
**How to avoid:** This is explicitly out of scope per CONTEXT.md - both sections can be visible
**Warning signs:** N/A (this is the desired behavior per phase context)
</common_pitfalls>

<code_examples>
## Code Examples

### Settings Partial Template
```erb
<!-- Source: app/views/settings/hostings/_openai_settings.html.erb -->
<div class="space-y-4">
  <div>
    <h2 class="font-medium mb-1"><%= t(".title") %></h2>
    <% if ENV["OPENAI_ACCESS_TOKEN"].present? %>
      <p class="text-sm text-secondary"><%= t(".env_configured_message") %></p>
    <% else %>
      <p class="text-secondary text-sm mb-4"><%= t(".description") %></p>
    <% end %>
  </div>

  <%= styled_form_with model: Setting.new,
                       url: settings_hosting_path,
                       method: :patch,
                       class: "space-y-4",
                       data: {
                         controller: "auto-submit-form",
                         "auto-submit-form-trigger-event-value": "blur"
                       } do |form| %>

    <%= form.password_field :openai_access_token,
                            label: t(".access_token_label"),
                            placeholder: t(".access_token_placeholder"),
                            value: (Setting.openai_access_token.present? ? "********" : nil),
                            autocomplete: "off",
                            autocapitalize: "none",
                            spellcheck: "false",
                            inputmode: "text",
                            disabled: ENV["OPENAI_ACCESS_TOKEN"].present?,
                            data: { "auto-submit-form-target": "auto" } %>

    <%= form.text_field :openai_model,
                        label: t(".model_label"),
                        placeholder: t(".model_placeholder"),
                        value: Setting.openai_model,
                        autocomplete: "off",
                        autocapitalize: "none",
                        spellcheck: "false",
                        inputmode: "text",
                        disabled: ENV["OPENAI_MODEL"].present?,
                        data: { "auto-submit-form-target": "auto" } %>
  <% end %>
</div>
```

### Provider Selector Dropdown
```erb
<!-- Source: app/views/settings/hostings/_provider_selection.html.erb -->
<%= styled_form_with model: Setting.new,
                     url: settings_hosting_path,
                     method: :patch do |form| %>
  <%= form.select :exchange_rate_provider,
                  options_for_select(
                    [
                      [t(".providers.yahoo_finance"), "yahoo_finance"],
                      [t(".providers.twelve_data"), "twelve_data"]
                    ],
                    Setting.exchange_rate_provider
                  ),
                  { label: t(".exchange_rate_provider_label") },
                  { disabled: ENV["EXCHANGE_RATE_PROVIDER"].present?,
                    data: { "auto-submit-form-target": "auto" } } %>

  <%= form.select :securities_provider,
                  options_for_select(
                    [
                      [t(".providers.yahoo_finance"), "yahoo_finance"],
                      [t(".providers.twelve_data"), "twelve_data"]
                    ],
                    Setting.securities_provider
                  ),
                  { label: t(".securities_provider_label") },
                  { disabled: ENV["SECURITIES_PROVIDER"].present?,
                    data: { "auto-submit-form-target": "auto" } } %>
<% end %>
```

### Controller Update Pattern
```ruby
# Source: app/controllers/settings/hostings_controller.rb
def update
  # API key handling with masking
  if hosting_params.key?(:openai_access_token)
    token_param = hosting_params[:openai_access_token].to_s.strip
    unless token_param.blank? || token_param == "********"
      Setting.openai_access_token = token_param
    end
  end

  # Simple field update
  if hosting_params.key?(:openai_model)
    Setting.openai_model = hosting_params[:openai_model]
  end

  redirect_to settings_hosting_path, notice: t(".success")
rescue Setting::ValidationError => error
  flash.now[:alert] = error.message
  render :show, status: :unprocessable_entity
end
```

### Locale File Structure
```yaml
# Source: config/locales/views/settings/hostings/en.yml
en:
  settings:
    hostings:
      openai_settings:
        title: OpenAI
        description: Enter the access token and optionally configure a custom OpenAI-compatible provider
        env_configured_message: Successfully configured through environment variables.
        access_token_label: Access Token
        access_token_placeholder: Enter your access token here
        model_label: Model (Optional)
        model_placeholder: "gpt-4.1 (default)"
```

### Stimulus Controller Usage
```erb
<!-- auto-submit-form controller -->
<%= styled_form_with model: Setting.new,
                     url: settings_hosting_path,
                     method: :patch,
                     data: {
                       controller: "auto-submit-form",
                       "auto-submit-form-trigger-event-value": "blur"
                     } do |form| %>
  <!-- Fields with data-auto-submit-form-target="auto" auto-submit on blur -->
  <%= form.text_field :field_name, data: { "auto-submit-form-target": "auto" } %>
<% end %>
```
</code_examples>

<sota_updates>
## State of the Art (2024-2025)

The codebase uses established Rails patterns from 2023-2024:

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Traditional Rails forms | styled_form_with + StyledFormBuilder | 2023 | Consistent styling, less boilerplate |
| Manual submit buttons | auto-submit-form controller | 2023 | Instant save, better UX |
| SCSS styles | Tailwind CSS v4.x | 2024 | Utility-first, design system tokens |

**Current conventions:**
- Hotwire stack (Turbo + Stimulus) for reactive UI
- ViewComponents for reusable UI elements
- Tailwind CSS functional tokens (text-primary, bg-container)
- i18n for all user-facing strings
- ENV fallbacks with database overrides

**No changes needed for this phase** - following current conventions is the requirement.
</sota_updates>

<open_questions>
## Open Questions

None. The implementation pattern is clear from existing code.

**Decision made from CONTEXT.md:** Both provider settings sections will be visible simultaneously (no show/hide based on provider selection). The provider selector dropdown (`llm_provider` field) will be a separate form element above the provider-specific sections.
</open_questions>

<sources>
## Sources

### Primary (HIGH confidence)
- `/Users/andrewbewernick/GitHub/sure/app/helpers/styled_form_builder.rb` - Form builder API
- `/Users/andrewbewernick/GitHub/sure/app/views/settings/hostings/_openai_settings.html.erb` - Template to follow
- `/Users/andrewbewernick/GitHub/sure/app/views/settings/hostings/_provider_selection.html.erb` - Dropdown pattern
- `/Users/andrewbewernick/GitHub/sure/app/controllers/settings/hostings_controller.rb` - Controller already handles anthropic fields
- `/Users/andrewbewernick/GitHub/sure/config/locales/views/settings/hostings/en.yml` - Locale structure

### Secondary (MEDIUM confidence)
- `app/javascript/controllers/auto_submit_form_controller.js` - Auto-submit behavior
- `app/components/DS/` - Design system components
- Phase 06-CONTEXT.md - User's vision and requirements

### Tertiary (LOW confidence - needs validation)
- None - all findings verified from codebase
</sources>

<metadata>
## Metadata

**Research scope:**
- Core technology: Rails + Hotwire (Turbo + Stimulus)
- Ecosystem: StyledFormBuilder, Tailwind CSS v4.x, auto-submit-form controller
- Patterns: Settings partials, ENV overrides, API key masking
- Pitfalls: Form structure consistency, i18n, ENV handling

**Confidence breakdown:**
- Standard stack: HIGH - directly from codebase
- Architecture: HIGH - existing patterns documented
- Pitfalls: HIGH - identified from existing code
- Code examples: HIGH - copied from actual files

**Research date:** 2026-01-09
**Valid until:** 2026-02-09 (30 days - internal patterns stable)
</metadata>

---

*Phase: 06-settings-ui*
*Research completed: 2026-01-09*
*Ready for planning: yes*
