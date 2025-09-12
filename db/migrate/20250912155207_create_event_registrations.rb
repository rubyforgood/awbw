class CreateEventRegistrations < ActiveRecord::Migration[6.1]
  def change
    create_table :event_registrations do |t|
      t.string :first_name
      t.string :last_name
      t.string :email
      t.references :event, foreign_key: true

      t.timestamps
    end
  end
end
