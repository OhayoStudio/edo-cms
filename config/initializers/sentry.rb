Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]
  config.traces_sample_rate = 1.0
  config.enabled_environments = %w[production]
  # sentry-rails 7 ships Rails logs to Sentry Logs by default; keep them local.
  config.rails.structured_logging.enabled = false
end
