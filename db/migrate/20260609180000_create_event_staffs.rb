class CreateEventStaffs < ActiveRecord::Migration[8.1]
  def up
    create_table :event_staffs do |t|
      t.references :event, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.string :title
      t.boolean :expected_to_attend, null: false, default: false
      t.timestamps
    end

    add_index :event_staffs, [ :event_id, :person_id ], unique: true
  end

  def down
    drop_table :event_staffs, if_exists: true
  end
end
