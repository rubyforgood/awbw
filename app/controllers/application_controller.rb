class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  before_action :authenticate_user!, unless: :public_page?

  private

  def public_page?
    # Allow unauthenticated access to the dashboard index
    controller_name == "dashboard" && action_name == "index"
  end

  def after_sign_in_path_for(resource)
    user_signed_in? ? authenticated_root_path : unauthenticated_root_path
  end

  def after_sign_out_path_for(resource_or_scope)
    if request.referrer&.include?("/users/change_password")
      new_user_password_path
    else
      unauthenticated_root_path
    end
  end
end
