class AddExtraAddressFieldsToUsers < ActiveRecord::Migration
  def change
    add_column :users, :phone2, :string
    add_column :users, :phone3, :string
    add_column :users, :best_time_to_call, :string
    add_column :users, :address2, :string
    add_column :users, :city2, :string
    add_column :users, :state2, :string
    add_column :users, :zip2, :string
    add_column :users, :primary_address, :integer
  end
end
