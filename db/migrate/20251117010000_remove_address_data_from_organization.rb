class RemoveAddressDataFromOrganization < ActiveRecord::Migration[8.1]
  def change
    # Remove from projects
    remove_column :projects, :phone, :string
    remove_column :projects, :street_address, :string
    remove_column :projects, :city, :string
    remove_column :projects, :state, :string
    remove_column :projects, :zip_code, :string
    remove_column :projects, :country, :string
    remove_column :projects, :county, :string
    remove_column :projects, :district, :string
    remove_column :projects, :locality, :string
    remove_column :projects, :la_city_council_district, :string
    remove_column :projects, :la_service_planning_area, :string
    remove_column :projects, :la_supervisorial_district, :string

    # Add to addresses
    add_column :addresses, :address_type, :string
    add_column :addresses, :inactive, :boolean, null: false, default: false
    add_column :addresses, :district, :string
    add_column :addresses, :phone, :string
    rename_column :addresses, :street, :street_address
    rename_column :addresses, :zip, :zip_code
  end
end
