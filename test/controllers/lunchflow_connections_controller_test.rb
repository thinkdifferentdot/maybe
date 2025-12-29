require "test_helper"

class LunchflowConnectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    sign_in @user
    @connection = lunchflow_connections(:dylan_lunchflow)
  end

  test "should get index" do
    get lunchflow_connections_url
    assert_response :success
  end

  test "should get new" do
    get new_lunchflow_connection_url
    assert_response :success
  end

  test "should create lunchflow_connection" do
    assert_difference("LunchflowConnection.count") do
      post lunchflow_connections_url, params: {
        lunchflow_connection: { name: "New Connection" }
      }
    end

    assert_redirected_to lunchflow_connections_url
  end

  test "should sync connection" do
    # Mocha expectation
    LunchflowConnection.any_instance.expects(:sync_later).once

    post sync_lunchflow_connection_url(@connection)
    assert_redirected_to lunchflow_connections_url
  end

  test "should destroy connection" do
    assert_difference("LunchflowConnection.count", -1) do
      delete lunchflow_connection_url(@connection)
    end

    assert_redirected_to lunchflow_connections_url
  end
end
