class AddProjectIdToReports < ActiveRecord::Migration
  def change
    add_reference :reports, :project, index: true
    add_foreign_key :reports, :projects
  end
end
