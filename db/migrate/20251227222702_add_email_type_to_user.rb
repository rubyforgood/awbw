class AddEmailTypeToUser < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :email_type, :string, default: "work", null: false
  end
end
