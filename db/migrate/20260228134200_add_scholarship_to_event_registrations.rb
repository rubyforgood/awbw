class AddScholarshipToEventRegistrations < ActiveRecord::Migration[8.1]
  def change
    add_column :event_registrations, :scholarship_recipient, :boolean, default: false, null: false
  end
end
