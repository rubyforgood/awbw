class AddWorkshopToFormFieldResources < ActiveRecord::Migration[8.1]
  # A fan-out link points at a workshop or a resource, so resource_id loosens to
  # nullable. Integer FK matches the integer PK on workshops (MySQL requires it).
  def up
    unless column_exists?(:form_field_resources, :workshop_id)
      add_reference :form_field_resources, :workshop, type: :integer, foreign_key: true
    end
    change_column_null :form_field_resources, :resource_id, true
    unless index_exists?(:form_field_resources, [ :form_field_id, :workshop_id ])
      add_index :form_field_resources, [ :form_field_id, :workshop_id ], unique: true,
                name: "index_form_field_resources_on_field_and_workshop"
    end
  end

  def down
    execute "DELETE FROM form_field_resources WHERE resource_id IS NULL"
    remove_index :form_field_resources, name: "index_form_field_resources_on_field_and_workshop", if_exists: true
    remove_foreign_key :form_field_resources, :workshops, if_exists: true
    remove_column :form_field_resources, :workshop_id, if_exists: true
    change_column_null :form_field_resources, :resource_id, false
  end
end
