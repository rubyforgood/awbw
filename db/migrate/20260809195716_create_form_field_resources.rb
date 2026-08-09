class CreateFormFieldResources < ActiveRecord::Migration[8.1]
  # Direct FormField -> Resource link. A form field with associated resources is a
  # "per-resource" question that renders one input per resource (the post-event survey
  # clarity question, one input per training topic/handout). Integer FKs match the
  # integer PKs on form_fields and resources.
  def up
    return if table_exists?(:form_field_resources)
    create_table :form_field_resources do |t|
      t.references :form_field, type: :integer, null: false, foreign_key: true
      t.references :resource, type: :integer, null: false, foreign_key: true
      t.integer :position
      t.timestamps
    end
    add_index :form_field_resources, [ :form_field_id, :resource_id ], unique: true,
              name: "index_form_field_resources_on_field_and_resource"
  end

  def down
    drop_table :form_field_resources, if_exists: true
  end
end
