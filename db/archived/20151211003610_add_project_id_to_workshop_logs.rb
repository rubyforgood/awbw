class AddProjectIdToWorkshopLogs < ActiveRecord::Migration[4.2]
  def change
    add_reference :workshop_logs, :project, index: true
    add_foreign_key :workshop_logs, :projects
  end
end
