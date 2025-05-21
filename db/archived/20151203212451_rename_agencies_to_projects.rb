class RenameAgenciesToProjects < ActiveRecord::Migration
  def change
    rename_table :agencies, :projects
  end
end
