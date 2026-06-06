# Derive the default host from PORT so parallel workspaces each get
# their own URL automatically. WORKSPACE_PORT identifies a workspace and
# flows into PORT via bin/conductor-server. Under Conductor, WORKSPACE_PORT
# is derived from CONDUCTOR_PORT by the bin/conductor-* scripts.
#
# In production, APP_HOST is set explicitly in the environment.

if Rails.env.development?
  port = ENV.fetch("PORT", 3000)
  workspace_port = ENV["WORKSPACE_PORT"]
  # Use awbw.local in a workspace so browsers treat all workspaces as the
  # same origin — passwords and cookies carry over regardless of port.
  # Requires 127.0.0.1 awbw.local in /etc/hosts.
  hostname = workspace_port ? "awbw.local" : "localhost"
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
