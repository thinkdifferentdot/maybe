# Phase 5: Settings Model - Research

**Researched:** 2026-01-10
**Domain:** Rails settings model with ENV fallbacks (established patterns)
**Confidence:** HIGH

<research_summary>
## Summary

This phase adds Anthropic settings to the existing `Setting` model following the established OpenAI pattern. No external libraries or new architecture needed — this is applying existing codebase patterns.

The pattern is straightforward:
1. Add `field` declarations to `Setting` model with `default: ENV["KEY"]` fallback
2. Add corresponding provider method in `Provider::Registry` with ENV/Setting fallback
3. Add validation methods following the `validate_openai_config!` pattern
4. Add controller params permitting in `Settings::HostingsController`

**Primary recommendation:** Mirror the OpenAI pattern exactly for `anthropic_access_token`, `anthropic_model`, and `llm_provider` fields.
</research_summary>

<standard_stack>
## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| rails-settings | (bundled) | Settings model with ENV fallback | Already in use, handles caching |
| None | - | No new dependencies needed | Pure Rails patterns |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| rails-settings | ActiveRecord settings table | rails-settings already handles caching, YAML serialization, ENV defaults |

**Installation:** None (already bundled)
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Recommended Project Structure
```
app/models/
├── setting.rb              # Add field declarations here
├── provider/
│   ├── registry.rb         # Add anthropic provider method
│   ├── anthropic.rb        # Already exists from Phase 2
│   └── openai.rb           # Reference pattern
└── ...

app/controllers/
└── settings/
    └── hostings_controller.rb  # Add params permitting here
```

### Pattern 1: Settings Field with ENV Fallback
**What:** Declare fields with ENV defaults using `rails-settings`
**When to use:** All configuration that supports both ENV and database storage
**Example:**
```ruby
# From app/models/setting.rb (lines 9-11)
field :openai_access_token, type: :string, default: ENV["OPENAI_ACCESS_TOKEN"]
field :openai_uri_base, type: :string, default: ENV["OPENAI_URI_BASE"]
field :openai_model, type: :string, default: ENV["OPENAI_MODEL"]

# Apply this pattern for Anthropic:
field :anthropic_access_token, type: :string, default: ENV["ANTHROPIC_ACCESS_TOKEN"]
field :anthropic_model, type: :string, default: ENV["ANTHROPIC_MODEL"]
```

### Pattern 2: Registry Provider with Fallback
**What:** Provider method checks ENV first, then Setting
**When to use:** All external service providers
**Example:**
```ruby
# From app/models/provider/registry.rb (lines 65-79)
def openai
  access_token = ENV["OPENAI_ACCESS_TOKEN"].presence || Setting.openai_access_token

  return nil unless access_token.present?

  uri_base = ENV["OPENAI_URI_BASE"].presence || Setting.openai_uri_base
  model = ENV["OPENAI_MODEL"].presence || Setting.openai_model

  Provider::Openai.new(access_token, uri_base: uri_base, model: model)
end

# Apply this pattern for Anthropic:
def anthropic
  access_token = ENV["ANTHROPIC_ACCESS_TOKEN"].presence || Setting.anthropic_access_token
  return nil unless access_token.present?

  model = ENV["ANTHROPIC_MODEL"].presence || Setting.anthropic_model
  Provider::Anthropic.new(access_token: access_token, model: model)
end
```

### Pattern 3: Validation Class Method
**What:** Validation that raises `Setting::ValidationError`
**When to use:** Configuration validation before saving
**Example:**
```ruby
# From app/models/setting.rb (lines 123-133)
def self.validate_openai_config!(uri_base: nil, model: nil)
  uri_base_value = uri_base.nil? ? openai_uri_base : uri_base
  model_value = model.nil? ? openai_model : model

  if uri_base_value.present? && model_value.blank?
    raise ValidationError, "OpenAI model is required when custom URI base is configured"
  end
end

# Consider similar for Anthropic if validation rules needed
```

### Pattern 4: Provider Selection Enum
**What:** Field storing provider choice as string with limited values
**When to use:** When multiple providers exist for a concept
**Example:**
```ruby
# From app/models/setting.rb (lines 15-17)
field :exchange_rate_provider, type: :string, default: ENV.fetch("EXCHANGE_RATE_PROVIDER", "twelve_data")
field :securities_provider, type: :string, default: ENV.fetch("SECURITIES_PROVIDER", "twelve_data")

# Apply this pattern for LLM provider:
LLM_PROVIDERS = %w[openai anthropic].freeze
field :llm_provider, type: :string, default: ENV.fetch("LLM_PROVIDER", "openai")
```

### Anti-Patterns to Avoid
- **Hardcoding ENV checks in providers:** Use the registry pattern instead
- **Skipping ENV fallbacks:** Always support both ENV and Setting for self-hosted deployments
- **Forgetting to update controller params:** New fields must be permitted in `hosting_params`
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Settings caching | Custom cache layer | rails-settings built-in caching | Already handles cache_prefix, clear_cache |
| YAML serialization | Custom serialization | rails-settings YAML encoding | Handles complex types automatically |
| ENV fallback logic | Ternaries everywhere | `default: ENV["KEY"]` pattern | Declarative, handles nil/blank correctly |

**Key insight:** The `rails-settings` gem (via `RailsSettings::Base`) handles all the complexity of caching, serialization, and ENV fallbacks. Don't duplicate this functionality.
</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

