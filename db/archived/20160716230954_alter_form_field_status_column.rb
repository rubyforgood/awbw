class AlterFormFieldStatusColumn < ActiveRecord::Migration[4.2]
  def up
    remove_column :form_fields, :status
    add_column :form_fields, :status, :integer, default: 1
  end
end
