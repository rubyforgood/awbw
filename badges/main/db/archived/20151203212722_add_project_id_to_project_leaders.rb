class AddProjectIdToProjectLeaders < ActiveRecord::Migration
  def change
    add_reference :project_leaders, :project, index: true
    add_foreign_key :project_leaders, :projects
    # remove_column :project_leaders, :agency_id
  end
end
