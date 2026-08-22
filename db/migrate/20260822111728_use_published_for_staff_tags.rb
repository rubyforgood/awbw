class UsePublishedForStaffTags < ActiveRecord::Migration[7.2]
  def up
    add_column :staff_tags, :published, :boolean, default: true, null: false unless column_exists?(:staff_tags, :published)
    execute "UPDATE staff_tags SET published = FALSE WHERE archived_at IS NOT NULL"
    remove_index :staff_tags, :archived_at, if_exists: true
    remove_column :staff_tags, :archived_at, if_exists: true
    add_index :staff_tags, :published unless index_exists?(:staff_tags, :published)
  end

  def down
    add_column :staff_tags, :archived_at, :datetime unless column_exists?(:staff_tags, :archived_at)
    execute "UPDATE staff_tags SET archived_at = NOW() WHERE published = FALSE"
    remove_index :staff_tags, :published, if_exists: true
    remove_column :staff_tags, :published, if_exists: true
    add_index :staff_tags, :archived_at unless index_exists?(:staff_tags, :archived_at)
  end
end
