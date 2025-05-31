class CreateForms < ActiveRecord::Migration[4.2]
  def change
    create_table :forms do |t|
      t.string :owner_type
      t.integer :owner_id

      t.timestamps null: false
    end
  end
end
