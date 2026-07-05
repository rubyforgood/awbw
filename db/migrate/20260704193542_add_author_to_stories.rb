class AddAuthorToStories < ActiveRecord::Migration[8.1]
  def up
    return if column_exists?(:stories, :author_id)
    add_reference :stories, :author, foreign_key: { to_table: :people }, index: true, null: true
  end

  def down
    remove_reference :stories, :author, foreign_key: { to_table: :people }, if_exists: true
  end
end
