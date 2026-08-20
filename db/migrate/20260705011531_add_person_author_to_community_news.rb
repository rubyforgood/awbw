class AddPersonAuthorToCommunityNews < ActiveRecord::Migration[8.1]
  # The community news "author" was a User gated to active logins, so
  # facilitators without a confirmed account could not be credited. Preserve
  # that legacy pick as user_author_id and add a nullable person author_id
  # instead — no backfill: AuthorCreditable#author_person falls back through
  # user_author.person then created_by.person for existing rows.
  def up
    # Drop and recreate the users foreign key around the rename so its
    # auto-generated constraint name follows user_author_id, freeing the old
    # name for the new person author reference.
    remove_foreign_key :community_news, :users, column: :author_id
    rename_column :community_news, :author_id, :user_author_id
    # New rows credit a person and leave no legacy user author, so it's nullable.
    change_column_null :community_news, :user_author_id, true
    rename_index :community_news, "index_community_news_on_author_id", "index_community_news_on_user_author_id" if index_name_exists?(:community_news, "index_community_news_on_author_id")
    add_foreign_key :community_news, :users, column: :user_author_id
    add_reference :community_news, :author, foreign_key: { to_table: :people }, index: true, null: true
    add_column :community_news, :author_credit_preference, :string, default: "full_name"
  end

  def down
    remove_column :community_news, :author_credit_preference, if_exists: true
    remove_reference :community_news, :author, foreign_key: { to_table: :people }, if_exists: true
    remove_foreign_key :community_news, :users, column: :user_author_id if foreign_key_exists?(:community_news, :users, column: :user_author_id)
    rename_index :community_news, "index_community_news_on_user_author_id", "index_community_news_on_author_id" if index_name_exists?(:community_news, "index_community_news_on_user_author_id")
    # Restore the NOT NULL author_id: fall back to the creator for rows that had
    # no legacy user author.
    execute "UPDATE community_news SET user_author_id = created_by_id WHERE user_author_id IS NULL"
    change_column_null :community_news, :user_author_id, false
    rename_column :community_news, :user_author_id, :author_id
    add_foreign_key :community_news, :users, column: :author_id unless foreign_key_exists?(:community_news, :users, column: :author_id)
  end
end
