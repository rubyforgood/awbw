class DropOrganization < ActiveRecord::Migration[8.1]
  def up
    # remove_foreign_key :addresses, :organizations
    remove_column :addresses, :organization_id, :integer
    add_reference :addresses, :addressable, polymorphic: true

    rename_column :facilitators, :profile_show_organizations, :profile_show_affiliations

    drop_table :organization_workshops
    drop_table :facilitator_organizations
    drop_table :organizations
  end

  def down
    create_table :organizations do |t|
      t.string :name, null: false
      t.boolean :is_active, default: true
      t.date :start_date
      t.date :close_date
      t.string :website_url
      t.string :agency_type, null: false
      t.string :agency_type_other
      t.string :phone, null: false
      t.text :mission
      t.string :project_id

      t.timestamps
    end

    create_table :facilitator_organizations do |t|
      t.references :facilitator, null: false
      t.references :organization, null: false
      t.timestamps
    end
    add_index :facilitator_organizations, [:facilitator_id, :organization_id],
              unique: true, name: 'index_facilitator_organizations_on_ids'

    create_table :organization_workshops do |t|
      t.references :organization, null: false
      t.references :workshop, null: false
      t.timestamps
    end
    add_index :organization_workshops, [:organization_id, :workshop_id], unique: true, name: 'index_organization_workshops_on_ids'


    rename_column :facilitators, :profile_show_affiliations, :profile_show_organizations

    remove_reference :addresses, :addressable, polymorphic: true
    add_column :addresses, :organization_id, :integer
    # add_foreign_key :addresses, :organizations
  end
end
