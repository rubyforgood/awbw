class AddOrganizationToWorkshopIdeas < ActiveRecord::Migration[8.1]
  def change
    add_reference :workshop_ideas, :organization, type: :integer, null: true, foreign_key: true
  end
end
