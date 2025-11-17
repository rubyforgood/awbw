class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  before_action :authenticate_user!  # ensures only logged-in users can access pages

  private

  def after_sign_in_path_for(resource)
    user_signed_in? ? authenticated_root_path : unauthenticated_root_path
  end

  def after_sign_out_path_for(resource)
    unauthenticated_root_path
  end
end
