class RemoveDefaultFromAmountCentsRemainingOnPayments < ActiveRecord::Migration[8.1]
  def change
    change_column_default :payments, :amount_cents_remaining, from: 0, to: nil
  end
end
