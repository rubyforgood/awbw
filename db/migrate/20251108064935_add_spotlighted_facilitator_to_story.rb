class AddSpotlightedFacilitatorToStory < ActiveRecord::Migration[8.1]
  def change
    add_reference :stories, :spotlighted_facilitator,
                  foreign_key: { to_table: :facilitators }, index: true
  end
end
