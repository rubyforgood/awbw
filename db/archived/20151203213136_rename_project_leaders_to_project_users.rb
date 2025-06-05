class RenameProjectLeadersToProjectUsers < ActiveRecord::Migration[4.2]
  def change
    rename_table :project_leaders, :project_users
  end
end
