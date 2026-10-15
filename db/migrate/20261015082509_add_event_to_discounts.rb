class AddEventToDiscounts < ActiveRecord::Migration[8.1]
  def change
    add_reference :discounts, :event, foreign_key: true
  end
end
