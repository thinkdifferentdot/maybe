# Admin Settings for Lunchflow-Supabase Configuration

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add admin UI to configure global Supabase and Lunchflow credentials through Settings page instead of editing Rails credentials files.

**Architecture:** Extend existing Setting model with new fields (supabase_url, supabase_key, lunchflow_api_key) following the synth_api_key pattern. Update SupabaseClient to use fallback hierarchy (ENV → Rails credentials → database settings). Add form section in Settings::HostingsController.

**Tech Stack:** Rails 7.2, rails-settings-cached gem, Hotwire (Turbo/Stimulus), Tailwind CSS

---

## Task 1: Add Setting Model Fields

**Files:**
- Modify: `app/models/setting.rb:1-10`
- Test: `test/models/setting_test.rb`

### Step 1: Write failing test for new settings fields

**File:** `test/models/setting_test.rb`

```ruby
require "test_helper"

class SettingTest < ActiveSupport::TestCase
  test "supabase_url defaults to ENV variable" do
    ClimateControl.modify SUPABASE_URL: "https://test.supabase.co" do
      assert_equal "https://test.supabase.co", Setting.supabase_url
    end
  end

  test "supabase_key defaults to ENV variable" do
    ClimateControl.modify SUPABASE_SERVICE_ROLE_KEY: "test-key-123" do
      assert_equal "test-key-123", Setting.supabase_key
    end
  end

  test "lunchflow_api_key defaults to ENV variable" do
    ClimateControl.modify LUNCHFLOW_API_KEY: "lf-key-456" do
      assert_equal "lf-key-456", Setting.lunchflow_api_key
    end
  end

  test "can set and retrieve supabase_url" do
    Setting.supabase_url = "https://my-project.supabase.co"
    assert_equal "https://my-project.supabase.co", Setting.supabase_url
  end

  test "can set and retrieve supabase_key" do
    Setting.supabase_key = "my-secret-key"
    assert_equal "my-secret-key", Setting.supabase_key
  end

  test "can set and retrieve lunchflow_api_key" do
    Setting.lunchflow_api_key = "my-lunchflow-key"
    assert_equal "my-lunchflow-key", Setting.lunchflow_api_key
  end
end
```

### Step 2: Run test to verify it fails

**Command:**
```bash
bin/rails test test/models/setting_test.rb
```

**Expected:** FAIL - undefined method `supabase_url`, `supabase_key`, `lunchflow_api_key`

### Step 3: Add fields to Setting model

**File:** `app/models/setting.rb`

```ruby
# Dynamic settings the user can change within the app (helpful for self-hosting)
class Setting < RailsSettings::Base
  cache_prefix { "v1" }

  field :synth_api_key, type: :string, default: ENV["SYNTH_API_KEY"]
  field :openai_access_token, type: :string, default: ENV["OPENAI_ACCESS_TOKEN"]

  # Lunchflow-Supabase integration settings
  field :supabase_url, type: :string, default: ENV["SUPABASE_URL"]
  field :supabase_key, type: :string, default: ENV["SUPABASE_SERVICE_ROLE_KEY"]
  field :lunchflow_api_key, type: :string, default: ENV["LUNCHFLOW_API_KEY"]

  field :require_invite_for_signup, type: :boolean, default: false
  field :require_email_confirmation, type: :boolean, default: ENV.fetch("REQUIRE_EMAIL_CONFIRMATION", "true") == "true"
end
```

### Step 4: Run test to verify it passes

**Command:**
```bash
bin/rails test test/models/setting_test.rb
```

**Expected:** PASS - all tests green

### Step 5: Commit

```bash
git add app/models/setting.rb test/models/setting_test.rb
git commit -m "feat: add Supabase and Lunchflow settings fields to Setting model"
```

---

## Task 2: Update SupabaseClient with Fallback Hierarchy

**Files:**
- Modify: `app/services/supabase_client.rb:1-30`
- Test: `test/services/supabase_client_test.rb`

### Step 1: Write failing test for SupabaseClient.from_settings

**File:** `test/services/supabase_client_test.rb`

