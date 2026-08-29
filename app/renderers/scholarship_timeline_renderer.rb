class ScholarshipTimelineRenderer < ApplicationTimelineRenderer
  private

  def path_for(scholarship)
    routes.edit_scholarship_path(scholarship)
  end
end
