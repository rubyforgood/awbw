class AddAllocatedAmountToPayments < ActiveRecord::Migration[8.1]
  def change
    add_column :payments, :allocated_amount_cents, :integer, null: false, default: 0
  end
end
