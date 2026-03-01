class CreateEventRegistrationOrganizations < ActiveRecord::Migration[8.1]
  def change
    create_table :event_registration_organizations do |t|
      t.references :event_registration, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true, type: :integer

      t.timestamps
    end

    add_index :event_registration_organizations,
              [ :event_registration_id, :organization_id ],
              unique: true,
              name: "idx_event_reg_orgs_on_registration_and_org"
  end
end
