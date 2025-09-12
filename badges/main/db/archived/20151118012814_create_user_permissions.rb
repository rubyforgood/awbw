class CreateUserPermissions < ActiveRecord::Migration
  def change
    create_table :user_permissions do |t|
      t.references :user, index: true
      t.references :permission, index: true

      t.timestamps null: false
    end
    add_foreign_key :user_permissions, :users
    add_foreign_key :user_permissions, :permissions
  end
end
