class AddParticipantsFieldsToWorkshopLogs < ActiveRecord::Migration[4.2]
  def change
    add_column :workshop_logs, :num_participants_on_going, :integer, default: 0
    add_column :workshop_logs, :num_participants_first_time, :integer, default: 0
  end
end
