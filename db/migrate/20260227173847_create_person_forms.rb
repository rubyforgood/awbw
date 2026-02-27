class CreatePersonForms < ActiveRecord::Migration[8.1]
  def change
    create_table :person_forms do |t|
      t.references :person, type: :bigint, index: true
      t.references :form, type: :integer, index: true

      t.timestamps
    end

    add_foreign_key :person_forms, :people
    add_foreign_key :person_forms, :forms
  end
end
