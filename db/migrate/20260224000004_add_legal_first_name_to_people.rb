class AddLegalFirstNameToPeople < ActiveRecord::Migration[8.0]
  def change
    add_column :people, :legal_first_name, :string
  end
end
