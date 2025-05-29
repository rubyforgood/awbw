class AddProjectIdToReports < ActiveRecord::Migration[4.2]
  def change
    add_reference :reports, :project, index: true
    add_foreign_key :reports, :projects
  end
end
