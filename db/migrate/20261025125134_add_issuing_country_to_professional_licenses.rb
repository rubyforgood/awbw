class AddIssuingCountryToProfessionalLicenses < ActiveRecord::Migration[8.1]
  def up
    add_column :professional_licenses, :issuing_country, :string unless column_exists?(:professional_licenses, :issuing_country)
  end

  def down
    remove_column :professional_licenses, :issuing_country if column_exists?(:professional_licenses, :issuing_country)
  end
end