```ruby
require "test_helper"

class SupabaseClientTest < ActiveSupport::TestCase
  teardown do
    Setting.supabase_url = nil
    Setting.supabase_key = nil
  end

  test "from_settings uses ENV variables first" do
    ClimateControl.modify(
      SUPABASE_URL: "https://env.supabase.co",
      SUPABASE_SERVICE_ROLE_KEY: "env-key"
    ) do
      Setting.supabase_url = "https://setting.supabase.co"
      Setting.supabase_key = "setting-key"

      client = SupabaseClient.from_settings

      assert_equal "https://env.supabase.co", client.url
      assert_equal "env-key", client.key
    end
  end

  test "from_settings falls back to Setting when ENV not set" do
    ClimateControl.modify(SUPABASE_URL: nil, SUPABASE_SERVICE_ROLE_KEY: nil) do
      Setting.supabase_url = "https://setting.supabase.co"
      Setting.supabase_key = "setting-key"

      client = SupabaseClient.from_settings

      assert_equal "https://setting.supabase.co", client.url
      assert_equal "setting-key", client.key
    end
  end

  test "from_settings raises error when no credentials configured" do
    ClimateControl.modify(SUPABASE_URL: nil, SUPABASE_SERVICE_ROLE_KEY: nil) do
      Setting.supabase_url = nil
      Setting.supabase_key = nil

      error = assert_raises(RuntimeError) do
        SupabaseClient.from_settings
      end

      assert_match(/Supabase credentials not configured/, error.message)
    end
  end

  test "from_settings raises error when only URL is configured" do
    ClimateControl.modify(SUPABASE_URL: nil, SUPABASE_SERVICE_ROLE_KEY: nil) do
      Setting.supabase_url = "https://test.supabase.co"
      Setting.supabase_key = nil

      error = assert_raises(RuntimeError) do
        SupabaseClient.from_settings
      end

      assert_match(/Supabase credentials not configured/, error.message)
    end
  end
end
```

### Step 2: Run test to verify it fails

**Command:**
```bash
bin/rails test test/services/supabase_client_test.rb
```

**Expected:** FAIL - undefined method `from_settings` for SupabaseClient

### Step 3: Update SupabaseClient with from_settings class method

**File:** `app/services/supabase_client.rb`

Add `attr_reader :url, :key` and the `.from_settings` class method:

```ruby
class SupabaseClient
  attr_reader :url, :key

  def initialize(url:, key:)
    @url = url
    @key = key
  end

  # Class method to create client from settings with fallback hierarchy
  def self.from_settings
    url = ENV["SUPABASE_URL"] ||
          Rails.application.credentials.dig(:supabase, :url) ||
          Setting.supabase_url

    key = ENV["SUPABASE_SERVICE_ROLE_KEY"] ||
          Rails.application.credentials.dig(:supabase, :key) ||
          Setting.supabase_key

    raise "Supabase credentials not configured. Please set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY." if url.blank? || key.blank?

    new(url: url, key: key)
  end

  # ... rest of existing methods ...
end
```

### Step 4: Run test to verify it passes

**Command:**
```bash
bin/rails test test/services/supabase_client_test.rb
```

**Expected:** PASS - all tests green

### Step 5: Commit

```bash
git add app/services/supabase_client.rb test/services/supabase_client_test.rb
git commit -m "feat: add SupabaseClient.from_settings with ENV/credentials/Setting fallback"
```

---

## Task 3: Update LunchflowConnection to Use from_settings

**Files:**
- Modify: `app/models/lunchflow_connection.rb:45-51`
- Test: `test/models/lunchflow_connection_test.rb`

### Step 1: Write failing test for supabase_client method

**File:** `test/models/lunchflow_connection_test.rb`

Add test to verify it uses the new from_settings method:

```ruby
test "supabase_client uses SupabaseClient.from_settings" do
  ClimateControl.modify(
    SUPABASE_URL: "https://test.supabase.co",
    SUPABASE_SERVICE_ROLE_KEY: "test-key"
  ) do
    connection = lunchflow_connections(:one)
    client = connection.supabase_client

    assert_instance_of SupabaseClient, client
    assert_equal "https://test.supabase.co", client.url
    assert_equal "test-key", client.key
  end
end

test "supabase_client caches the client instance" do
  ClimateControl.modify(
    SUPABASE_URL: "https://test.supabase.co",
    SUPABASE_SERVICE_ROLE_KEY: "test-key"
  ) do
    connection = lunchflow_connections(:one)
    client1 = connection.supabase_client
    client2 = connection.supabase_client

    assert_same client1, client2
  end
end
```

### Step 2: Run test to verify current behavior

