class AddMinWordsToFormFields < ActiveRecord::Migration[8.1]
  # Optional per-field minimum word count for free-form text answers.
  # NULL means no minimum is enforced.
  def up
    add_column :form_fields, :min_words, :integer unless column_exists?(:form_fields, :min_words)
  end

  def down
    remove_column :form_fields, :min_words, if_exists: true
  end
end
