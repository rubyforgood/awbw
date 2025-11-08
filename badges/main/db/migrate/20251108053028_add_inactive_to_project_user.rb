class AddInactiveToProjectUser < ActiveRecord::Migration[8.1]
  def change
    add_column :project_users, :inactive, :boolean, default: false, null: false
  end
end
