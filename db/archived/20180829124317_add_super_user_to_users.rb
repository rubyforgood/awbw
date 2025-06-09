class AddSuperUserToUsers < ActiveRecord::Migration
  def change
    add_column :users, :super_user, :boolean, default: false
  end
end
