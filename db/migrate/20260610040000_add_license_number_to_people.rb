class AddLicenseNumberToPeople < ActiveRecord::Migration[8.1]
  def up
    add_column :people, :license_number, :string
    add_column :people, :license_type, :string
  end

  def down
    remove_column :people, :license_type, if_exists: true
    remove_column :people, :license_number, if_exists: true
  end
end
