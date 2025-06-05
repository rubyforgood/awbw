require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Awbw
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.0

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # This was enabled prior to Rails 5.0 upgrade. However, this seems overly 
    # permissive. We should verify if this is necessary, and if not, remove it.
    # # CORS Middleware
    # config.middleware.insert_before Rack::Runtime, Rack::Cors, logger: Rails.logger do
    #   allow do
    #     origins '*'

    #     resource '*',
    #     :headers => :any,
    #     :methods => [:get, :post, :options, :delete, :put, :options, :head],
    #     max_age: 1728000
    #   end
    # end
  end
end
