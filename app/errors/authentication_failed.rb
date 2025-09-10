# frozen_string_literal: true

class AuthenticationFailed < StandardError
  def initialize(message = "Not Authorized")
    super(message)
  end
end
