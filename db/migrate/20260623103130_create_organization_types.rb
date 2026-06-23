class CreateOrganizationTypes < ActiveRecord::Migration[8.0]
  def up
    return if table_exists?(:organization_types)

    create_table :organization_types do |t|
      t.string :name
      t.text :description
      t.boolean :published, default: false, null: false

      t.timestamps
    end
    add_index :organization_types, :published
  end

  def down
    drop_table :organization_types, if_exists: true
  end
end
