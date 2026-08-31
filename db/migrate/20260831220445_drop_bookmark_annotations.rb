class DropBookmarkAnnotations < ActiveRecord::Migration[8.0]
  def up
    drop_table :bookmark_annotations, if_exists: true
  end

  def down
    create_table :bookmark_annotations, id: :integer do |t|
      t.text :annotation, size: :long
      t.integer :bookmark_id
      t.timestamps
      t.index :bookmark_id, name: "index_bookmark_annotations_on_bookmark_id"
    end

    add_foreign_key :bookmark_annotations, :bookmarks unless foreign_key_exists?(:bookmark_annotations, :bookmarks)
  end
end
