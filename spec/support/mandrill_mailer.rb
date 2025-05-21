# I am fairly certain that we are not actively using MandrillMailer in the 
# codebase. However, it is included in the Gemfile and it is configured in
# config/initializers/mail.rb. Just in case it is being used by some 3rd party
# gem, we will enable offline mode for the test env:
#
#   https://github.com/renz45/mandrill_mailer?tab=readme-ov-file#offline-testing

require 'mandrill_mailer/offline'
