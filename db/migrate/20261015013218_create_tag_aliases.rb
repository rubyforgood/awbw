class CreateTagAliases < ActiveRecord::Migration[8.1]
  def up
    create_table :tag_aliases do |t|
      t.string :name, null: false
      # A term can be recorded as deliberately naming nothing, so aliasable is optional.
      t.references :aliasable, polymorphic: true, null: true, index: false
      t.boolean :ignored, default: false, null: false
      t.string :source, null: false
      t.integer :created_by_id
      t.integer :updated_by_id
      t.timestamps
    end

    # The column collation is case-insensitive, so one spelling can't be recorded twice
    # for the same tag. A term naming two tags is two rows.
    add_index :tag_aliases, %i[name aliasable_type aliasable_id], unique: true,
              name: "index_tag_aliases_on_name_and_aliasable"
    add_index :tag_aliases, %i[aliasable_type aliasable_id], name: "index_tag_aliases_on_aliasable"
  end

  def down
    drop_table :tag_aliases, if_exists: true
  end
end
