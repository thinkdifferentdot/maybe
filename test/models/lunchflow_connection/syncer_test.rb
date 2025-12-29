require "test_helper"

class LunchflowConnection::SyncerTest < ActiveSupport::TestCase
  setup do
    @connection = lunchflow_connections(:dylan_lunchflow)
    @syncer = LunchflowConnection::Syncer.new(@connection)
  end

  test "initializes with connection" do
    assert_equal @connection, @syncer.instance_variable_get(:@connection)
  end

  test "perform_sync invokes edge function, fetches accounts and creates lunchflow_accounts" do
    mock_client = Minitest::Mock.new
    mock_query = Minitest::Mock.new

    # Expect edge function trigger
    mock_client.expect(:invoke_function, { "success" => true }, ["sync-lunchflow"])

    # Mock the supabase client chain
    mock_query.expect(:select, mock_query, ["*"])
    mock_query.expect(:eq, mock_query, ["status", "ACTIVE"])
    mock_query.expect(:execute, [
      {
        "id" => 999,
        "name" => "Test Checking",
        "institution_name" => "Test Bank",
        "institution_logo" => nil,
        "provider" => "gocardless",
        "currency" => "USD",
        "status" => "ACTIVE"
      }
    ])

    mock_client.expect(:from, mock_query, ["lunchflow_accounts"])

    # Mock transactions query (return empty)
    txn_query = Minitest::Mock.new
    txn_query.expect(:select, txn_query, ["*"])
    txn_query.expect(:eq, txn_query, ["account_id", 999])
    txn_query.expect(:order, txn_query, ["date"])
    txn_query.expect(:execute, [])
    mock_client.expect(:from, txn_query, ["lunchflow_transactions"])

    # Mock balance query
    bal_query = Minitest::Mock.new
    bal_query.expect(:select, bal_query, ["*"])
    bal_query.expect(:eq, bal_query, ["account_id", 999])
    bal_query.expect(:order, bal_query, ["synced_at"])
    bal_query.expect(:limit, bal_query, [1])
    bal_query.expect(:single, bal_query)
    bal_query.expect(:execute, nil)
    mock_client.expect(:from, bal_query, ["lunchflow_balances"])

    @connection.stub(:supabase_client, mock_client) do
      sync = @connection.syncs.create!
      @syncer.perform_sync(sync)
    end

    lunchflow_account = @connection.lunchflow_accounts.find_by(lunchflow_id: 999)
    assert_not_nil lunchflow_account
    assert_equal "Test Checking", lunchflow_account.name
    mock_client.verify
  end
end
