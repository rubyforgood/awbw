class AddRoleToForms < ActiveRecord::Migration[8.1]
  def change
    add_column :forms, :role, :string
    remove_column :forms, :scholarship_application, :boolean
  end
end
