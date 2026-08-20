class CreateEventRegistrationChecklistCompletions < ActiveRecord::Migration[7.2]
  def up
    return if table_exists?(:event_registration_checklist_completions)

    create_table :event_registration_checklist_completions do |t|
      t.references :event_registration, null: false, foreign_key: true
      t.string :step, null: false
      t.references :completed_by, type: :integer, foreign_key: { to_table: :users }
      t.datetime :completed_at
      t.timestamps
    end

    add_index :event_registration_checklist_completions,
      [ :event_registration_id, :step ],
      unique: true,
      name: "index_checklist_completions_on_registration_and_step"
  end

  def down
    drop_table :event_registration_checklist_completions, if_exists: true
  end
end
