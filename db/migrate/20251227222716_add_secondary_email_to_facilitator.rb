class AddSecondaryEmailToFacilitator < ActiveRecord::Migration[8.1]
  def change
    rename_column :facilitators, :primary_email_address, :email
    rename_column :facilitators, :primary_email_address_type, :email_type

    add_column :facilitators, :email_2, :string
    add_column :facilitators, :email_2_type, :string, default: "personal", null: false
  end
end
