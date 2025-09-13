class AddContactInfoToFacilitators < ActiveRecord::Migration[6.1]
  def change
    add_column :facilitators, :primary_email_address, :string, null: false 
    add_column :facilitators, :primary_email_address_type, :string, null: false
    add_column :facilitators, :street_address, :string, null: false
    add_column :facilitators, :city, :string, null: false
    add_column :facilitators, :state, :string, null: false
    add_column :facilitators, :zip, :string, null: false
    add_column :facilitators, :country, :string, null: false
    add_column :facilitators, :mailing_address_type, :string, null: false
    add_column :facilitators, :phone_number, :string, null: false
    add_column :facilitators, :phone_number_type, :string, null: false
  end
end
