class CreateFacilitators < ActiveRecord::Migration[6.1]
  def change
    create_table :facilitators do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false

      t.timestamps
    end
  end
end
