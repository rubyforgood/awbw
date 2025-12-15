require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Awbw
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks generators])
    config.autoload_paths << Rails.root.join("app/renderers")

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.generators do |g| # scaffold generator settings
      # g.orm :active_record             # Use ActiveRecord (default)
      # g.template_engine :erb           # Use ERB for templates
      g.test_framework :rspec, fixture: false  # Use RSpec, skip fixtures
      g.jbuilder false                 # Skip Jbuilder views
      g.helper false                   # Skip helper files
      g.assets false                   # Skip JS/CSS assets
      g.channel assets: false          # Skip ActionCable JS
    end
  end
end
