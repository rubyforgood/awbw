source 'https://rubygems.org'

ruby "3.3.8"

gem "rails", "~> 6.1.7"

# TODO Consider removing these after upgrading Rails. These are a Ruby 3.3 => 3.4 warning.
# add required gems leaving standard library to avoid log noise
gem "bigdecimal"
gem "drb"
gem "mutex_m"
gem "observer"


gem 'sprockets-rails', '~> 3.2.2'
gem "activerecord-trilogy-adapter" # for mysql installation
gem 'bootstrap-sass'
gem "sassc-rails", ">= 2.1.2"
gem 'uglifier'
gem 'coffee-rails'
gem "feature_flipper"

gem 'jquery-rails'
gem 'jbuilder', '~> 2.0'

gem 'devise', '~> 4.7.3'
gem 'neat', '1.7.1'
gem 'bourbon', '~> 4.2.2'
gem 'draper'
gem "kt-paperclip", "~> 6.4", ">= 6.4.1"
gem 'aws-sdk-s3'
gem 'rails_admin','~> 2.2.1'
# gem 'rails_admin', git: 'https://github.com/enmand/rails_admin.git'
# rails_admin 1.1.1 has a transitive dependency on haml (~> 4.0). haml 4.0.7 in
# turn has a transitive dependency on tile and does not specify a version range.
# This causes it to pull in tilt 2.6.0 which is incompatible with haml 4.0.7. So
# specifying tilt as a direct dependency with a version range that is compatible
# with haml 4.0.7. We can remove this as soon we get upgrade to a newer version
# of rails_admin that should pull in a newer version of haml, breaking this
# dependency chain.
gem 'tilt', '~> 2.4.0'


gem 'puma', '~> 5.6' # Add Puma as the web server

gem 'cocoon', '~> 1.2.6'

gem 'font-awesome-rails'
gem 'wicked'
gem 'search_cop', '~> 1.0.6'
gem 'jwt', '~> 1.2.1'
gem 'httparty'
gem 'will_paginate', '~> 3.1.7'
gem 'bootstrap-will_paginate'
gem 'apipie-rails', '~> 0.5.0'
gem 'rack-cors', :require => 'rack/cors'
gem 'ckeditor', '~> 4.3.0'
gem "binding_of_caller"
gem 'image_processing'
gem 'foundation_emails'
gem 'inky-rb', require: 'inky'
# Stylesheet inlining for email
gem 'premailer-rails'
gem "bcrypt", '3.1.16'
gem "json", ">= 2.6", "< 3" # or simply: gem "json", "~> 2.7"

group :development, :test do
  gem 'better_errors'
  gem "brakeman", require: false
  gem "bundler-audit", require: false
  gem 'capybara', '~> 3.36'
  gem 'dotenv-rails'
  gem 'faker'
  gem 'factory_bot_rails'
  gem 'listen'
  gem 'pry-rails'
  gem 'rspec-rails'
  gem "simplecov", require: false
  gem "simplecov_json_formatter", require: false
  gem 'selenium-webdriver'
  gem 'shoulda-matchers', require: false
  gem "debug", "~> 1.11"
end