**Command:**
```bash
bin/rails test test/models/lunchflow_connection_test.rb::test_supabase_client_uses_SupabaseClient.from_settings
```

**Expected:** May PASS or FAIL depending on current implementation - we're refactoring

### Step 3: Update LunchflowConnection#supabase_client method

**File:** `app/models/lunchflow_connection.rb`

Replace the existing `supabase_client` method:

```ruby
def supabase_client
  @supabase_client ||= SupabaseClient.from_settings
end
```

### Step 4: Run test to verify it passes

**Command:**
```bash
bin/rails test test/models/lunchflow_connection_test.rb
```

**Expected:** PASS - all tests green

### Step 5: Commit

```bash
git add app/models/lunchflow_connection.rb test/models/lunchflow_connection_test.rb
git commit -m "refactor: update LunchflowConnection to use SupabaseClient.from_settings"
```

---

## Task 4: Update Settings::HostingsController

**Files:**
- Modify: `app/controllers/settings/hostings_controller.rb:13-40`
- Test: `test/controllers/settings/hostings_controller_test.rb`

### Step 1: Write failing test for updating Lunchflow settings

**File:** `test/controllers/settings/hostings_controller_test.rb`

Add tests for new settings:

```ruby
test "can update supabase_url setting" do
  sign_in users(:family_admin)

  patch settings_hosting_path, params: {
    setting: { supabase_url: "https://new-project.supabase.co" }
  }

  assert_redirected_to settings_hosting_path
  assert_equal "https://new-project.supabase.co", Setting.supabase_url
  follow_redirect!
  assert_select ".notice", text: /successfully updated/i
end

test "can update supabase_key setting" do
  sign_in users(:family_admin)

  patch settings_hosting_path, params: {
    setting: { supabase_key: "new-secret-key-123" }
  }

  assert_redirected_to settings_hosting_path
  assert_equal "new-secret-key-123", Setting.supabase_key
end

test "can update lunchflow_api_key setting" do
  sign_in users(:family_admin)

  patch settings_hosting_path, params: {
    setting: { lunchflow_api_key: "lf-new-key-456" }
  }

  assert_redirected_to settings_hosting_path
  assert_equal "lf-new-key-456", Setting.lunchflow_api_key
end

test "can update multiple lunchflow settings at once" do
  sign_in users(:family_admin)

  patch settings_hosting_path, params: {
    setting: {
      supabase_url: "https://multi.supabase.co",
      supabase_key: "multi-key",
      lunchflow_api_key: "multi-lf-key"
    }
  }

  assert_redirected_to settings_hosting_path
  assert_equal "https://multi.supabase.co", Setting.supabase_url
  assert_equal "multi-key", Setting.supabase_key
  assert_equal "multi-lf-key", Setting.lunchflow_api_key
end
```

### Step 2: Run test to verify it fails

**Command:**
```bash
bin/rails test test/controllers/settings/hostings_controller_test.rb
```

**Expected:** FAIL - parameters not permitted or settings not saved

### Step 3: Update controller strong params

**File:** `app/controllers/settings/hostings_controller.rb`

Update the `hosting_params` method to permit new fields:

```ruby
private
  def hosting_params
    params.require(:setting).permit(
      :require_invite_for_signup,
      :require_email_confirmation,
      :synth_api_key,
      :supabase_url,
      :supabase_key,
      :lunchflow_api_key
    )
  end
```

### Step 4: Update controller update action

**File:** `app/controllers/settings/hostings_controller.rb`

Add logic to update new settings in the `update` method (after line 24):

```ruby
def update
  if hosting_params.key?(:require_invite_for_signup)
    Setting.require_invite_for_signup = hosting_params[:require_invite_for_signup]
  end

  if hosting_params.key?(:require_email_confirmation)
    Setting.require_email_confirmation = hosting_params[:require_email_confirmation]
  end

  if hosting_params.key?(:synth_api_key)
    Setting.synth_api_key = hosting_params[:synth_api_key]
  end

  # Lunchflow-Supabase settings
  if hosting_params.key?(:supabase_url)
    Setting.supabase_url = hosting_params[:supabase_url]
  end

  if hosting_params.key?(:supabase_key)
    Setting.supabase_key = hosting_params[:supabase_key]
  end

  if hosting_params.key?(:lunchflow_api_key)
    Setting.lunchflow_api_key = hosting_params[:lunchflow_api_key]
  end

  redirect_to settings_hosting_path, notice: t(".success")
rescue ActiveRecord::RecordInvalid => error
  flash.now[:alert] = t(".failure")
  render :show, status: :unprocessable_entity
end
```

