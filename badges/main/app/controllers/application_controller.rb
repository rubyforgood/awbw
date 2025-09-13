class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :null_session
  before_action :authenticate_api_user!
  before_action :authenticate_user!
  before_action :clear_sign_in_flash

  private

  def clear_sign_in_flash
    flash.delete(:notice) if flash.notice == "You have successfully logged in."
  end

  def authenticate_api_user!
    return unless current_api_user.present?
    sign_in current_api_user
    flash[:notice] = 'You have successfully logged in.'
  end

  def authenticate_user!
    user = User.find_by(email: params[:user][:email]) if params[:user]
    if user && user.legacy
      flash[:notice] = 'We have migrated our data to a new system.  '\
                       'Please click the link below to reset your password.'
    end

    super
  end

  # IMPERSONATE USER
  alias_method :devise_current_user, :current_user
  def current_user
    if session[:i_user] && devise_current_user && devise_current_user.super_user?
      user = User.find_by(email: session[:i_user]) if session[:i_user]
    else
      devise_current_user
    end
  end

  def after_sign_in_path_for(resource)
    root_path
  end

  def after_sign_out_path_for(resource)
    new_user_session_path
  end

  def current_api_user
    if http_auth_header_content
      @current_user ||= User.find_by(id: AuthenticationToken.new(http_auth_header_content).user_id)
    elsif current_user
      @current_user
    end
  end

  def http_auth_header_content
    if request.headers['Authorization'].present?
      @http_auth_header_content ||=
        request.headers['Authorization'].split(' ').last
    else
      @http_auth_header_content ||= params['Authorization']
    end
  end
end
