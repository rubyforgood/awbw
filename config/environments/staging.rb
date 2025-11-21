require_relative 'production'

# Override production settings here
Rails.application.configure do
  config.active_storage.service = :digitalocean
end
