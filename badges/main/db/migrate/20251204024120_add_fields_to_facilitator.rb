class AddFieldsToFacilitator < ActiveRecord::Migration[8.1]
  def change
    add_column :facilitators, :phone_number_2, :string
    add_column :facilitators, :phone_number_3, :string
    add_column :facilitators, :best_time_to_call, :string

    add_column :facilitators, :notes, :text

    add_column :facilitators, :date_of_birth, :date
  end
end
