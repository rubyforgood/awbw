# Derive the default host from PORT so Conductor workspaces each get
# their own URL automatically. CONDUCTOR_PORT is set by Conductor and
# flows into PORT via bin/conductor-server.
#
# In production, APP_HOST is set explicitly in the environment.

if Rails.env.development?
  port = ENV.fetch("PORT", 3000)
  # Use awbw.local when running in Conductor so browsers treat all
  # workspaces as the same origin — passwords and cookies carry over
  # regardless of port. Requires 127.0.0.1 awbw.local in /etc/hosts.
  hostname = ENV["CONDUCTOR_PORT"] ? "awbw.local" : "localhost"
  default_host = "#{hostname}:#{port}"

  Rails.application.routes.default_url_options[:host] = default_host

  Rails.application.config.action_mailer.default_url_options = {
    host: hostname, port: port, protocol: "http"
  }

  Rails.application.config.after_initialize do
    ActiveStorage::Current.url_options = {
      protocol: "http",
      host: hostname,
      port: port
    }
  end
end
