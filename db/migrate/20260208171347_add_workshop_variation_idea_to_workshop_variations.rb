class AddWorkshopVariationIdeaToWorkshopVariations < ActiveRecord::Migration[8.0]
  def change
    add_reference :workshop_variations, :workshop_variation_idea, foreign_key: true
  end
end
