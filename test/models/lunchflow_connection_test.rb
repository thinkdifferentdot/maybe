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
end
