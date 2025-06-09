class CreateBookmarkAnnotations < ActiveRecord::Migration
  def change
    create_table :bookmark_annotations do |t|
      t.references :bookmark, index: true
      t.text :annotation

      t.timestamps null: false
    end
    add_foreign_key :bookmark_annotations, :bookmarks
  end
end
