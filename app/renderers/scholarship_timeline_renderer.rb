class ScholarshipTimelineRenderer < ApplicationTimelineRenderer
  private

  def subject_path(scholarship)
    Rails.application.routes.url_helpers.edit_scholarship_path(scholarship)
  end
end
