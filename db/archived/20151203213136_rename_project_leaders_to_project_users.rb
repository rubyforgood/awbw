class RenameProjectLeadersToProjectUsers < ActiveRecord::Migration
  def change
    rename_table :project_leaders, :project_users
  end
end
