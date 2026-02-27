class CreatePersonFormFormFields < ActiveRecord::Migration[8.1]
  def change
    create_table :person_form_form_fields do |t|
      t.references :form_field, type: :integer, index: true
      t.references :person_form, type: :bigint, index: true
      t.text :text

      t.timestamps
    end

    add_foreign_key :person_form_form_fields, :form_fields
    add_foreign_key :person_form_form_fields, :person_forms
  end
end
