class RenameAgenciesToProjects < ActiveRecord::Migration[4.2]
  def change
    rename_table :agencies, :projects
  end
end
