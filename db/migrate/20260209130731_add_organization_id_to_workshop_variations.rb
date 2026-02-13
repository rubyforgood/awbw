class AddOrganizationIdToWorkshopVariations < ActiveRecord::Migration[8.1]
  def change
    add_reference :workshop_variations,
                  :organization,
                  foreign_key: true,
                  type: :integer
  end
end
