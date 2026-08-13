# Suppress benign shutdown noise. When a pod is terminated (deploy, restart,
# scale-down) the DB connection pool closes while SolidQueue's supervisor is
# still trying to deregister its Process record, so that final query fails with
# a closed connection. There's no request, no user, and nothing is lost — it's
# just restart noise, so we drop it rather than page on it.
#
# Kept narrow on purpose: only closed-connection errors with no component (i.e.
# outside any web request or job) are dropped, so a genuine mid-request DB
# outage still reports.
Honeybadger.configure do |config|
  shutdown_error_classes = %w[
    ActiveRecord::ConnectionNotEstablished
    Trilogy::EOFError
  ]

  config.before_notify do |notice|
    connection_error = shutdown_error_classes.include?(notice.error_class)
    closed_connection = notice.error_message.to_s.include?("TRILOGY_CLOSED_CONNECTION")
    outside_request = notice.component.blank?

    notice.halt! if connection_error && closed_connection && outside_request
  end
end
