class RenameResourceTextToBody < ActiveRecord::Migration[8.1]
  def change
    rename_column :resources, :text, :body
  end
end
