class AddFilemakerCodeAndDescriptionToPayments < ActiveRecord::Migration[8.1]
  def change
    add_column :payments, :filemaker_code, :string
    add_index :payments, :filemaker_code
    add_column :payments, :description, :text
  end
end
