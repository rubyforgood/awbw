class AddParentIdToFormFields < ActiveRecord::Migration
  def change
    add_column :form_fields, :parent_id, :integer, references: :form_fields
  end
end
