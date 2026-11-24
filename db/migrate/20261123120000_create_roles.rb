class CreateRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :roles do |t|
      t.references :user, type: :integer, null: false, foreign_key: true
      t.string :role, null: false
      t.references :roleable, polymorphic: true
      t.references :created_by, type: :integer, foreign_key: { to_table: :users }
      t.references :updated_by, type: :integer, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :roles, [ :user_id, :role, :roleable_type, :roleable_id ],
              unique: true,
              name: "index_roles_on_user_role_and_roleable"
  end
end
