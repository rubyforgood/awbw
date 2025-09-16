class AuthenticationToken
  EXPIRY_TIME = -> { 2.weeks.from_now }

  def initialize(token)
    @token = token
  end

  def self.generate_token(user_id, expiry=EXPIRY_TIME.call)
    payload = {user_id: user_id, exp: expiry.to_i }
    new(JWT.encode(payload, Rails.application.credentials.secret_key_base))
  end

  def to_s
    @token
  end

  def user_id
    decode['user_id']
  end

  private

  def decode
    begin
      JWT.decode(@token, Rails.application.credentials.secret_key_base).first
    rescue JWT::ExpiredSignature
      raise AuthenticationFailed.new("Token Expired")
    rescue JWT::DecodeError
      raise AuthenticationFailed.new("Token Invalid")
    end
  end
end
