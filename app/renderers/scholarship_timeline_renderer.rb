class ScholarshipTimelineRenderer < ApplicationTimelineRenderer
  private

  def path_for(scholarship)
    Rails.application.routes.url_helpers.edit_scholarship_path(scholarship)
  end
end
