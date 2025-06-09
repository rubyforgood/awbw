class AddActivationStatusToUsers < ActiveRecord::Migration
  def change
    add_column :users, :activation_status, :integer, default: 0
  end
end
