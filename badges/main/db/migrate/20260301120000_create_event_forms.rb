class CreateEventForms < ActiveRecord::Migration[8.1]
  def change
    create_table :event_forms do |t|
      t.references :event, null: false, foreign_key: true
      t.references :form, null: false, foreign_key: true, type: :integer
      t.string :role, null: false

      t.timestamps
    end

    add_index :event_forms, [ :event_id, :form_id, :role ], unique: true
  end
end
