if Rails.env.production?
  require "opentelemetry/sdk"
  require "opentelemetry/exporter/otlp"
  require "opentelemetry/instrumentation/all"

  OpenTelemetry::SDK.configure do |c|
    c.service_name = ENV.fetch("OTEL_SERVICE_NAME", "awbw")

    c.add_span_processor(
      OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
        OpenTelemetry::Exporter::OTLP::Exporter.new(
          endpoint: "https://api.honeycomb.io",
          headers: { "x-honeycomb-team" => ENV.fetch("HONEYCOMB_API_KEY") }
        )
      )
    )

    c.use_all
  end
end
