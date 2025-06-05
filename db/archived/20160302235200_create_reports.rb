class CreateReports < ActiveRecord::Migration[4.2]
  def change
    create_table :reports do |t|
      t.string :type
      t.integer :owner_id
      t.string :owner_type


      t.timestamps null: false
    end
  end
end
