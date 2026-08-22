class AddPurposeToForms < ActiveRecord::Migration[8.0]
  def change
    add_column :forms, :purpose, :string
  end
end
