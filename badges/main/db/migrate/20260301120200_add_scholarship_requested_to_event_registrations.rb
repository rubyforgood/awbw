class AddScholarshipRequestedToEventRegistrations < ActiveRecord::Migration[8.1]
  def change
    add_column :event_registrations, :scholarship_requested, :boolean, default: false, null: false
  end
end
