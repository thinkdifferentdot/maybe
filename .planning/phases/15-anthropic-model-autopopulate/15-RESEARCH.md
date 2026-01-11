# Phase 15: Anthropic Model Autopopulate - Research

**Researched:** 2026-01-10
**Domain:** Rails 7.2 + Hotwire + Anthropic API integration
**Confidence:** HIGH

<research_summary>
## Summary

Researched the Anthropic `/v1/models` API endpoint and existing Rails/Stimulus patterns in the codebase for implementing dynamic model fetching. The Anthropic API provides a models endpoint that returns available Claude models with display names. Since neither the ruby-anthropic gem (v1.16.0, currently in use) nor the official anthropic-sdk-ruby gem expose a models API method, we need to use Faraday directly (already a dependency).

**Primary recommendation:** Use Faraday for the HTTP request to `https://api.anthropic.com/v1/models`, filter results to models starting with "claude-", and create a Stimulus controller that fetches on page load when the Anthropic section is visible. Follow existing patterns: `ai_categorize_controller.js` for fetch patterns and `provider_visibility_controller.js` for section visibility events.
</research_summary>

<standard_stack>
## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Faraday | (installed) | HTTP client | Already in Gemfile, used by Provider classes |
| anthropic gem | 1.16.0 | Anthropic API client | Currently installed for messages API |
| Stimulus | (via importmap) | Frontend controllers | Standard Hotwire pattern in this app |
| RailsSettings | (installed) | Settings storage | Used for all settings including AI config |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| auto-submit-form | (existing controller) | Auto-save on blur/change | For saving selected model |
| provider-visibility | (existing controller) | Show/hide provider sections | For triggering fetch when visible |
| icon helper | (application_helper) | Icons for UI states | Loading spinner, error icons |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Faraday | Net::HTTP | Faraday already configured with retry, familiar pattern |
| New Stimulus controller | Extend existing | New controller is cleaner, single responsibility |

**Installation:**
No new gems needed - Faraday and anthropic gem already installed.
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Recommended Project Structure
```
app/
├── controllers/
│   └── settings/
│       └── hostings_controller.rb  # Add anthropic_models action
├── javascript/
│   └── controllers/
│       └── anthropic_model_select_controller.js  # NEW
├── models/
│   └── setting.rb  # Existing, no changes needed
└── views/
    └── settings/
        └── hostings/
            └── _anthropic_settings.html.erb  # Modify view
```

### Pattern 1: Backend Proxy via Rails Controller
**What:** Create a Rails controller action that proxies the request to Anthropic API
**When to use:** Any external API call from frontend that needs authentication
**Example:**
```ruby
# hostings_controller.rb
def anthropic_models
  require_admin!

  token = Setting.anthropic_access_token.presence || ENV["ANTHROPIC_API_KEY"]

  if token.blank?
    render json: { error: "No API token configured" }, status: :unprocessable_entity
    return
  end

  response = fetch_anthropic_models(token)

  if response.success?
    render json: response.body
  else
    render json: { error: "Failed to fetch models" }, status: response.status
  end
rescue => e
  render json: { error: e.message }, status: :internal_server_error
end

private

def fetch_anthropic_models(token)
  connection = Faraday.new(
    url: "https://api.anthropic.com",
    headers: {
      "anthropic-version" => "2023-06-01",
      "X-API-Key" => token,
      "Content-Type" => "application/json"
    }
  )

  response = connection.get("/v1/models")

  if response.success?
    body = JSON.parse(response.body)
    # Filter to claude- models per validation requirement
    claude_models = body["data"].select { |m| m["id"].start_with?("claude-") }
    OpenStruct.new(success?: true, status: response.status, body: { "data" => claude_models })
  else
    OpenStruct.new(success?: false, status: response.status, body: nil)
  end
end
```

