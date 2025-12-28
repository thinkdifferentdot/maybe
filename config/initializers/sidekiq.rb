require "sidekiq/web"

if Rails.env.production?
  Sidekiq::Web.use(Rack::Auth::Basic) do |username, password|
    configured_username = ::Digest::SHA256.hexdigest(ENV.fetch("SIDEKIQ_WEB_USERNAME", "maybe"))
    configured_password = ::Digest::SHA256.hexdigest(ENV.fetch("SIDEKIQ_WEB_PASSWORD", "maybe"))

    ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(username), configured_username) &&
      ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(password), configured_password)
  end
end

Sidekiq::Cron.configure do |config|
  # 10 min "catch-up" window in case worker process is re-deploying when cron tick occurs
  config.reschedule_grace_period = 600
end

Sidekiq.configure_server do |config|
  config.on(:startup) do
    schedule = [
      {
        "name" => "sync_lunchflow_connections",
        "cron" => "0 */6 * * *", # Every 6 hours
        "class" => "SyncLunchflowConnectionsJob"
      }
    ]

    Sidekiq::Cron::Job.load_from_array(schedule)
  end
end
