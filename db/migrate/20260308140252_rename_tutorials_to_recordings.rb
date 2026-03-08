class RenameRecordings < ActiveRecord::Migration[8.0]
  def change
    rename_table :tutorials, :recordings

    add_column :recordings, :is_tutorial, :boolean, default: true, null: false
    add_column :recordings, :is_podcast, :boolean, default: false, null: false
    add_index :recordings, :is_tutorial
    add_index :recordings, :is_podcast
  end
end
