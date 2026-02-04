class RenameSpotlightedFacilitatorToSpotlightedPerson < ActiveRecord::Migration[8.1]
  def change
    rename_column :stories, :spotlighted_facilitator_id, :spotlighted_person_id
  end
end
