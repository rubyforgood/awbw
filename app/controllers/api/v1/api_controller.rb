# frozen_string_literal: true

class Api::V1::ApiController < ApplicationController
  protect_from_forgery with: :null_session, if: proc { |c| c.request.format.json? }

  rescue_from AuthenticationFailed, with: :authentication_failed
  before_action :authenticate_api_user!

  def authenticate_api_user!
    raise AuthenticationFailed if current_api_user.blank?
  end

  def current_api_user
    if http_auth_header_content
      @current_user ||= User.find_by(id: AuthenticationToken.new(http_auth_header_content).user_id)
    elsif current_user
      @current_user
    end
  end

  def authentication_failed(exception)
    render(json: { error: exception.message }, status: :unauthorized)
  end

  private

  def http_auth_header_content
    @http_auth_header_content ||= if request.headers["Authorization"].present?
      request.headers["Authorization"].split(" ").last
    else
      params["Authorization"]
    end
  end
end
