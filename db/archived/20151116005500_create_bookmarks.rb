class CreateBookmarks < ActiveRecord::Migration
  def change
    create_table :bookmarks do |t|
      t.references :user, index: true
      t.string :bookmarkable_type
      t.integer :bookmarkable_id

      t.timestamps null: false
    end
    add_foreign_key :bookmarks, :users
  end
end
