class AddAuthorToStoriesAndStoryIdeas < ActiveRecord::Migration[7.2]
  def up
    add_reference :stories, :author, type: :bigint, null: true, index: true
    add_reference :story_ideas, :author, type: :bigint, null: true, index: true

    add_foreign_key :stories, :people, column: "author_id"
    add_foreign_key :story_ideas, :people, column: "author_id"

    # Backfill author from the creating user's linked person, preserving existing
    # author credits. Rows whose creator has no linked person stay null (Anonymous).
    execute <<~SQL.squish
      UPDATE stories
      JOIN users ON users.id = stories.created_by_id
      SET stories.author_id = users.person_id
      WHERE users.person_id IS NOT NULL
    SQL

    execute <<~SQL.squish
      UPDATE story_ideas
      JOIN users ON users.id = story_ideas.created_by_id
      SET story_ideas.author_id = users.person_id
      WHERE users.person_id IS NOT NULL
    SQL
  end

  def down
    remove_foreign_key :stories, column: "author_id" if foreign_key_exists?(:stories, column: "author_id")
    remove_foreign_key :story_ideas, column: "author_id" if foreign_key_exists?(:story_ideas, column: "author_id")
    remove_reference :stories, :author, if_exists: true
    remove_reference :story_ideas, :author, if_exists: true
  end
end
