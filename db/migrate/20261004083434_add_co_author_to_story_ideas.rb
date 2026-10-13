class AddCoAuthorToStoryIdeas < ActiveRecord::Migration[8.0]
  def up
    add_column :story_ideas, :co_author_id, :bigint unless column_exists?(:story_ideas, :co_author_id)
    add_column :story_ideas, :co_author_credit_preference, :string unless column_exists?(:story_ideas, :co_author_credit_preference)
    add_index :story_ideas, :co_author_id unless index_exists?(:story_ideas, :co_author_id)
  end

  def down
    remove_index :story_ideas, :co_author_id, if_exists: true
    remove_column :story_ideas, :co_author_credit_preference, if_exists: true
    remove_column :story_ideas, :co_author_id, if_exists: true
  end
end
