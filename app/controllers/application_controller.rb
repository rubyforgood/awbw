class ApplicationController < ActionController::Base
  include ActionPolicy::Controller
  prepend ActionPolicy::Draper

  before_action :authenticate_user!  # ensures only logged-in users can access pages
  before_action :set_current_user # for AhoyTrackable in models

  after_action :verify_authorized, unless: :skip_authorization?
  # verify_authorized except: :index
  # verify_authorized_scoped only: :index

  after_action :flush_lifecycle_events
  around_action :set_time_zone_from_user, if: :current_user

  helper_method :admin?

  rescue_from ActionPolicy::Unauthorized do |exception|
    flash[:alert] = exception.message.presence || "You are not authorized to perform this action."
    redirect_back_or_to root_path
  end

  def default_authorization_policy_class
    ApplicationPolicy
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

  def set_time_zone_from_user
    zone = ActiveSupport::TimeZone[current_user&.time_zone]
    if zone
      Time.use_zone(zone) { yield }
    else
      yield
    end
  end

  def authenticate_user!
    return super if devise_controller?
    return if user_signed_in?
    ahoy.authenticate(current_user)
    redirect_to root_path
  end

  def flush_lifecycle_events
    Analytics::LifecycleBuffer.flush(self)
  end

  def set_current_user
    Current.user = current_user if user_signed_in?
  end

  def resource_controller?
    controller_name.classify.safe_constantize.present?
  end

  def auto_authorize!
    model = policy_class_for_controller
    return unless model

    resource = params[:id].present? ? model.find(params[:id]) : model

    Rails.logger.debug("AUTO AUTHORIZE: #{resource.inspect}")
    resource = instance_variable_get("@#{controller_name.singularize}") || policy_class_for_controller
    authorize!(resource) if resource
  end

  def policy_class_for_controller
    controller_name.classify.safe_constantize
  end

  def skip_authorization?
    devise_controller? || policy_class_for_controller.nil?
  end
end
