class AddExternalOriginToPayments < ActiveRecord::Migration[8.1]
  def change
    add_column :payments, :external_origin, :boolean, default: true, null: false
  end
end
