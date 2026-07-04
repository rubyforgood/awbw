class RemoveLicenseFieldsFromPeople < ActiveRecord::Migration[8.1]
  # A person's license now lives in professional_licenses. These denormalized
  # columns hold no data, so drop them.
  def up
    remove_column :people, :license_number, if_exists: true
    remove_column :people, :license_type, if_exists: true
  end

  def down
    add_column :people, :license_number, :string unless column_exists?(:people, :license_number)
    add_column :people, :license_type, :string unless column_exists?(:people, :license_type)
  end
end
