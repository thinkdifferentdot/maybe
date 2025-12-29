require "test_helper"
require "webmock/minitest"

class SupabaseClientTest < ActiveSupport::TestCase
  include WebMock::API

  setup do
    @client = SupabaseClient.new(
      url: "https://test.supabase.co",
      key: "test-key"
    )
  end

  teardown do
    Setting.supabase_url = nil
    Setting.supabase_key = nil
  end

  test "initializes with url and key" do
    assert_equal "https://test.supabase.co", @client.url
  end

  test "builds correct headers" do
    headers = @client.send(:headers)
    assert_equal "Bearer test-key", headers["Authorization"]
    assert_equal "test-key", headers["apikey"]
  end

  test "from method queries table with filters" do
    # This tests the query builder interface
    query = @client.from("lunchflow_accounts")
    assert_kind_of SupabaseClient::QueryBuilder, query
  end

  test "invoke_function calls edge function" do
    stub_request(:post, "https://test.supabase.co/functions/v1/test-func")
      .with(headers: { "Authorization" => "Bearer test-key" })
      .to_return(status: 200, body: '{"success":true}', headers: {})

    response = @client.invoke_function("test-func")
    assert response["success"]
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
