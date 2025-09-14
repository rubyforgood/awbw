class CreateOrganizationWorkshops < ActiveRecord::Migration[8.1]
  def change
    create_table :organization_workshops do |t|
      t.references :organization, null: false, foreign_key: true, type: :integer
      t.references :workshop, null: false, foreign_key: true, type: :integer

      t.timestamps
    end

    add_index :organization_workshops, [:organization_id, :workshop_id], unique: true, name: 'index_organization_workshops_on_ids'
  end
end
