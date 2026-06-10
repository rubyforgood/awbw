class RenameFormsSectionsToSubsections < ActiveRecord::Migration[8.1]
  def up
    rename_column :forms, :sections, :subsections if column_exists?(:forms, :sections)
  end

  def down
    rename_column :forms, :subsections, :sections if column_exists?(:forms, :subsections)
  end
end
