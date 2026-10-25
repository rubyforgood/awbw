unless Rails.env.local?
  require "opentelemetry/sdk"
  require "opentelemetry/exporter/otlp"
  require "opentelemetry/instrumentation/all"

  class OpenTelemetryLogger < Logger
    INSTALLED_MESSAGE = /\AInstrumentation: .+ was successfully installed/

    def add(severity, message = nil, progname = nil, &block)
      return true if (message || progname).to_s.match?(INSTALLED_MESSAGE)

      super
    end
  end

  OpenTelemetry::SDK.configure do |c|
    c.logger = OpenTelemetryLogger.new($stdout)
    c.use_all()
  end
end