### Step 5: Run test to verify it passes

**Command:**
```bash
bin/rails test test/controllers/settings/hostings_controller_test.rb
```

**Expected:** PASS - all tests green

### Step 6: Commit

```bash
git add app/controllers/settings/hostings_controller.rb test/controllers/settings/hostings_controller_test.rb
git commit -m "feat: add Lunchflow-Supabase settings to HostingsController"
```

---

## Task 5: Create Lunchflow Settings View Partial

**Files:**
- Create: `app/views/settings/hostings/_lunchflow_settings.html.erb`

### Step 1: Create the partial following synth_settings pattern

**File:** `app/views/settings/hostings/_lunchflow_settings.html.erb`

```erb
<div class="space-y-4">
  <div>
    <h2 class="font-medium mb-1">Lunchflow Integration</h2>
    <% if ENV["SUPABASE_URL"].present? %>
      <p class="text-sm text-secondary">Supabase credentials are configured through environment variables.</p>
    <% else %>
      <p class="text-secondary text-sm mb-4">Configure Supabase connection for Lunchflow data sync.</p>
    <% end %>
  </div>

  <%= styled_form_with model: Setting.new,
                       url: settings_hosting_path,
                       method: :patch,
                       data: {
                         controller: "auto-submit-form",
                         "auto-submit-form-trigger-event-value": "blur"
                       } do |form| %>
    <%= form.text_field :supabase_url,
                        label: "Supabase URL",
                        placeholder: "https://your-project.supabase.co",
                        value: ENV.fetch("SUPABASE_URL", Setting.supabase_url),
                        disabled: ENV["SUPABASE_URL"].present?,
                        data: { "auto-submit-form-target": "auto" } %>

    <%= form.text_field :supabase_key,
                        label: "Supabase Service Role Key",
                        type: "password",
                        placeholder: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                        value: ENV.fetch("SUPABASE_SERVICE_ROLE_KEY", Setting.supabase_key),
                        disabled: ENV["SUPABASE_SERVICE_ROLE_KEY"].present?,
                        data: { "auto-submit-form-target": "auto" } %>

    <%= form.text_field :lunchflow_api_key,
                        label: "Lunchflow API Key",
                        type: "password",
                        placeholder: "Your Lunchflow API key",
                        value: ENV.fetch("LUNCHFLOW_API_KEY", Setting.lunchflow_api_key),
                        disabled: ENV["LUNCHFLOW_API_KEY"].present?,
                        data: { "auto-submit-form-target": "auto" } %>
  <% end %>

  <div class="bg-blue-50 border border-blue-200 rounded-md p-3">
    <p class="text-xs text-blue-900">
      <strong>Note:</strong> After updating the Lunchflow API Key, you must update your Supabase edge function secret:<br>
      <code class="bg-blue-100 px-1 py-0.5 rounded text-xs">supabase secrets set LUNCHFLOW_API_KEY=your_key</code>
    </p>
  </div>
</div>
```

### Step 2: Verify the partial matches design system

**Command:**
```bash
grep -n "text-secondary\|bg-blue-50\|border-blue-200" app/assets/tailwind/maybe-design-system.css
```

**Expected:** Verify these classes exist in design system (or adjust to use functional tokens)

### Step 3: Commit

```bash
git add app/views/settings/hostings/_lunchflow_settings.html.erb
git commit -m "feat: create Lunchflow settings partial for admin UI"
```

---

## Task 6: Add Lunchflow Section to Settings View

**Files:**
- Modify: `app/views/settings/hostings/show.html.erb:1-16`

### Step 1: Read current view structure

**Command:**
```bash
cat app/views/settings/hostings/show.html.erb
```

**Expected:** See existing sections (General, Invites, Danger Zone)

### Step 2: Add Lunchflow Integration section

**File:** `app/views/settings/hostings/show.html.erb`

Add new section after the "General" section:

