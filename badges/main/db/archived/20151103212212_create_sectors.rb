class CreateSectors < ActiveRecord::Migration
  def change
    create_table :sectors do |t|
      t.string :name

      t.timestamps null: false
    end
  end
end
