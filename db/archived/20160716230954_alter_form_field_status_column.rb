class AlterFormFieldStatusColumn < ActiveRecord::Migration
  def up
    remove_column :form_fields, :status
    add_column :form_fields, :status, :integer, default: 1
  end
end
