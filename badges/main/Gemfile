source "https://rubygems.org"

ruby "4.0.1"

gem "rails", "~> 8.1.0"
gem "bootsnap", require: false

gem "sprockets-rails", "~> 3.2.2"
gem "trilogy", "2.9.0"
gem "uglifier"
gem "feature_flipper"

gem "vite_rails"

gem "jquery-rails"
gem "jbuilder", "~> 2.0"

gem "devise", "~> 4.9.4"
gem "draper"
gem "kt-paperclip", "~> 7.1.1"
gem "aws-sdk-s3"

gem "puma", "~> 6.0" # Add Puma as the web server

gem "cocoon", "~> 1.2.6"

gem "wicked"
gem "search_cop"
gem "jwt", "~> 1.2.1"
gem "httparty"
gem "will_paginate", "~> 3.1.7"
gem "apipie-rails", "~> 1.5.0"
gem "rack-cors", require: "rack/cors"
# gem "ckeditor", "~> 4.3.0" # removed given gh security scan results. still need a replacement.
gem "image_processing"

# Visit and event tracking
gem "ahoy_matey"

# Stylesheet inlining for email
gem "premailer-rails" # applies any style tag classes to html elements for better email client compatibility

gem "bcrypt", "3.1.16"
gem "json", ">= 2.6", "< 3" # or simply: gem "json", "~> 2.7"
gem "ostruct"
gem "simple_form"
gem "country_select"

gem "turbo-rails", "~> 2.0"
gem "stimulus-rails", "~> 1.3"

gem "active_storage_validations", "~> 3.0"

gem "positioning", "~> 0.4.7"

gem "action_policy", "~> 0.7.6"

group :development do
  gem "rubocop-rails-omakase", require: false
end

group :development, :test do
  gem "better_errors"
  # gem "binding_of_caller"  # Temporarily commented - doesn't support Ruby 4.0.1
  #
  # FIXME: Workaround for Ruby 4.0+
  # https://github.com/banister/binding_of_caller/pull/90
  gem "binding_of_caller", github: "kivikakk/binding_of_caller", branch: "push-yrnnzolypxun"

  gem "brakeman", "~> 8.0.0", require: false
  gem "bundler-audit", require: false
  gem "capybara", "~> 3.36"
  gem "dotenv-rails"
  gem "faker"
  gem "factory_bot_rails"
  gem "listen"
  gem "pry-coolline"
  gem "pry-rails"
  gem "rspec-rails"
  gem "simplecov", require: false
  gem "simplecov_json_formatter", require: false
  gem "selenium-webdriver"
  gem "shoulda-matchers", require: false
  gem "debug", "~> 1.11"
  gem "bullet"
end
