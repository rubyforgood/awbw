class ApplicationController < ActionController::Base
  before_action :authenticate_user! # ensures only logged-in users can access pages
  before_action :track_user_with_ahoy, unless: :devise_controller?
  before_action :set_current_user # for AhoyTrackable in models
  before_action :set_honeybadger_context # so faults name the affected user
  before_action :set_paper_trail_whodunnit
  before_action :preload_current_user_associations

  before_action do
    if current_user && allowed_to?(:manage?, with: ApplicationPolicy)
      Rack::MiniProfiler.authorize_request
    end
  end

  verify_authorized unless: :devise_controller?

  after_action :flush_lifecycle_events
  rescue_from ActionPolicy::Unauthorized do |exception|
    flash[:alert] = "You are not authorized to perform this action.<br>#{ exception.message if Rails.env.test? }"
    redirect_to root_path
  end

  # Bots/crawlers requesting non-HTML formats (e.g. text/plain) trigger
  # MissingTemplate errors because we only have .html.erb templates.
  # Return 406 Not Acceptable instead of a 500 error.
  rescue_from ActionView::MissingTemplate do
    head :not_acceptable
  end

  private

  # Dollar cell for a CSV export: the money helper's formatting when there's an
  # amount, blank when there's nothing (so empty cells read cleanly).
  def csv_dollars(cents)
    cents.positive? ? helpers.dollars_from_cents(cents) : ""
  end

  def after_sign_out_path_for(resource_or_scope)
    if params[:reset_password].present? # needed for custom "log out and reset it" flow
      new_user_password_path
    else
      root_path
    end
  end

  around_action :set_time_zone_from_user

  def set_time_zone_from_user
    zone = ActiveSupport::TimeZone[current_user&.time_zone || "Pacific Time (US & Canada)"]
    if zone
      Time.use_zone(zone) { yield }
    else
      yield
    end
  end

  def track_user_with_ahoy
    ahoy.authenticate(current_user) if user_signed_in?
  end

  def flush_lifecycle_events
    Analytics::LifecycleBuffer.flush(self) # needed for Ahoy tracking in models
  end

  def preload_current_user_associations
    return unless current_user

    # Preload bookmarks so bookmark_for uses in-memory lookup instead of N+1 queries
    current_user.bookmarks.load

    return unless current_user.person
    @current_user_active_affiliations = current_user.person
                                                  .affiliations
                                                  .active
                                                  .includes(:organization)
                                                  .load
    @current_user_staffs_events = current_user.person.event_staffs.exists?
  end

  def set_current_user
    Current.user = current_user if user_signed_in? # needed for Ahoy tracking in models
  end

  def set_honeybadger_context
    return unless user_signed_in?

    Honeybadger.context(user_id: current_user.id, user_email: current_user.email)
  end
end
