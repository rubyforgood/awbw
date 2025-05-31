class AddSuperUserToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :super_user, :boolean, default: false
  end
end
