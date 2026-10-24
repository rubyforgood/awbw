class DropLegacyResourceWorkshopLinks < ActiveRecord::Migration[8.1]
  def up
    drop_table :workshop_resources, if_exists: true
    remove_foreign_key :resources, :workshops, if_exists: true
    remove_index :resources, :workshop_id, if_exists: true
    remove_column :resources, :workshop_id, if_exists: true
  end

  def down
    add_column :resources, :workshop_id, :integer unless column_exists?(:resources, :workshop_id)
    add_index :resources, :workshop_id, if_not_exists: true
    add_foreign_key :resources, :workshops unless foreign_key_exists?(:resources, :workshops)

    create_table :workshop_resources, id: :integer, if_not_exists: true do |t|
      t.integer :workshop_id
      t.integer :resource_id
      t.integer :created_by_id
      t.integer :updated_by_id
      t.datetime :created_at, precision: nil, null: false
      t.datetime :updated_at, precision: nil, null: false
      t.index :workshop_id
      t.index :resource_id
      t.index :created_by_id
      t.index :updated_by_id
    end
    add_foreign_key :workshop_resources, :workshops unless foreign_key_exists?(:workshop_resources, :workshops)
    add_foreign_key :workshop_resources, :resources unless foreign_key_exists?(:workshop_resources, :resources)
    add_foreign_key :workshop_resources, :users, column: :created_by_id unless foreign_key_exists?(:workshop_resources, column: :created_by_id)
    add_foreign_key :workshop_resources, :users, column: :updated_by_id unless foreign_key_exists?(:workshop_resources, column: :updated_by_id)
  end
end
