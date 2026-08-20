class AddIntendsToPayToEventRegistrations < ActiveRecord::Migration[8.1]
  def up
    unless column_exists?(:event_registrations, :intends_to_pay)
      add_column :event_registrations, :intends_to_pay, :boolean, default: false, null: false
    end
  end

  def down
    remove_column :event_registrations, :intends_to_pay, if_exists: true
  end
end
