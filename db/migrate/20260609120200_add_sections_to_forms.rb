class AddSectionsToForms < ActiveRecord::Migration[8.1]
  # Reintroduces `forms.sections`, now meaning the top-level grouping of
  # subsections (the new tier above subsections). Stored as JSON:
  # [{ "label" => "About you", "subsections" => ["person_identifier", ...] }, ...]
  def up
    add_column :forms, :sections, :json unless column_exists?(:forms, :sections)
  end

  def down
    remove_column :forms, :sections if column_exists?(:forms, :sections)
  end
end
