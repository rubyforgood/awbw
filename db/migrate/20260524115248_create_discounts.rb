class CreateDiscounts < ActiveRecord::Migration[8.1]
  def change
    create_table :discounts do |t|
      t.integer :amount_cents, null: false, default: 0

      t.timestamps
    end
  end
end
