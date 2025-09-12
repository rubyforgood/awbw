class AddWorkshopIdToResources < ActiveRecord::Migration
  def change
    add_reference :resources, :workshop, index: true
    add_foreign_key :resources, :workshops
  end
end
