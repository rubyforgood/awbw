class AddFlaggedToComments < ActiveRecord::Migration[8.1]
  def up
    return if column_exists?(:comments, :flagged)
    add_column :comments, :flagged, :boolean, null: false, default: false
  end

  def down
    remove_column :comments, :flagged, if_exists: true
  end
end
