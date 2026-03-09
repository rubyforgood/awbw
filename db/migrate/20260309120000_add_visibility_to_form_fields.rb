class AddVisibilityToFormFields < ActiveRecord::Migration[8.0]
  def change
    add_column :form_fields, :visibility, :integer, default: 0, null: false
  end
end
