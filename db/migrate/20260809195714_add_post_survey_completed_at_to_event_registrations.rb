class AddPostSurveyCompletedAtToEventRegistrations < ActiveRecord::Migration[8.1]
  # The query-free completion cache the registrants readiness Status reads, mirroring
  # certificate_sent_at.
  def up
    return if column_exists?(:event_registrations, :post_survey_completed_at)
    add_column :event_registrations, :post_survey_completed_at, :datetime
  end

  def down
    remove_column :event_registrations, :post_survey_completed_at, if_exists: true
  end
end
