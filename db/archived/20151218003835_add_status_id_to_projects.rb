class AddStatusIdToProjects < ActiveRecord::Migration[4.2]
  def change
    add_reference :projects, :project_status, index: true
    add_foreign_key :projects, :project_statuses
  end
end
