require "test_helper"

class Settings::AutoCategorizationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
  end

  test "should get edit" do
    get edit_settings_auto_categorization_url
    assert_response :success
  end

  test "can update string setting" do
    patch settings_auto_categorization_url, params: {
      setting: { openai_categorization_model: "gpt-4-turbo" }
    }
    assert_redirected_to edit_settings_auto_categorization_url
    assert_equal "gpt-4-turbo", Setting.openai_categorization_model
  end

  test "can update auto categorization settings" do
    patch settings_auto_categorization_url, params: {
      setting: {
        categorization_confidence_threshold: 75,
        categorization_batch_size: 100,
        categorization_null_tolerance: "balanced",
        categorization_prefer_subcategories: false
      }
    }

    assert_redirected_to edit_settings_auto_categorization_url
    assert_equal 75, Setting.categorization_confidence_threshold
    assert_equal 100, Setting.categorization_batch_size
    assert_equal "balanced", Setting.categorization_null_tolerance
    assert_equal false, Setting.categorization_prefer_subcategories
  end

  test "rejects invalid settings" do
    patch settings_auto_categorization_url, params: {
      setting: { categorization_confidence_threshold: 150 }
    }

    assert_response :unprocessable_entity
    # Value should not change
    assert_not_equal 150, Setting.categorization_confidence_threshold
  end

  test "rejects invalid batch size" do
    patch settings_auto_categorization_url, params: {
      setting: { categorization_batch_size: 5 }
    }

    assert_response :unprocessable_entity
  end
end
