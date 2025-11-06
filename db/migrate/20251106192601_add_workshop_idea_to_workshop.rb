class AddWorkshopIdeaToWorkshop < ActiveRecord::Migration[8.1]
  def change
    add_reference :workshops, :workshop_idea, null: true, foreign_key: true, index: true
  end
end
