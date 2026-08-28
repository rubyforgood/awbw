class AddAuthorToIdeaModels < ActiveRecord::Migration[8.1]
  TABLES = %i[story_ideas workshop_ideas workshop_variation_ideas].freeze

  def up
    TABLES.each do |table|
      add_reference table, :author, foreign_key: { to_table: :people }, index: true, null: true unless column_exists?(table, :author_id)
      # Backfill authorship from the submitting account's person so the profile can
      # credit ideas by author (matching every other content type) without dropping
      # anything already shown. An admin can reassign the author afterward.
      execute <<~SQL.squish
        UPDATE #{table}
        JOIN users ON users.id = #{table}.created_by_id
        SET #{table}.author_id = users.person_id
        WHERE #{table}.author_id IS NULL
          AND users.person_id IS NOT NULL
      SQL
    end
  end

  def down
    TABLES.each do |table|
      remove_reference table, :author, foreign_key: { to_table: :people }, if_exists: true
    end
  end
end
