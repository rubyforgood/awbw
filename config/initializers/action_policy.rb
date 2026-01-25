# frozen_string_literal: true

ActionPolicy.configure do |config|
  # Require authorization on every controller action
  # Enable after verifying all controllers have proper authorization
  # config.fail_if_not_authorized = true
end
