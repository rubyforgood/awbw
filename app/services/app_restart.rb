# Restarts the app from the admin UI: puma shuts down gracefully and the host
# (DigitalOcean) starts a fresh container, the same as a restart from its dashboard.
class AppRestart
  DELAY = 1.second

  def self.available?
    !Rails.env.local?
  end

  def self.call
    return unless available?

    Thread.new do
      sleep DELAY
      Process.kill("TERM", Process.pid)
    end
  end
end
