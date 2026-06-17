class AddW9AndInvoiceRequestedToEventRegistrations < ActiveRecord::Migration[8.1]
  def up
    unless column_exists?(:event_registrations, :w9_requested)
      add_column :event_registrations, :w9_requested, :boolean, default: false, null: false
    end

    unless column_exists?(:event_registrations, :invoice_requested)
      add_column :event_registrations, :invoice_requested, :boolean, default: false, null: false
    end
  end

  def down
    remove_column :event_registrations, :w9_requested, if_exists: true
    remove_column :event_registrations, :invoice_requested, if_exists: true
  end
end
