class CreateWindowsTypes < ActiveRecord::Migration
  def change
    create_table :windows_types do |t|
      t.string :name

      t.timestamps null: false
    end
  end
end
