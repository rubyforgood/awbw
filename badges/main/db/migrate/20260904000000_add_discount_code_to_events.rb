class AddDiscountCodeToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :discount_code, :string
    add_column :events, :discount_amount_cents, :integer
  end
end
