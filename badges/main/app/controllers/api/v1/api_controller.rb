class Api::V1::ApiController < ActionController::API
  include ActionController::RequestForgeryProtection
  protect_from_forgery with: :null_session, :if => Proc.new { |c| c.request.format.json? }

  rescue_from AuthenticationFailed, with: :authentication_failed
  before_action :authenticate_api_user!

  def authenticate_api_user!
    raise AuthenticationFailed unless current_api_user.present?
  end

  def current_api_user
    if http_auth_header_content
      @current_user ||= User.find_by(id: AuthenticationToken.new(http_auth_header_content).user_id)
    elsif current_user
      @current_user
    end
  end

  def authentication_failed(exception)
    render json: {error: exception.message}, status: :unauthorized
  end

  private

  def http_auth_header_content
    if request.headers['Authorization'].present?
      @http_auth_header_content ||=
        request.headers['Authorization'].split(' ').last
    else
      @http_auth_header_content ||= params['Authorization']
    end
  end
end
