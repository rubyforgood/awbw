# frozen_string_literal: true

class CreateTimelineTables < ActiveRecord::Migration[8.1]
  def change
    create_table :timeline_events do |t|
      t.belongs_to :subject, polymorphic: true, null: false
      t.belongs_to :actor, polymorphic: true, null: true
      t.string :action, null: false
      t.json :snapshot, null: false
      t.timestamps
    end

    add_index :timeline_events, [ :subject_type, :subject_id, :created_at ]
    add_index :timeline_events, :action
    add_index :timeline_events, [ :actor_type, :actor_id, :created_at ]

    create_table :timeline_entries do |t|
      t.belongs_to :owner, polymorphic: true, null: false
      t.belongs_to :timeline_event, null: false, foreign_key: true
      t.timestamps
    end

    add_index :timeline_entries, [ :owner_type, :owner_id, :created_at ]
    add_index :timeline_entries, [ :timeline_event_id, :owner_type, :owner_id ], unique: true, name: "index_timeline_entries_on_event_and_owner_unique"
  end
end
