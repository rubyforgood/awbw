class AddRegistrantToEventRegistrations < ActiveRecord::Migration[8.1]
  def change
    remove_column :event_registrations, :email, :string
    remove_column :event_registrations, :first_name, :string
    remove_column :event_registrations, :last_name, :string

    add_reference :event_registrations, :registrant, type: :integer, foreign_key: {to_table: :users}, index: true

    add_index :event_registrations, [:registrant_id, :event_id], unique: true
  end
end
