class AddFieldsToUsers < ActiveRecord::Migration
  def change
    add_column :users, :address, :string
    add_column :users, :city, :string
    add_column :users, :state, :string
    add_column :users, :zip, :string
    add_column :users, :birthday, :date
    add_column :users, :subscribecode, :string
    add_column :users, :comment, :text
    add_column :users, :notes, :text
    add_column :users, :legacy, :boolean, default: false
    remove_column :users, :activation_status
    add_column :users, :inactive, :boolean, default: true
    add_column :users, :confirmed, :boolean, default: false
    add_column :users, :legacy_id, :integer
  end
end
