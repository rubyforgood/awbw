class AddScholarshipTasksCompletedToEventRegistrations < ActiveRecord::Migration[8.1]
  def change
    add_column :event_registrations, :scholarship_tasks_completed, :boolean, default: false, null: false
  end
end
