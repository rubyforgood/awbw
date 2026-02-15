class AddPolymorphicIndexToBookmarks < ActiveRecord::Migration[7.2]
  def change
    add_index :bookmarks, [ :bookmarkable_type, :bookmarkable_id ],
              name: "index_bookmarks_on_bookmarkable"
  end
end
