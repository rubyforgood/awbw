if defined?(Rack::MiniProfiler)
  Rack::MiniProfiler.config.enabled =
    if Rails.env.development?
      true
    else
      ENV.fetch("RACK_MINI_PROFILER", "false").downcase == "true"
    end

  Rack::MiniProfiler.config.position = "bottom-left"
  Rack::MiniProfiler.config.enable_hotwire_turbo_drive_support = true
end
