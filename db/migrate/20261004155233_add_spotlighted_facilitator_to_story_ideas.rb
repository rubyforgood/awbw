class AddSpotlightedFacilitatorToStoryIdeas < ActiveRecord::Migration[8.0]
  def up
    add_column :story_ideas, :spotlighted_facilitator_id, :bigint unless column_exists?(:story_ideas, :spotlighted_facilitator_id)
    add_index :story_ideas, :spotlighted_facilitator_id unless index_exists?(:story_ideas, :spotlighted_facilitator_id)
  end

  def down
    remove_index :story_ideas, :spotlighted_facilitator_id, if_exists: true
    remove_column :story_ideas, :spotlighted_facilitator_id, if_exists: true
  end
end