```erb
<%= content_for :page_title, t(".title") %>

<%= settings_section title: t(".general") do %>
  <div class="space-y-6">
    <%= render "settings/hostings/synth_settings" %>
  </div>
<% end %>

<%= settings_section title: "Lunchflow Integration" do %>
  <div class="space-y-6">
    <%= render "settings/hostings/lunchflow_settings" %>
  </div>
<% end %>

<%= settings_section title: t(".invites") do %>
  <%= render "settings/hostings/invite_code_settings" %>
<% end %>

<%= settings_section title: t(".danger_zone") do %>
  <%= render "settings/hostings/danger_zone_settings" %>
<% end %>
```

### Step 3: Verify the view renders without errors

**Command:**
```bash
bin/rails server
# Visit http://localhost:3000/settings/hosting in browser
```

**Expected:** Page loads, new "Lunchflow Integration" section visible

### Step 4: Commit

```bash
git add app/views/settings/hostings/show.html.erb
git commit -m "feat: add Lunchflow Integration section to hosting settings page"
```

---

## Task 7: Manual Integration Testing

**Files:**
- N/A (manual browser testing)

### Step 1: Start development server

**Command:**
```bash
bin/dev
```

### Step 2: Navigate to Settings page

1. Open browser to `http://localhost:3000`
2. Sign in as admin user
3. Navigate to Settings > Self Hosting

### Step 3: Test form submission

1. Enter Supabase URL: `https://test-project.supabase.co`
2. Tab to next field (should auto-submit)
3. Verify success notice appears
4. Refresh page and verify value persists

### Step 4: Test password field masking

1. Enter Supabase Service Role Key: `test-secret-key-123`
2. Verify field shows dots instead of characters
3. Tab to next field (should auto-submit)

### Step 5: Test ENV variable precedence

**Command:**
```bash
# Stop server
# Set ENV variable
export SUPABASE_URL="https://env-override.supabase.co"
# Restart server
bin/dev
```

1. Navigate to Settings > Self Hosting
2. Verify Supabase URL field is disabled
3. Verify field shows ENV value
4. Unset ENV and restart to continue testing

### Step 6: Test LunchflowConnection sync with new settings

**Command:**
```bash
bin/rails console
```

```ruby
# Set settings
Setting.supabase_url = "https://your-actual-project.supabase.co"
Setting.supabase_key = "your-actual-service-role-key"
Setting.lunchflow_api_key = "your-actual-lunchflow-key"

# Test connection
connection = LunchflowConnection.first
client = connection.supabase_client
puts "Connected to: #{client.url}"

# Trigger sync (if Supabase is configured)
connection.sync
```

**Expected:** No errors, sync completes successfully

### Step 7: Document testing results

Create a checklist of verified functionality:

- [ ] Form renders in Settings > Self Hosting
- [ ] Auto-submit works on blur
- [ ] Success notice appears after save
- [ ] Values persist after page refresh
- [ ] Password fields mask input
- [ ] ENV variables disable and override fields
- [ ] SupabaseClient.from_settings uses correct fallback
- [ ] LunchflowConnection sync works with new settings

---

## Task 8: Update Documentation

**Files:**
- Modify: `docs/lunchflow-setup.md`

### Step 1: Add configuration section to setup docs

**File:** `docs/lunchflow-setup.md`

Add section on configuring credentials through admin UI:

```markdown
## Configuration

### Option 1: Admin UI (Recommended for Self-Hosted)

1. Navigate to Settings > Self Hosting
2. Scroll to "Lunchflow Integration" section
3. Enter:
   - **Supabase URL**: Your Supabase project URL (e.g., `https://abcdefg.supabase.co`)
   - **Supabase Service Role Key**: From Supabase Dashboard > Settings > API
   - **Lunchflow API Key**: Your Lunchflow API key
4. Each field auto-saves on blur
5. Update Supabase edge function secret:
   ```bash
   supabase secrets set LUNCHFLOW_API_KEY=your_lunchflow_api_key
   ```

### Option 2: Environment Variables (Recommended for Production)

Set environment variables (highest precedence):

```bash
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"
export LUNCHFLOW_API_KEY="your-lunchflow-api-key"
```

### Option 3: Rails Credentials (Legacy)

Edit encrypted credentials:

```bash
rails credentials:edit
```

Add:

```yaml
supabase:
  url: https://your-project.supabase.co
  key: your-service-role-key
```

### Credential Precedence

