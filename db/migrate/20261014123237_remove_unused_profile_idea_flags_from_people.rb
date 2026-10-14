class RemoveUnusedProfileIdeaFlagsFromPeople < ActiveRecord::Migration[8.1]
  COLUMNS = %i[profile_show_story_ideas profile_show_workshop_ideas profile_show_workshop_variation_ideas].freeze

  def up
    COLUMNS.each do |column|
      remove_column :people, column if column_exists?(:people, column)
    end
  end

  def down
    COLUMNS.each do |column|
      add_column :people, column, :boolean, default: true, null: false unless column_exists?(:people, column)
    end
  end
end
