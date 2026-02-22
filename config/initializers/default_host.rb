# Derive the default host from PORT so Conductor workspaces each get
# their own URL automatically. CONDUCTOR_PORT is set by Conductor and
# flows into PORT via bin/conductor-server.
#
# In production, APP_HOST is set explicitly in the environment.

if Rails.env.development?
  port = ENV.fetch("PORT", 3000)
  default_host = "localhost:#{port}"

  Rails.application.routes.default_url_options[:host] = default_host

  Rails.application.config.action_mailer.default_url_options = {
    host: "localhost", port: port, protocol: "http"
  }

  Rails.application.config.after_initialize do
    ActiveStorage::Current.url_options = {
      protocol: "http",
      host: "localhost",
      port: port
    }
  end
end
