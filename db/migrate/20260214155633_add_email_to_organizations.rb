class AddEmailToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :email, :string
  end
end
