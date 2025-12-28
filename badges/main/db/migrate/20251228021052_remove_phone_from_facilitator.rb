class RemovePhoneFromFacilitator < ActiveRecord::Migration[8.1]
  def change
    remove_column :facilitators, :phone_number, :string
    remove_column :facilitators, :phone_number_2, :string
    remove_column :facilitators, :phone_number_3, :string
    remove_column :facilitators, :phone_number_type, :string
  end
end
