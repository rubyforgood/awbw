class ChangeFormFieldsInstructionalHintToText < ActiveRecord::Migration[8.1]
  def up
    change_column :form_fields, :instructional_hint, :text
  end

  def down
    change_column :form_fields, :instructional_hint, :string, limit: 255
  end
end
