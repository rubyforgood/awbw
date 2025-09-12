class AddWorkshopIdToWorkshopQuotes < ActiveRecord::Migration
  def change
    add_reference :workshop_quotes, :workshop, index: true
    add_foreign_key :workshop_quotes, :workshops
  end
end
