class CreateStaffTags < ActiveRecord::Migration[7.2]
  def change
    create_table :staff_tags do |t|
      t.string :name, null: false
      t.text :description
      t.datetime :archived_at
      # created_by/updated_by point at users, whose PK is an int, so we keep plain
      # reference columns (no DB FK) to match the app's audit-column convention.
      t.bigint :created_by_id
      t.bigint :updated_by_id
      t.timestamps
    end
    add_index :staff_tags, :name, unique: true
    add_index :staff_tags, :archived_at
    add_index :staff_tags, :created_by_id
    add_index :staff_tags, :updated_by_id

    create_table :staff_taggings do |t|
      t.references :staff_tag, null: false, foreign_key: true
      t.references :staff_taggable, polymorphic: true, null: false
      t.bigint :created_by_id
      t.timestamps
    end
    add_index :staff_taggings, :created_by_id
    add_index :staff_taggings,
              [ :staff_tag_id, :staff_taggable_type, :staff_taggable_id ],
              unique: true,
              name: "index_staff_taggings_uniqueness"
  end
end
