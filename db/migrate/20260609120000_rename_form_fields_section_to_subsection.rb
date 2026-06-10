class RenameFormFieldsSectionToSubsection < ActiveRecord::Migration[8.1]
  def up
    rename_column :form_fields, :section, :subsection if column_exists?(:form_fields, :section)
    if index_exists?(:form_fields, :subsection, name: "index_form_fields_on_section")
      rename_index :form_fields, "index_form_fields_on_section", "index_form_fields_on_subsection"
    end
  end

  def down
    if index_exists?(:form_fields, :subsection, name: "index_form_fields_on_subsection")
      rename_index :form_fields, "index_form_fields_on_subsection", "index_form_fields_on_section"
    end
    rename_column :form_fields, :subsection, :section if column_exists?(:form_fields, :subsection)
  end
end
