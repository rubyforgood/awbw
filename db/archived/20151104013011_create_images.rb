
class CreateImages < ActiveRecord::Migration[4.2]
  def change
    create_table :images do |t|
      t.integer :owner_id, index: true
      t.string :owner_type

      t.timestamps null: false
    end
  end
end
