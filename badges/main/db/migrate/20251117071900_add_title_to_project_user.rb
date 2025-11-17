class AddTitleToProjectUser < ActiveRecord::Migration[8.1]
  def change
    add_column :project_users, :title, :string
  end
end
