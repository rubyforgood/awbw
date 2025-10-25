class AddCreatedByToWorkshopVariation < ActiveRecord::Migration[8.1]
  def change
    unless column_exists?(:workshop_variations, :created_by_id)
      add_reference :workshop_variations, :created_by,
                    foreign_key: { to_table: :users },
                    index: true, null: true, type: :integer
    end
  end
end
