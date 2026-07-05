class StandardizeAuthorCreditFields < ActiveRecord::Migration[8.1]
  # The community news "display author" is a legacy pick (a User) that predates
  # person authors; name it as legacy so it reads like resources.legacy_author_name.
  # author_credit_preference is defaulted to "full_name" in the UI and in
  # AuthorCreditable (attribute default + author_credit fallback), not by a data
  # backfill, so there's no column change here.
  def up
    if column_exists?(:community_news, :user_author_id) && !column_exists?(:community_news, :legacy_author_user_id)
      rename_column :community_news, :user_author_id, :legacy_author_user_id
    end
    if index_name_exists?(:community_news, "index_community_news_on_user_author_id")
      rename_index :community_news, "index_community_news_on_user_author_id", "index_community_news_on_legacy_author_user_id"
    end
  end

  def down
    if index_name_exists?(:community_news, "index_community_news_on_legacy_author_user_id")
      rename_index :community_news, "index_community_news_on_legacy_author_user_id", "index_community_news_on_user_author_id"
    end
    if column_exists?(:community_news, :legacy_author_user_id) && !column_exists?(:community_news, :user_author_id)
      rename_column :community_news, :legacy_author_user_id, :user_author_id
    end
  end
end
