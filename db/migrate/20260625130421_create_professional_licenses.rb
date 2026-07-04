class CreateProfessionalLicenses < ActiveRecord::Migration[8.1]
  def up
    create_table :professional_licenses do |t|
      t.references :person, null: false, foreign_key: true
      t.string :number
      t.string :kind
      t.string :issuing_state
      t.date :expires_on
      t.bigint :created_by_id
      t.bigint :updated_by_id
      t.timestamps
    end
    add_index :professional_licenses, :created_by_id
    add_index :professional_licenses, :updated_by_id
    # Enforces one license per (person, number). MySQL treats NULLs as distinct,
    # so this guards numbered licenses; the model keeps the single placeholder
    # (number-less) license per person via find_or_create.
    add_index :professional_licenses, [ :person_id, :number ], unique: true,
      name: "index_professional_licenses_on_person_and_number"
  end

  def down
    drop_table :professional_licenses, if_exists: true
  end
end
