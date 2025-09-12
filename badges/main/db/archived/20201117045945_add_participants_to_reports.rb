class AddParticipantsToReports < ActiveRecord::Migration
  def change
    add_column :reports, :children_first_time, :integer, :default => 0
    add_column :reports, :children_ongoing, :integer, :default => 0
    add_column :reports, :teens_first_time, :integer, :default => 0
    add_column :reports, :teens_ongoing, :integer, :default => 0
    add_column :reports, :adults_first_time, :integer, :default => 0
    add_column :reports, :adults_ongoing, :integer, :default => 0
  end
end
