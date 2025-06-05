class AddProjectIdToWorkshopLogs < ActiveRecord::Migration
  def change
    add_reference :workshop_logs, :project, index: true
    add_foreign_key :workshop_logs, :projects
  end
end
