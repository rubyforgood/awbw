class ApplicationController < ActionController::Base
  include ApplicationHelper
  prepend ActionPolicy::Draper
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  before_action :authenticate_user!  # ensures only logged-in users can access pages

  # TODO add this after_action callback to verify
  # that `authorize!` has been called in all controllers
  # once all policies are added
  #
  # verify_authorized
  #

  rescue_from ActionPolicy::Unauthorized do |exception|
    flash[:alert] = exception.message.presence || "You are not authorized to perform this action."
    redirect_back_or_to root_link_path # TODO handle unauthenticated
  end

  private

  def after_sign_in_path_for(resource)
    # user_signed_in? ? root_path : root_path
    root_path
  end

  def after_sign_out_path_for(resource_or_scope)
    if request.referrer&.include?("/users/change_password")
      new_user_password_path
    else
      # root_path
      root_path
    end
  end
end
