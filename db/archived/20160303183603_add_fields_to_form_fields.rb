class AddFieldsToFormFields < ActiveRecord::Migration
  def change
    add_column :form_fields, :status, :boolean, default: true
    add_column :form_fields, :instructional_hint, :string
    add_column :form_fields, :answer_type, :integer
    add_column :form_fields, :answer_datatype, :integer
    add_column :form_fields, :ordering, :integer
    add_column :form_fields, :is_required, :boolean, default: true

    remove_column :form_fields, :label
  end
end
