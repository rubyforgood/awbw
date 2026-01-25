class ApplicationController < ActionController::Base
  include ActionPolicy::Controller

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  before_action :authenticate_user!  # ensures only logged-in users can access pages

  rescue_from ActionPolicy::Unauthorized do |exception|
    flash[:alert] = exception.message.presence || "You are not authorized to perform this action."
    redirect_back_or_to authenticated_root_path
  end

  private

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
