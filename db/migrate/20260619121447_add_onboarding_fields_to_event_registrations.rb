class AddOnboardingFieldsToEventRegistrations < ActiveRecord::Migration[7.2]
  def up
    add_column :event_registrations, :fee_note, :text unless column_exists?(:event_registrations, :fee_note)

    (1..5).each do |day|
      column = "completed_day_#{day}"
      add_column :event_registrations, column, :boolean, default: false, null: false unless column_exists?(:event_registrations, column)
    end
  end

  def down
    remove_column :event_registrations, :fee_note, if_exists: true

    (1..5).each do |day|
      column = "completed_day_#{day}"
      remove_column :event_registrations, column, if_exists: true
    end
  end
end
