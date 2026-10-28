class AddResponsesEditableToForms < ActiveRecord::Migration[8.1]
  def up
    add_column :forms, :responses_editable, :boolean, default: true, null: false unless column_exists?(:forms, :responses_editable)
  end

  def down
    remove_column :forms, :responses_editable if column_exists?(:forms, :responses_editable)
  end
end
