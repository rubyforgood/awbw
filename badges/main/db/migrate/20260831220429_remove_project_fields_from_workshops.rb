class RemoveProjectFieldsFromWorkshops < ActiveRecord::Migration[8.0]
  def up
    remove_column :workshops, :project, if_exists: true
    remove_column :workshops, :project_spanish, if_exists: true
  end

  def down
    add_column :workshops, :project, :text, size: :long unless column_exists?(:workshops, :project)
    add_column :workshops, :project_spanish, :text, size: :long unless column_exists?(:workshops, :project_spanish)
  end
end
