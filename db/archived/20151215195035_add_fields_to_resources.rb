class AddFieldsToResources < ActiveRecord::Migration
  def change
    add_column :resources, :agency, :string
    add_column :resources, :legacy, :boolean
    add_reference :resources, :windows_type, index: true
    add_foreign_key :resources, :windows_types
    add_column :resources, :filemaker_code, :string
    add_column :resources, :ordering, :integer
    add_column :resources, :legacy_id, :integer
  end
end
