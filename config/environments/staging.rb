require_relative "production"

# Override production settings here
Rails.application.configure do
  # Attachment handling
  config.active_storage.service = :digitalocean
  app_host = ENV.fetch("APP_HOST", "localhost")
  Rails.application.routes.default_url_options[:host] = app_host
  config.action_mailer.asset_host = app_host
  config.after_initialize do
    ActiveStorage::Current.url_options = {
      protocol: Rails.env.development? ? "http" : "https",
      host: app_host
    }
  end
end
