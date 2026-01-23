class RenameOrderingToPositionOnFormFields < ActiveRecord::Migration[8.1]
  def change
    rename_column :form_fields, :ordering, :position
  end
end
