class AddLicenseNumberToPeople < ActiveRecord::Migration[8.1]
  def up
    add_column :people, :license_number, :string
  end

  def down
    remove_column :people, :license_number, if_exists: true
  end
end
