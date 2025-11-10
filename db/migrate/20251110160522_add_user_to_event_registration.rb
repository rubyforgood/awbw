class AddUserToEventRegistration < ActiveRecord::Migration[8.1]
  def change
    remove_column :event_registrations, :email, :string
    remove_column :event_registrations, :first_name, :string
    remove_column :event_registrations, :last_name, :string

    add_reference :event_registrations, :user, type: :integer, foreign_key: true, index: true
  end
end
