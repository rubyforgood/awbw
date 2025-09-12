class CreateAgencies < ActiveRecord::Migration
  def change
    create_table :agencies do |t|
    t.string :name
      t.references :location, index: true
      t.integer :leader_id

      t.timestamps null: false
    end
    add_foreign_key :agencies, :locations
  end
end
