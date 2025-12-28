require "test_helper"

class SyncLunchflowConnectionsJobTest < ActiveJob::TestCase
  test "syncs all active lunchflow connections" do
    connection = lunchflow_connections(:dylan_lunchflow)

    # Stub the sync_later method
    LunchflowConnection.any_instance.expects(:sync_later).once

    SyncLunchflowConnectionsJob.perform_now
  end
end
