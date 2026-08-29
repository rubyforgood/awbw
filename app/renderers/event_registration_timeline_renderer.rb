class EventRegistrationTimelineRenderer < ApplicationTimelineRenderer
  private

  def path_for(registration)
    routes.edit_event_registration_path(registration)
  end
end
