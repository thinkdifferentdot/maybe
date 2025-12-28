class SyncLunchflowConnectionsJob < ApplicationJob
  queue_as :default

  def perform
    LunchflowConnection.active.find_each do |connection|
      connection.sync_later
    end
  end
end
