class ChangeBodyNullableOnWorkshopVariations < ActiveRecord::Migration[8.1]
  def up
    change_column_null :workshop_variations, :body, true
  end

  def down
    WorkshopVariation.where(body: nil).update_all(body: "")
    change_column_null :workshop_variations, :body, false
  end
end