### Pattern 2: Stimulus Controller with API Fetch
**What:** Fetch models when section becomes visible, populate select dropdown
**When to use:** Dynamic form options that need server data
**Example:**
```javascript
// anthropic_model_select_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["select", "loading", "error"];
  static values = {
    url: String,
    currentModel: String
  };

  connect() {
    // Fetch when section is visible
    if (this.isSectionVisible()) {
      this.fetchModels();
    }

    // Listen for provider changes
    document.addEventListener("provider-visibility:changed", this.handleVisibilityChange);
  }

  disconnect() {
    document.removeEventListener("provider-visibility:changed", this.handleVisibilityChange);
  }

  handleVisibilityChange = (event) => {
    if (event.detail.provider === "anthropic" && this.isSectionVisible()) {
      this.fetchModels();
    }
  }

  isSectionVisible() {
    const section = this.element.closest('[data-provider-visibility-target="section"]');
    return section && !section.classList.contains("hidden");
  }

  async fetchModels() {
    // Skip if already populated
    if (this.hasSelectTarget && this.selectTarget.options.length > 1) {
      return;
    }

    this.showLoading();

    try {
      const response = await fetch(this.urlValue, {
        headers: { "Accept": "application/json" }
      });

      if (!response.ok) throw new Error(`HTTP ${response.status}`);

      const data = await response.json();
      this.populateModels(data.data);
    } catch (error) {
      this.showError(error.message);
    } finally {
      this.hideLoading();
    }
  }

  populateModels(models) {
    this.selectTarget.innerHTML = "";

    // Add placeholder
    const placeholder = document.createElement("option");
    placeholder.value = "";
    placeholder.textContent = "Select a model...";
    this.selectTarget.appendChild(placeholder);

    // Add models sorted by display name
    models
      .sort((a, b) => a.display_name.localeCompare(b.display_name))
      .forEach(model => {
        const option = document.createElement("option");
        option.value = model.id;
        option.textContent = `${model.display_name} (${model.id})`;
        this.selectTarget.appendChild(option);
      });

    // Set current value
    if (this.currentModelValue) {
      this.selectTarget.value = this.currentModelValue;
    }
  }

  showLoading() {
    if (this.hasSelectTarget) this.selectTarget.disabled = true;
    if (this.hasLoadingTarget) this.loadingTarget.classList.remove("hidden");
  }

  hideLoading() {
    if (this.hasLoadingTarget) this.loadingTarget.classList.add("hidden");
  }

  showError(message) {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = message;
      this.errorTarget.classList.remove("hidden");
    }
  }
}
```

### Anti-Patterns to Avoid
- **Direct browser calls to Anthropic API:** Will fail due to CORS - must use backend proxy
- **Fetching on every page load:** Cache in controller or check if already populated
- **Not handling ENV variables:** Must respect ENV["ANTHROPIC_MODEL"] - disable select when set
- **Not filtering models:** Existing validation requires "claude-" prefix - filter server-side
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTTP requests | Net::HTTP, custom code | Faraday | Already configured with retry, familiar pattern in codebase |
| Loading state | Custom spinner logic | Existing icon helper + CSS | Use `icon("loader")` with Tailwind animate-spin |
| API authentication logic | Custom header handling | Faraday headers | Clean pattern, handles errors |
| Provider visibility detection | Custom show/hide logic | provider-visibility controller events | Already dispatches events on change |

**Key insight:** Rails 7.2 + Hotwire apps have established patterns. Faraday for HTTP, Stimulus for interactivity. The existing `ai_categorize_controller.js` shows the exact pattern for fetch + loading state + error handling.
</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

### Pitfall 1: CORS Errors
**What goes wrong:** Browser blocks direct calls to api.anthropic.com
**Why it happens:** Anthropic API doesn't allow browser-originated requests
**How to avoid:** Always use Rails backend proxy for API calls
**Warning signs:** Network errors in console, no response from API

### Pitfall 2: Not Respecting ENV Variables
**What goes wrong:** Select is editable even when ENV["ANTHROPIC_MODEL"] is set
**Why it happens:** Missing the `disabled: ENV["ANTHROPIC_MODEL"].present?` check
**How to avoid:** Copy the existing disabled pattern from text_field to select
**Warning signs:** Settings page allows editing when it shouldn't

### Pitfall 3: Not Filtering Models
**What goes wrong:** All Anthropic models shown, including non-Claude ones
**Why it happens:** API returns all models, but validation requires "claude-" prefix
**How to avoid:** Filter server-side with `.select { |m| m["id"].start_with?("claude-") }`
**Warning signs:** Models fail validation after selection

### Pitfall 4: Fetching on Every Provider Switch
**What goes wrong:** Repeated API calls when switching between providers
**Why it happens:** Not checking if select is already populated
**How to avoid:** Check `selectTarget.options.length > 1` before fetching
**Warning signs:** Multiple network requests in DevTools
</common_pitfalls>

