unless Rails.env.local?
  Rails.application.configure do
    config.lograge.enabled = true
    config.lograge.formatter = Lograge::Formatters::Json.new

    config.lograge.ignore_custom = lambda do |event|
      event.payload[:path] == "/up"
    end

    config.lograge.custom_options = lambda do |event|
      exceptions = %w[controller action format id]
      params = event.payload[:params]&.except(*exceptions) || {}

      {
        request_id: event.payload[:headers]&.fetch("action_dispatch.request_id", nil),
        user_id: event.payload[:user_id],
        remote_ip: event.payload[:remote_ip],
        params: params,
        time: Time.current.iso8601(3)
      }.compact
    end

    config.lograge.custom_payload do |controller|
      {
        user_id: controller.current_user&.id,
        remote_ip: controller.request.remote_ip
      }
    end
  end
end
