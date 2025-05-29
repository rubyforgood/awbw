class CreateAgeRanges < ActiveRecord::Migration[4.2]
  def change
    create_table :age_ranges do |t|
      t.string :name

      t.timestamps null: false
    end
  end
end
