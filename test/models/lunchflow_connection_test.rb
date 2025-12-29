require "test_helper"

class LunchflowConnectionTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
  end

  test "belongs to family" do
    connection = LunchflowConnection.new(
      family: @family,
      name: "Test Connection"
    )
    assert connection.valid?
    assert_equal @family, connection.family
  end

  test "requires name" do
    connection = LunchflowConnection.new(family: @family)
    assert_not connection.valid?
    assert_includes connection.errors[:name], "can't be blank"
  end

  test "has default active status" do
    connection = LunchflowConnection.create!(
      family: @family,
      name: "Test Connection"
    )
    assert_equal "active", connection.status
  end

  test "active scope returns only active connections" do
    active = LunchflowConnection.create!(family: @family, name: "Active", status: "active")
    inactive = LunchflowConnection.create!(family: @family, name: "Inactive", status: "inactive")

    assert_includes LunchflowConnection.active, active
    assert_not_includes LunchflowConnection.active, inactive
  end

  test "supabase_client uses SupabaseClient.from_settings" do
    ClimateControl.modify(
      SUPABASE_URL: "https://test.supabase.co",
      SUPABASE_SERVICE_ROLE_KEY: "test-key"
    ) do
      connection = LunchflowConnection.create!(family: @family, name: "Test Connection")
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
      connection = LunchflowConnection.create!(family: @family, name: "Test Connection")
      client1 = connection.supabase_client
      client2 = connection.supabase_client

      assert_same client1, client2
    end
  end
end
