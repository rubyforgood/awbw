class UpdateProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :street_address, :string
    add_column :projects, :city, :string
    add_column :projects, :state, :string
    add_column :projects, :zip_code, :string
    add_column :projects, :county, :string
    add_column :projects, :country, :string
    add_column :projects, :website_url, :string
    add_column :projects, :agency_type, :string
    add_column :projects, :phone, :string
    add_column :projects, :mission_vision_values, :string
    add_column :projects, :internal_id, :string
    add_column :projects, :la_city_council_district, :integer
    add_column :projects, :la_supervisorial_district, :integer
    add_column :projects, :la_service_planning_area, :integer
  end
end
