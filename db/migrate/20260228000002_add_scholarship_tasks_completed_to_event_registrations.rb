class AddScholarshipTasksCompletedToEventRegistrations < ActiveRecord::Migration[8.1]
  def change
    unless column_exists?(:event_registrations, :scholarship_tasks_completed)
      add_column :event_registrations, :scholarship_tasks_completed, :boolean, default: false, null: false
    end
  end
end
