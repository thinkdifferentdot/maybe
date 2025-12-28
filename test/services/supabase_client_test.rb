require "test_helper"

class SupabaseClientTest < ActiveSupport::TestCase
  setup do
    @client = SupabaseClient.new(
      url: "https://test.supabase.co",
      key: "test-key"
    )
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
end