<code_examples>
## Code Examples

### Anthropic Models API Response Format
```json
{
  "data": [
    {
      "id": "claude-sonnet-4-20250514",
      "created_at": "2025-02-19T00:00:00Z",
      "display_name": "Claude Sonnet 4",
      "type": "model"
    },
    {
      "id": "claude-opus-4-20250514",
      "created_at": "2025-02-19T00:00:00Z",
      "display_name": "Claude Opus 4",
      "type": "model"
    }
  ],
  "has_more": false,
  "first_id": "claude-sonnet-4-20250514",
  "last_id": "claude-opus-4-20250514"
}
```
Source: [Anthropic API Reference - List Models](https://platform.claude.com/docs/en/api/models/list)

### Route Definition
```ruby
# config/routes.rb
resource :hosting, only: %i[show update] do
  get :anthropic_models, on: :collection
  delete :clear_cache, on: :collection
end
```

### View Integration Pattern
```erb
<div data-controller="anthropic-model-select"
     data-anthropic-model-select-url-value="<%= anthropic_models_settings_hosting_path %>"
     data-anthropic-model-select-current-model-value="<%= Setting.anthropic_model %>">

  <select name="setting[anthropic_model]"
          data-anthropic-model-select-target="select"
          data-auto-submit-form-target="auto"
          <%= 'disabled' if ENV["ANTHROPIC_MODEL"].present? %>>
    <option value="" disabled>Loading models...</option>
  </select>

  <div data-anthropic-model-select-target="loading" class="hidden">
    <%= icon("loader", class: "w-3 h-3 animate-spin") %>
    <span class="text-xs text-secondary">Loading models...</span>
  </div>

  <div data-anthropic-model-select-target="error" class="hidden">
    <%= icon("alert-circle", class: "w-3 h-3 text-warning") %>
    <span class="text-xs text-warning"></span>
  </div>
</div>
```
</code_examples>

<sota_updates>
## State of the Art (2025)

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual model entry | Dropdown with API fetching | This implementation | Better UX, no typos, auto-updates |

**New tools/patterns to consider:**
- **Caching:** Could add Rails.cache around API call (1 hour expiry) to reduce API calls
- **Turbo Stream updates:** Could use Turbo Streams for error messages instead of manual DOM manipulation

**Deprecated/outdated:**
- None - this is a new feature for this codebase
</sota_updates>

<open_questions>
## Open Questions

None - all aspects of this implementation follow established patterns in the codebase.
</open_questions>

<sources>
## Sources

### Primary (HIGH confidence)
- [Anthropic API Reference - List Models](https://platform.claude.com/docs/en/api/models/list) - Official API documentation for `/v1/models` endpoint
- [ruby-anthropic gem README](https://github.com/alexrudall/ruby-anthropic) - Community gem (v1.16.0 currently in use, no models API method)
- [anthropic-sdk-ruby documentation](https://www.rubydoc.info/github/anthropics/anthropic-sdk-ruby) - Official SDK (also lacks models API method in docs)

### Secondary (MEDIUM confidence)
- [Claude models available in 2025](https://www.datastudios.org/post/all-claude-ai-models-available-in-2025-full-list-for-web-app-api-and-cloud-platforms) - Model list reference

### Tertiary (LOW confidence - needs validation)
- None - all findings verified
</sources>

<metadata>
## Metadata

**Research scope:**
- Core technology: Anthropic `/v1/models` API endpoint, Rails 7.2, Stimulus.js
- Ecosystem: Faraday HTTP client, RailsSettings, Hotwire patterns
- Patterns: Backend proxy, Stimulus fetch, loading states, error handling
- Pitfalls: CORS, ENV handling, model filtering, duplicate fetches

**Confidence breakdown:**
- Standard stack: HIGH - Faraday and anthropic gem already in use
- Architecture: HIGH - Based on existing controllers in the codebase
- Pitfalls: HIGH - CORS and ENV issues well understood
- Code examples: HIGH - From official API docs and existing codebase patterns

**Research date:** 2026-01-10
**Valid until:** 2026-02-10 (30 days - API endpoints stable, Ruby patterns stable)
</metadata>

---

*Phase: 15-anthropic-model-autopopulate*
*Research completed: 2026-01-10*
*Ready for planning: yes*
