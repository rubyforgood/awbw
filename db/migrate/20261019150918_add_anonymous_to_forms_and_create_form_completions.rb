class AddAnonymousToFormsAndCreateFormCompletions < ActiveRecord::Migration[8.1]
  def up
    add_column :forms, :anonymous, :boolean, default: false, null: false unless column_exists?(:forms, :anonymous)

    # No timestamps or submission id: a time of day would let staff match a
    # completion to the anonymous submission it came from.
    create_table :form_completions, if_not_exists: true do |t|
      t.bigint :person_id, null: false
      t.integer :form_id, null: false
      t.bigint :event_id, null: false
      t.date :completed_on, null: false
    end
    add_index :form_completions, %i[person_id form_id event_id], unique: true, if_not_exists: true
    add_index :form_completions, :form_id, if_not_exists: true
    add_index :form_completions, :event_id, if_not_exists: true
    add_foreign_key :form_completions, :people, if_not_exists: true
    add_foreign_key :form_completions, :forms, if_not_exists: true
    add_foreign_key :form_completions, :events, if_not_exists: true
  end

  def down
    drop_table :form_completions, if_exists: true
    remove_column :forms, :anonymous if column_exists?(:forms, :anonymous)
  end
end
