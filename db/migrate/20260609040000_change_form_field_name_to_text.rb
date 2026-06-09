class ChangeFormFieldNameToText < ActiveRecord::Migration[8.1]
  # Question names can be long, multi-sentence prompts that overflowed the
  # varchar(255) limit and raised ActiveRecord::ValueTooLong. Widen to text.
  def up
    change_column :form_fields, :name, :text
  end

  def down
    change_column :form_fields, :name, :string
  end
end
