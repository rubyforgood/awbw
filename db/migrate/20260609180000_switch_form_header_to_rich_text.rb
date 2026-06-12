class SwitchFormHeaderToRichText < ActiveRecord::Migration[8.1]
  # The optional form header moved from a plain-HTML `header` text column to an
  # ActionText rich-text field (`rhino_header`), edited with the rhino editor.
  def up
    if column_exists?(:forms, :header)
      execute(<<~SQL)
        INSERT INTO action_text_rich_texts (name, body, record_type, record_id, created_at, updated_at)
        SELECT 'rhino_header', header, 'Form', id, NOW(), NOW()
        FROM forms
        WHERE header IS NOT NULL AND header <> ''
      SQL
    end
    remove_column :forms, :header, :text, if_exists: true
  end

  def down
    add_column :forms, :header, :text unless column_exists?(:forms, :header)
    execute(<<~SQL)
      UPDATE forms
      SET header = (
        SELECT body FROM action_text_rich_texts
        WHERE record_type = 'Form' AND name = 'rhino_header' AND record_id = forms.id
        LIMIT 1
      )
    SQL
    execute("DELETE FROM action_text_rich_texts WHERE record_type = 'Form' AND name = 'rhino_header'")
  end
end