### Pitfall 1: Forgetting to Update Controller Permitted Params
**What goes wrong:** New fields save to database but params are rejected
**Why it happens:** Strong parameters in controller must explicitly list each field
**How to avoid:** Add new field to `hosting_params` permit list immediately after adding field declaration
**Warning signs:** "Unpermitted parameter" in logs, settings don't persist

### Pitfall 2: Missing ENV.fetch Default
**What goes wrong:** `ENV["KEY"]` returns nil when unset, no default behavior
**Why it happens:** Using `ENV["KEY"]` instead of `ENV.fetch("KEY", "default")`
**How to avoid:** Use `ENV.fetch("KEY", "default")` for provider selection fields
**Warning signs:** Tests fail when ENV vars not set, unexpected nil values

### Pitfall 3: Not Handling Empty String vs Nil
**What goes wrong:** User clears field but it doesn't actually clear (stores empty string)
**Why it happens:** Form submits `""` which is truthy in some contexts
**How to avoid:** Use `.presence` || pattern when reading values (see registry.rb line 66)
**Warning signs:** Settings show blank but still act as "set"

### Pitfall 4: Race Conditions on Dynamic Fields
**What goes wrong:** Concurrent requests corrupt settings
**Why it happens:** Old pattern used single YAML blob for all dynamic fields
**How to avoid:** Use the new individual entry pattern (lines 19-21, 78-86 in setting.rb)
**Warning signs:** Settings randomly revert, intermittent errors
</common_pitfalls>

<code_examples>
## Code Examples

### Adding Anthropic Fields to Setting Model
```ruby
# Source: app/models/setting.rb (add after line 12)
field :anthropic_access_token, type: :string, default: ENV["ANTHROPIC_ACCESS_TOKEN"]
field :anthropic_model, type: :string, default: ENV["ANTHROPIC_MODEL"]

# Provider selection (add after line 17)
LLM_PROVIDERS = %w[openai anthropic].freeze
field :llm_provider, type: :string, default: ENV.fetch("LLM_PROVIDER", "openai")
```

### Adding Anthropic to Registry
```ruby
# Source: app/models/provider/registry.rb (add after line 79)
def anthropic
  access_token = ENV["ANTHROPIC_ACCESS_TOKEN"].presence || Setting.anthropic_access_token
  return nil unless access_token.present?

  model = ENV["ANTHROPIC_MODEL"].presence || Setting.anthropic_model
  Provider::Anthropic.new(access_token: access_token, model: model)
end
```

### Adding to LLM Available Providers
```ruby
# Source: app/models/provider/registry.rb (modify line 113)
when :llm
  %i[openai anthropic]
```

### Adding Controller Params
```ruby
# Source: app/controllers/settings/hostings_controller.rb (modify line 102)
def hosting_params
  params.require(:setting).permit(
    :onboarding_state, :require_email_confirmation, :brand_fetch_client_id,
    :twelve_data_api_key, :openai_access_token, :openai_uri_base, :openai_model, :openai_json_mode,
    :exchange_rate_provider, :securities_provider,
    :anthropic_access_token, :anthropic_model, :llm_provider  # Add these
  )
end
```

### Adding Controller Update Logic
```ruby
# Source: app/controllers/settings/hostings_controller.rb (add after line 87)
if hosting_params.key?(:anthropic_access_token)
  token_param = hosting_params[:anthropic_access_token].to_s.strip
  unless token_param.blank? || token_param == "********"
    Setting.anthropic_access_token = token_param
  end
end

if hosting_params.key?(:anthropic_model)
  Setting.anthropic_model = hosting_params[:anthropic_model]
end

if hosting_params.key?(:llm_provider)
  Setting.llm_provider = hosting_params[:llm_provider]
end
```
</code_examples>

<sota_updates>
## State of the Art (2024-2025)

No changes needed — the `rails-settings` pattern is stable and well-established.

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| N/A | Current | N/A | This pattern is timeless |

**New tools/patterns to consider:**
- None — stick with established patterns

**Deprecated/outdated:**
- None relevant
</sota_updates>

<open_questions>
## Open Questions

None — this is a well-established pattern in the codebase with no ambiguity.
</open_questions>

<sources>
## Sources

### Primary (HIGH confidence)
- `app/models/setting.rb` - Complete reference for field declarations, validation patterns
- `app/models/provider/registry.rb` - Complete reference for provider instantiation patterns
- `app/controllers/settings/hostings_controller.rb` - Complete reference for controller handling

### Secondary (MEDIUM confidence)
- None — all findings directly from codebase

### Tertiary (LOW confidence - needs validation)
- None
</sources>

<metadata>
## Metadata

**Research scope:**
- Core technology: Rails settings model (rails-settings gem)
- Ecosystem: None (internal patterns)
- Patterns: Field declarations, ENV fallbacks, provider registry, controller params
- Pitfalls: Params permitting, ENV.fetch, string vs nil handling

**Confidence breakdown:**
- Standard stack: HIGH - established codebase pattern
- Architecture: HIGH - directly from existing code
- Pitfalls: HIGH - patterns observed in codebase
- Code examples: HIGH - verified from actual source files

**Research date:** 2026-01-10
**Valid until:** 2026-07-10 (180 days - internal patterns don't change)
</metadata>

---

*Phase: 05-settings-model*
*Research completed: 2026-01-10*
*Ready for planning: yes*
