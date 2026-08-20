class RenameFormFieldHintTextToSubtitleAndAddHintText < ActiveRecord::Migration[8.0]
  # The column historically called `hint_text` has always rendered as a subtitle
  # under the field label, so it is renamed to `subtitle`. A fresh `hint_text`
  # column is then added for SimpleForm-style hint text shown below the input.
  def up
    rename_column :form_fields, :hint_text, :subtitle unless column_exists?(:form_fields, :subtitle)
    add_column :form_fields, :hint_text, :text unless column_exists?(:form_fields, :hint_text)
  end

  def down
    remove_column :form_fields, :hint_text, :text, if_exists: true
    rename_column :form_fields, :subtitle, :hint_text if column_exists?(:form_fields, :subtitle)
  end
end
