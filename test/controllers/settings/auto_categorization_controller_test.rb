require "test_helper"

class Settings::AutoCategorizationControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
    Setting.ai_categorize_on_import = false
    Setting.ai_categorize_on_sync = false
    Setting.ai_categorize_on_ui_action = false
  end

  test "should get show" do
    get settings_auto_categorization_url
    assert_response :success
  end

  test "can update ai_categorize_on_import" do
    patch settings_auto_categorization_url, params: { setting: { ai_categorize_on_import: "1" } }

    assert_redirected_to settings_auto_categorization_url
    assert_equal true, Setting.ai_categorize_on_import?
  end

  test "can update ai_categorize_on_sync" do
    patch settings_auto_categorization_url, params: { setting: { ai_categorize_on_sync: "1" } }

    assert_redirected_to settings_auto_categorization_url
    assert_equal true, Setting.ai_categorize_on_sync?
  end

  test "can update ai_categorize_on_ui_action" do
    patch settings_auto_categorization_url, params: { setting: { ai_categorize_on_ui_action: "1" } }

    assert_redirected_to settings_auto_categorization_url
    assert_equal true, Setting.ai_categorize_on_ui_action?
  end

  test "can turn off settings" do
    Setting.ai_categorize_on_import = true

    patch settings_auto_categorization_url, params: { setting: { ai_categorize_on_import: "0" } }

    assert_redirected_to settings_auto_categorization_url
    assert_equal false, Setting.ai_categorize_on_import?
  end

  test "cannot update when not admin" do
    sign_in users(:family_member)

    patch settings_auto_categorization_url, params: { setting: { ai_categorize_on_import: "1" } }

    assert_redirected_to settings_auto_categorization_url
    assert_equal false, Setting.ai_categorize_on_import?
  end
end
