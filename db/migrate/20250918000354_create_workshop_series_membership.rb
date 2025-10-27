class CreateWorkshopSeriesMembership < ActiveRecord::Migration[8.1]
  def up
    create_table :workshop_series_memberships do |t|
      t.integer :workshop_parent_id, null: false
      t.integer :workshop_child_id, null: false
      t.string :series_description
      t.string :series_description_spanish
      t.integer :series_order, default: 1, null: false

      t.timestamps
    end

    add_foreign_key :workshop_series_memberships, :workshops, column: :workshop_parent_id
    add_foreign_key :workshop_series_memberships, :workshops, column: :workshop_child_id

    add_index :workshop_series_memberships, [:workshop_parent_id, :workshop_child_id], unique: true,
              name: "index_workshop_series_memberships_on_parent_and_child"
  end

  def down
    remove_foreign_key :workshop_series_memberships, column: :workshop_parent_id
    remove_foreign_key :workshop_series_memberships, column: :workshop_child_id
    remove_index :workshop_series_memberships, name: "index_workshop_series_memberships_on_parent_and_child"
    drop_table :workshop_series_memberships
  end
end
