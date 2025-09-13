class CreateEvents < ActiveRecord::Migration[6.1]
  def change
    create_table :events do |t|
      t.string "title"
      t.text "description"
      t.datetime "start_date"
      t.datetime "end_date"
      t.datetime "registration_close_date"
      t.timestamps
    end
  end
end
