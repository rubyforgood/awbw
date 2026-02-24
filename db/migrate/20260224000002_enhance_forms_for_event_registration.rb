class EnhanceFormsForEventRegistration < ActiveRecord::Migration[8.0]
  def change
    add_column :form_fields, :field_key, :string
    add_column :form_fields, :field_group, :string

    add_index :form_fields, :field_key
    add_index :form_fields, :field_group
  end
end
