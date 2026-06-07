class AddMemoToPayments < ActiveRecord::Migration[8.1]
  def up
    add_column :payments, :memo, :string
  end

  def down
    remove_column :payments, :memo, if_exists: true
  end
end
