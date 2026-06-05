class AddAuthorNameToStories < ActiveRecord::Migration[8.1]
  def up
    add_column :stories, :author_name, :string
  end

  def down
    remove_column :stories, :author_name, if_exists: true
  end
end
