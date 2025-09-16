class CreateAddresses < ActiveRecord::Migration[6.1]
  def change
    create_table :addresses do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :street, null: false
      t.string :city, null: false
      t.string :state, null: false
      t.string :zip, null: false
      t.string :country
      t.string :locality
      t.string :county
      t.integer :la_city_council_district
      t.integer :la_supervisorial_district
      t.integer :la_service_planning_area

      t.timestamps
    end
  end
end
