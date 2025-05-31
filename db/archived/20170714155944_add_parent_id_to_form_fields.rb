class AddParentIdToFormFields < ActiveRecord::Migration[4.2]
  def change
    add_column :form_fields, :parent_id, :integer, references: :form_fields
  end
end
