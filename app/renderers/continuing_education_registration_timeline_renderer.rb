class ContinuingEducationRegistrationTimelineRenderer < ApplicationTimelineRenderer
  private

  def path_for(ce_registration)
    routes.edit_continuing_education_registration_path(ce_registration)
  end
end
