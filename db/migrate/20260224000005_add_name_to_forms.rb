class AddNameToForms < ActiveRecord::Migration[8.0]
  def change
    add_column :forms, :name, :string unless column_exists?(:forms, :name)
  end
end
