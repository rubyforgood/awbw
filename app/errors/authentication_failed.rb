class AuthenticationFailed < StandardError
  def initialize(message = "Not Authorized")
    super(message)
  end
end
