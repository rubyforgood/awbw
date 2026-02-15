class AddIsPrimaryToAddresses < ActiveRecord::Migration[8.1]
  def change
    add_column :addresses, :is_primary, :boolean, default: false, null: false
  end
end
