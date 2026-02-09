class AddOrganizationToWorkshopVariation < ActiveRecord::Migration[8.1]
  def up
    change_column :workshop_variations, :organization_id, :integer

    unless foreign_key_exists?(:workshop_variations, :organizations)
      add_foreign_key :workshop_variations, :organizations
    end
  end

  def down
    remove_foreign_key :workshop_variations, :organizations if foreign_key_exists?(:workshop_variations, :organizations)

    change_column :workshop_variations, :organization_id, :bigint
  end
end