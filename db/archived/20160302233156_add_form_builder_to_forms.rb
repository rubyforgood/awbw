class AddFormBuilderToForms < ActiveRecord::Migration[4.2]
  def change
    add_reference :forms, :form_builder, index: true
    add_foreign_key :forms, :form_builders
  end
end
