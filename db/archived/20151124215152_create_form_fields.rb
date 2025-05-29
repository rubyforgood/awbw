class CreateFormFields < ActiveRecord::Migration[4.2]
  def change
    create_table :form_fields do |t|
      t.string :label
      t.references :form, index: true

      t.timestamps null: false
    end
    add_foreign_key :form_fields, :forms
  end
end
