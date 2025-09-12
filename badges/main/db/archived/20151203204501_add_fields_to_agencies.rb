class AddFieldsToAgencies < ActiveRecord::Migration
  def change
    add_reference :agencies, :windows_type, index: true
    add_foreign_key :agencies, :windows_types
    add_column :agencies, :district, :string
    add_column :agencies, :start_date, :date
    add_column :agencies, :end_date, :date
    add_column :agencies, :locality, :string
    add_column :agencies, :description, :text
    add_column :agencies, :notes, :text
    add_column :agencies, :filemaker_code, :string
    add_column :agencies, :inactive, :boolean, default: false
    add_column :agencies, :legacy_id, :integer
    add_column :agencies, :legacy, :boolean, default: false
  end
end
