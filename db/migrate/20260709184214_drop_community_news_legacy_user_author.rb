class DropCommunityNewsLegacyUserAuthor < ActiveRecord::Migration[8.1]
  # Community news is a handful of rows, so the legacy "display author" User
  # (user_author_id) isn't worth keeping as a separate credit tier. No backfill:
  # existing rows credit their person author, or fall back to created_by.person
  # via AuthorCreditable. Drop the column and its index/foreign key.
  def up
    remove_foreign_key :community_news, :users, column: :user_author_id if foreign_key_exists?(:community_news, :users, column: :user_author_id)
    remove_column :community_news, :user_author_id, if_exists: true
  end

  def down
    unless column_exists?(:community_news, :user_author_id)
      add_column :community_news, :user_author_id, :integer
      add_index :community_news, :user_author_id unless index_exists?(:community_news, :user_author_id)
    end
    add_foreign_key :community_news, :users, column: :user_author_id unless foreign_key_exists?(:community_news, :users, column: :user_author_id)
  end
end
