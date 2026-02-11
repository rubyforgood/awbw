if defined?(Rack::MiniProfiler)
  # Enable only in non-production environments
  if Rails.env.production?
    Rack::MiniProfiler.config.enabled = false
  else
    Rack::MiniProfiler.config.enabled = true
    Rack::MiniProfiler.config.position = "bottom-left"

    Rack::MiniProfiler.config.enable_hotwire_turbo_drive_support = true
  end
end
