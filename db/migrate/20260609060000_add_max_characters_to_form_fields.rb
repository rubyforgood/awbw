class AddMaxCharactersToFormFields < ActiveRecord::Migration[8.1]
  # Optional per-field maximum character count for free-form text answers.
  # NULL means no maximum is enforced.
  def up
    add_column :form_fields, :max_characters, :integer unless column_exists?(:form_fields, :max_characters)
  end

  def down
    remove_column :form_fields, :max_characters, if_exists: true
  end
end
