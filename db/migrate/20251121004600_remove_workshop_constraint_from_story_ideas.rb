class RemoveWorkshopConstraintFromStoryIdeas < ActiveRecord::Migration[8.1]
  def change
    change_column_null :story_ideas, :workshop_id, true
  end
end
