class RenameAllocatedAmountCentsToAmountCentsRemainingOnPayments < ActiveRecord::Migration[8.1]
  def change
    rename_column :payments, :allocated_amount_cents, :amount_cents_remaining
  end
end
