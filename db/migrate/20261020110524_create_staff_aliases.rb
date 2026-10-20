class CreateStaffAliases < ActiveRecord::Migration[8.1]
  def up
    create_table :staff_aliases do |t|
      t.string :name, null: false
      # A shared login like "Staff" is recorded as naming no one, so user is optional.
      t.references :user, type: :integer, foreign_key: true, null: true
      t.boolean :ignored, default: false, null: false
      t.integer :created_by_id
      t.integer :updated_by_id
      t.timestamps
    end

    # The column collation is case-insensitive, so "allison" and "Allison" are one name.
    add_index :staff_aliases, :name, unique: true
  end

  def down
    drop_table :staff_aliases, if_exists: true
  end
end
