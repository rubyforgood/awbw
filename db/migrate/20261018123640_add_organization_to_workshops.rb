class AddOrganizationToWorkshops < ActiveRecord::Migration[8.1]
  def change
    add_reference :workshops, :organization, type: :integer, null: true, foreign_key: true
  end
end
