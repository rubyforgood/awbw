class ApplicationController < ActionController::Base
  prepend ActionPolicy::Draper

  before_action :authenticate_user!  # ensures only logged-in users can access pages

  # TODO add this callback to verify
  # that `authorize!` has been called in all controllers
  # once all policies are added
  #
  # verify_authorized
  #

  rescue_from ActionPolicy::Unauthorized do |exception|
    flash[:alert] = exception.message.presence || "You are not authorized to perform this action."
    redirect_back_or_to root_path
  end

  private

  def after_sign_in_path_for(resource)
    root_path
  end

  def after_sign_out_path_for(resource_or_scope)
    if request.referrer&.include?("/users/change_password")
      new_user_password_path
    else
      root_path
    end
  end
end
