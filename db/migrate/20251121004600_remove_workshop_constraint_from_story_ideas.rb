class RemoveWorkshopConstraintFromStoryIdeas < ActiveRecord::Migration[8.1]
  def up
    change_column_null :story_ideas, :workshop_id, true
  end

  def down
    # clean invalid data before restoring NOT NULL
    StoryIdea.where(workshop_id: nil).update_all(workshop_id: StoryIdea.first&.workshop_id)

    change_column_null :story_ideas, :workshop_id, false
  end
end