The system checks credentials in this order:
1. Environment variables (highest priority)
2. Rails credentials
3. Database settings (via admin UI)
```

### Step 2: Commit documentation

```bash
git add docs/lunchflow-setup.md
git commit -m "docs: add admin UI configuration instructions for Lunchflow"
```

---

## Task 9: Run Full Test Suite

**Files:**
- N/A (verification step)

### Step 1: Run all model tests

**Command:**
```bash
bin/rails test test/models/
```

**Expected:** All tests PASS

### Step 2: Run all controller tests

**Command:**
```bash
bin/rails test test/controllers/
```

**Expected:** All tests PASS

### Step 3: Run all service tests

**Command:**
```bash
bin/rails test test/services/
```

**Expected:** All tests PASS

### Step 4: Run linting

**Command:**
```bash
bin/rubocop -f github -a
```

**Expected:** No offenses or auto-corrected

### Step 5: Run security scan

**Command:**
```bash
bin/brakeman --no-pager
```

**Expected:** No new security warnings

### Step 6: Final commit if any auto-corrections

```bash
git add -A
git commit -m "chore: auto-fix linting issues"
```

---

## Task 10: Create Pull Request

**Files:**
- N/A (Git operations)

### Step 1: Push branch to remote

**Command:**
```bash
git push -u origin feature/lunchflow-supabase-integration
```

### Step 2: Create pull request

**Command:**
```bash
gh pr create --title "feat: add admin UI for Lunchflow-Supabase settings" --body "$(cat <<'EOF'
## Summary

Adds admin settings UI to configure global Supabase and Lunchflow credentials through Settings > Self Hosting page, eliminating the need to manually edit Rails credentials files.

## Changes

- **Setting Model**: Added `supabase_url`, `supabase_key`, `lunchflow_api_key` fields
- **SupabaseClient**: Added `.from_settings` class method with ENV → credentials → database fallback
- **LunchflowConnection**: Updated to use `SupabaseClient.from_settings`
- **Settings::HostingsController**: Added support for new settings
- **Views**: Created Lunchflow settings partial, added section to hosting settings page
- **Tests**: Added comprehensive model, controller, and service tests
- **Docs**: Updated lunchflow-setup.md with configuration instructions

## Testing

- [ ] All tests pass (`bin/rails test`)
- [ ] Linting passes (`bin/rubocop -f github -a`)
- [ ] Security scan passes (`bin/brakeman --no-pager`)
- [ ] Manual testing: Form renders and auto-submits correctly
- [ ] Manual testing: ENV variables override database settings
- [ ] Manual testing: LunchflowConnection sync works with new settings

## Configuration

Settings can be configured through:
1. **Admin UI**: Settings > Self Hosting > Lunchflow Integration (self-hosted mode only)
2. **ENV variables**: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `LUNCHFLOW_API_KEY`
3. **Rails credentials**: Legacy support maintained

Precedence: ENV > Rails credentials > Database settings

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
EOF
)"
```

### Step 3: Verify PR created successfully

**Expected:** PR URL returned, e.g., `https://github.com/user/repo/pull/123`

---

## Success Criteria

- [x] Setting model has new fields with ENV defaults
- [x] SupabaseClient.from_settings implements fallback hierarchy
- [x] LunchflowConnection uses new settings method
- [x] Controller permits and saves new settings
- [x] Form section renders in Settings > Self Hosting
- [x] Auto-submit works on blur
- [x] Password fields mask sensitive values
- [x] ENV variables disable and override fields
- [x] All tests pass
- [x] Linting passes
- [x] Security scan passes
- [x] Documentation updated
- [x] Pull request created

---

## Post-Implementation Notes

### Edge Function Secret Update

After updating the Lunchflow API Key through the admin UI, admins must manually update the Supabase edge function secret:

```bash
cd supabase
supabase secrets set LUNCHFLOW_API_KEY=new_key_value
```

This is by design - the Supabase Management API requires additional credentials and complexity. The manual CLI approach is simpler and more reliable for self-hosted deployments.

### Security Considerations

- Credentials are stored in plain text in the database (matches existing Setting pattern for synth_api_key)
- ENV variables provide more secure option and take precedence
- Self-hosted mode only (managed mode users cannot access)
- Password field type masks values in browser
- CSRF protection via Rails built-in

### Future Enhancements

- Add "Test Connection" button to validate Supabase credentials before saving
- Add ActiveRecord encryption for Setting fields (requires broader refactor)
- Automate Supabase edge function secret updates via Management API
- Add audit logging for credential changes
