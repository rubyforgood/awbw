class CreateUserFormFormFields < ActiveRecord::Migration
  def change
    create_table :user_form_form_fields do |t|
      t.references :form_field, index: true
      t.references :user_form, index: true
      t.text :text

      t.timestamps null: false
    end
    add_foreign_key :user_form_form_fields, :form_fields
    add_foreign_key :user_form_form_fields, :user_forms
  end
end
