class AddFilemakerCodeToAddressesAndContactMethods < ActiveRecord::Migration[8.1]
  def up
    add_column :addresses, :filemaker_code, :string
    add_column :contact_methods, :filemaker_code, :string
  end

  def down
    remove_column :contact_methods, :filemaker_code, if_exists: true
    remove_column :addresses, :filemaker_code, if_exists: true
  end
end
