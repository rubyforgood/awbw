class CreateMetadata < ActiveRecord::Migration
  def change
    create_table :metadata do |t|
      t.string :name
      t.string :legacy_id
      t.timestamps null: false
    end
  end
end
