require "test_helper"

class SettingTest < ActiveSupport::TestCase
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
