class AddMaleAndFemaleToResources < ActiveRecord::Migration[4.2]
  def change
    add_column :resources, :male, :boolean, default: false
    add_column :resources, :female, :boolean, default: false
  end
end
