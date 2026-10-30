class AddReconciliationAcknowledgedAtToPayments < ActiveRecord::Migration[8.1]
  def up
    add_column :payments, :reconciliation_acknowledged_at, :datetime
  end

  def down
    remove_column :payments, :reconciliation_acknowledged_at, if_exists: true
  end
end
