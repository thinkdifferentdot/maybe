class LunchflowConnection::SyncCompleteEvent
  attr_reader :lunchflow_connection

  def initialize(lunchflow_connection)
    @lunchflow_connection = lunchflow_connection
  end

  def broadcast
    lunchflow_connection.accounts.each do |account|
      account.broadcast_sync_complete
    end

    lunchflow_connection.family.broadcast_sync_complete
  end
end
