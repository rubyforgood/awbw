source 'https://rubygems.org'

ruby "2.7.8"

gem 'rails', '~> 5.2.0'

gem 'sprockets-rails', '~> 3.2.2'
gem 'mysql2', '~> 0.5.0'
gem 'bootstrap-sass'
gem 'sass-rails', '~> 5.0.7'
gem 'uglifier'
gem 'coffee-rails'
gem "feature_flipper"

gem 'jquery-rails'
gem 'jbuilder', '~> 2.0'
gem 'sdoc', '~> 0.4.0', group: :doc

gem 'devise', '~> 4.7.3'
gem 'neat', '1.7.1'
gem 'bourbon', '~> 4.2.2'
gem 'draper'
gem 'paperclip', '~> 6.0.0'
gem 'aws-sdk-s3', '~> 1.98.0'
gem 'rails_admin','~> 1.4.0'
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
gem 'mandrill_mailer', '~> 1.0.1'
gem 'jwt', '~> 1.2.1'
gem 'httparty', '~> 0.13.7'
gem 'will_paginate', '~> 3.1.7'
gem 'bootstrap-will_paginate'
gem 'aws-sdk-v1', '~> 1.64.0'
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

group :development, :test do
  gem 'capybara', '~> 3.36'
  gem 'dotenv-rails'
  gem 'rspec-rails'
  gem 'factory_bot_rails', '~> 6.0.0'
  gem 'faker'
  gem 'shoulda-matchers', require: false
  gem "better_errors"
end
