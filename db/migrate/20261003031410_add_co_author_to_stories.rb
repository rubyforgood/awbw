class AddCoAuthorToStories < ActiveRecord::Migration[8.1]
  def up
    unless column_exists?(:stories, :co_author_id)
      add_reference :stories, :co_author, foreign_key: { to_table: :people }, index: true, null: true
    end
    add_column :stories, :co_author_credit_preference, :string unless column_exists?(:stories, :co_author_credit_preference)
  end

  def down
    remove_column :stories, :co_author_credit_preference, if_exists: true
    remove_reference :stories, :co_author, foreign_key: { to_table: :people }, if_exists: true
  end
end
