class AddFilemakerCodeToPeople < ActiveRecord::Migration[8.1]
  def up
    add_column :people, :filemaker_code, :string
  end

  def down
    remove_column :people, :filemaker_code, if_exists: true
  end
end
