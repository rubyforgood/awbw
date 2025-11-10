class AddUserReferenceToEventRegistration < ActiveRecord::Migration[8.1]
  def change
    # Remove old columns
    remove_column :event_registrations, :email, :string
    remove_column :event_registrations, :first_name, :string
    remove_column :event_registrations, :last_name, :string

    # Add user reference as integer with foreign key
    add_reference :event_registrations, :user, type: :integer, foreign_key: true, index: true

    # Add unique index for through-table behavior
    add_index :event_registrations, [:user_id, :event_id], unique: true, name: "index_event_registrations_on_user_and_event"
  end
end
