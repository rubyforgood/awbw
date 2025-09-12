class CreatePermissions < ActiveRecord::Migration
  def change
    create_table :permissions do |t|
      t.string :security_cat

      t.timestamps null: false
    end
  end
end
