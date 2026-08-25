class EventRegistrationTimelineRenderer < ApplicationTimelineRenderer
  private

  def path_for(registration)
    Rails.application.routes.url_helpers.edit_event_registration_path(registration)
  end
end
