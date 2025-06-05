Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable/disable caching.
  # (By default caching is disabled -- run rails dev:cache to toggle caching.)
  if Rails.root.join('tmp', 'caching-dev.txt').exist?
    config.action_controller.perform_caching = true

    config.cache_store = :memory_store
    config.public_file_server.headers = {
      'Cache-Control' => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  # Store uploaded files on the local file system (see config/storage.yml for options)
  config.active_storage.service = :local

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = true

  config.action_mailer.perform_caching = false

  config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
  # config.action_mailer.perform_deliveries = false

  # Existing code base uses config/intializers/mail.rb to configure ActionMailer
  # config.action_mailer.delivery_method = :smtp
  # config.action_mailer.smtp_settings = {
  #   :user_name => ENV.fetch('SMTP_USERNAME'),
  #   :password => ENV.fetch('SMTP_PASSWORD'),
  #   :address => ENV.fetch('SMTP_SERVER'),
  #   :domain => ENV.fetch('SMTP_SERVER'),
  #   :port => ENV.fetch('SMTP_PORT'),
  #   :authentication => :cram_md5
  # }

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # Asset digests allow you to set far-future HTTP expiration dates on all assets,
  # yet still be able to expire them through the digest params.
  config.assets.digest = true

  # Suppress logger output for asset requests.
  config.assets.quiet = true

  # Adds additional error checking when serving assets at runtime.
  # Checks for improperly declared sprockets dependencies.
  # Raises helpful error messages.
  config.assets.raise_runtime_errors = true

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true

  # Amazon S3 Config
  config.paperclip_defaults = {
    storage: :s3,
    s3_region: ENV.fetch('AWS_REGION'),
    bucket: ENV.fetch('AWS_S3_BUCKET'),
    s3_credentials: {
        access_key_id: ENV.fetch('AWS_ACCESS_KEY_ID'),
        secret_access_key: ENV.fetch('AWS_SECRET_ACCESS_KEY'),
    }
  }

  # Use an evented file watcher to asynchronously detect changes in source code,
  # routes, locales, etc. This feature depends on the listen gem.
  # config.file_watcher = ActiveSupport::EventedFileUpdateChecker
  config.file_watcher = ActiveSupport::FileUpdateChecker
end
