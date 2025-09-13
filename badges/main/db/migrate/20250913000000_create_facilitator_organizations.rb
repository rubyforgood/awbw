class CreateFacilitatorOrganizations < ActiveRecord::Migration[6.1]
  def change
    create_table :facilitator_organizations do |t|
      t.references :facilitator, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true

      t.timestamps
    end

    add_index :facilitator_organizations, [:facilitator_id, :organization_id],
              unique: true, name: 'index_facilitator_organizations_on_ids'
  end
end