class AddPaymentDueDeadlineToEvents < ActiveRecord::Migration[8.1]
  def up
    add_column :events, :payment_due_deadline, :datetime
  end

  def down
    remove_column :events, :payment_due_deadline, if_exists: true
  end
end
