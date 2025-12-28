class RemoveAddressFieldsFromFacilitator < ActiveRecord::Migration[8.1]
  def change
    remove_column :facilitators, :mailing_address_type, :string
    remove_column :facilitators, :street_address, :string
    remove_column :facilitators, :city, :string
    remove_column :facilitators, :state, :string
    remove_column :facilitators, :zip, :string
    remove_column :facilitators, :country, :string
  end
end
