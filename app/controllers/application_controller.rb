class ApplicationController < ActionController::Base
  before_action :authenticate_user!  # ensures only logged-in users can access pages
  before_action :set_current_user # for AhoyTrackable in models
  before_action :preload_current_user_associations

  before_action do
    if current_user && current_user.super_user
      Rack::MiniProfiler.authorize_request
    end
  end

  verify_authorized unless: :devise_controller?

  after_action :flush_lifecycle_events
  around_action :set_time_zone_from_user, if: :current_user

  rescue_from ActionPolicy::Unauthorized do |exception|
    flash[:alert] = "You are not authorized to perform this action.<br>#{ exception.message if Rails.env.test? }"
    redirect_to root_path
  end

  private

  def after_sign_out_path_for(resource_or_scope)
    if request.referrer&.include?("/users/change_password") # needed for custom "log out and reset it" flow
      new_user_password_path
    else
      root_path
    end
  end

  around_action :set_time_zone_from_user

  def set_time_zone_from_user
    zone = ActiveSupport::TimeZone[current_user&.time_zone || "UTC"]
    if zone
      Time.use_zone(zone) { yield }
    else
      yield
    end
  end

  def authenticate_user!
    # Rails.logger.warn "AUTH CHECK → #{request.fullpath}"
    # Rails.logger.warn "  user_signed_in?: #{user_signed_in?}"
    # Rails.logger.warn "  current_user: #{current_user&.id}"
    # Rails.logger.warn "  devise_controller?: #{devise_controller?}"
    # Rails.logger.warn "  referrer: #{request.referrer}"
    return super if devise_controller?
    return if user_signed_in?
    ahoy.authenticate(current_user)
  end

  # def authenticate_user!
  #   return super if devise_controller?
  #   return if user_signed_in?
  #   ahoy.authenticate(current_user)
  #   redirect_to root_path # this part is questionable
  # end

  # def authenticate_user!
  #   ahoy.authenticate(current_user) if user_signed_in?
  #   super
  # end

  def flush_lifecycle_events
    Analytics::LifecycleBuffer.flush(self) # needed for Ahoy tracking in models
  end

  def preload_current_user_associations
    return unless current_user
    current_user.person.organization_people.includes(:organization).load if current_user.person
  end

  def set_current_user
    Current.user = current_user if user_signed_in? # needed for Ahoy tracking in models
  end
end
