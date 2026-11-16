class AddFilemakerCodeToEventRegistrations < ActiveRecord::Migration[8.1]
  def change
    add_column :event_registrations, :filemaker_code, :string
    add_index :event_registrations, :filemaker_code
  end
end
