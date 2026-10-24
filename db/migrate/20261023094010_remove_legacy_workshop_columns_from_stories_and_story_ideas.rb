class RemoveLegacyWorkshopColumnsFromStoriesAndStoryIdeas < ActiveRecord::Migration[8.1]
  TABLES = %i[stories story_ideas].freeze

  def up
    TABLES.each do |table|
      remove_foreign_key table, :workshops if foreign_key_exists?(table, :workshops)
      remove_index table, :workshop_id, if_exists: true
      remove_column table, :workshop_id if column_exists?(table, :workshop_id)
      remove_column table, :external_workshop_title if column_exists?(table, :external_workshop_title)
    end
  end

  def down
    TABLES.each do |table|
      add_column table, :workshop_id, :integer unless column_exists?(table, :workshop_id)
      add_column table, :external_workshop_title, :string unless column_exists?(table, :external_workshop_title)
      add_index table, :workshop_id unless index_exists?(table, :workshop_id)
      add_foreign_key table, :workshops unless foreign_key_exists?(table, :workshops)
    end
  end
end
