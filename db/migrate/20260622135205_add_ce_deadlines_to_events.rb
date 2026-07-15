class AddCeDeadlinesToEvents < ActiveRecord::Migration[8.1]
  def up
    add_column :events, :ce_hours_request_deadline, :date unless column_exists?(:events, :ce_hours_request_deadline)
    add_column :events, :ce_payment_due_deadline, :date unless column_exists?(:events, :ce_payment_due_deadline)
  end

  def down
    remove_column :events, :ce_hours_request_deadline, if_exists: true
    remove_column :events, :ce_payment_due_deadline, if_exists: true
  end
end
