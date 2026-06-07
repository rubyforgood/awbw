class AddCeCreditRequestedToEventRegistrations < ActiveRecord::Migration[8.1]
  def up
    unless column_exists?(:event_registrations, :ce_credit_requested)
      add_column :event_registrations, :ce_credit_requested, :boolean, default: false, null: false
    end
  end

  def down
    remove_column :event_registrations, :ce_credit_requested, if_exists: true
  end
end
