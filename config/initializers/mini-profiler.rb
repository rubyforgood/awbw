if defined?(Rack::MiniProfiler)
  # Enable in development and staging, disable in production
  if Rails.env.production?
    Rack::MiniProfiler.config.enabled = false
  elsif Rails.env.staging?
    Rack::MiniProfiler.config.enabled = true
    Rack::MiniProfiler.config.position = "bottom-left"
    Rack::MiniProfiler.config.enable_hotwire_turbo_drive_support = true
  else
    Rack::MiniProfiler.config.enabled = true
    Rack::MiniProfiler.config.position = "bottom-left"
    Rack::MiniProfiler.config.enable_hotwire_turbo_drive_support = true
  end
end
