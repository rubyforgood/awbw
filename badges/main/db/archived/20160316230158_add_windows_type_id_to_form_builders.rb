class AddWindowsTypeIdToFormBuilders < ActiveRecord::Migration
  def change
    add_reference :form_builders, :windows_type, index: true
    add_foreign_key :form_builders, :windows_types
  end
end
