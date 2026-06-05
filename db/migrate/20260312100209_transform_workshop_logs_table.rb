class TransformWorkshopLogsTable < ActiveRecord::Migration[8.1]
  def up
    # Remove legacy foreign keys (workshops FK stays — it's the same before and after)
    remove_foreign_key :workshop_logs, :users

    # Remove legacy columns
    remove_column :workshop_logs, :challenges
    remove_column :workshop_logs, :comments
    remove_column :workshop_logs, :differences
    remove_column :workshop_logs, :is_embodied_art_workshop
    remove_column :workshop_logs, :lead_similar
    remove_column :workshop_logs, :num_participants_first_time
    remove_column :workshop_logs, :num_participants_on_going
    remove_column :workshop_logs, :questions
    remove_column :workshop_logs, :reaction
    remove_column :workshop_logs, :similarities
    remove_column :workshop_logs, :successes
    remove_column :workshop_logs, :suggestions

    # Rename columns
    rename_column :workshop_logs, :user_id, :created_by_id
    remove_index :workshop_logs, :created_by_id, if_exists: true
    rename_column :workshop_logs, :date, :workshop_held_on

    # Add new columns
    add_column :workshop_logs, :windows_type_id, :integer
    add_column :workshop_logs, :external_workshop_title, :string
    add_column :workshop_logs, :children_first_time, :integer, default: 0
    add_column :workshop_logs, :children_ongoing, :integer, default: 0
    add_column :workshop_logs, :teens_first_time, :integer, default: 0
    add_column :workshop_logs, :teens_ongoing, :integer, default: 0
    add_column :workshop_logs, :adults_first_time, :integer, default: 0
    add_column :workshop_logs, :adults_ongoing, :integer, default: 0
    add_column :workshop_logs, :total_children, :integer, default: 0
    add_column :workshop_logs, :total_teens, :integer, default: 0
    add_column :workshop_logs, :total_adults, :integer, default: 0

    # Add indexes
    add_index :workshop_logs, :created_by_id
    add_index :workshop_logs, :workshop_held_on
    add_index :workshop_logs, [ :organization_id, :workshop_held_on ], name: "index_workshop_logs_on_org_and_workshop_held_on"
    add_index :workshop_logs, :windows_type_id

    # Add foreign keys (workshops FK already exists from legacy table)
    add_foreign_key :workshop_logs, :users, column: :created_by_id
    add_foreign_key :workshop_logs, :windows_types
  end

  def down
    # Remove new foreign keys (workshops FK stays — it's the same before and after)
    remove_foreign_key :workshop_logs, column: :created_by_id, if_exists: true
    remove_foreign_key :workshop_logs, :windows_types, if_exists: true

    # Remove new indexes
    remove_index :workshop_logs, :created_by_id, if_exists: true
    remove_index :workshop_logs, :workshop_held_on, if_exists: true
    remove_index :workshop_logs, name: "index_workshop_logs_on_org_and_workshop_held_on", if_exists: true
    remove_index :workshop_logs, :windows_type_id, if_exists: true

    # Remove new columns (guarded for partial rollback recovery)
    %i[windows_type_id external_workshop_title
       children_first_time children_ongoing teens_first_time teens_ongoing
       adults_first_time adults_ongoing total_children total_teens total_adults].each do |col|
      remove_column :workshop_logs, col if column_exists?(:workshop_logs, col)
    end

    # Rename back
    if column_exists?(:workshop_logs, :workshop_held_on)
      rename_column :workshop_logs, :workshop_held_on, :date
    end
    if column_exists?(:workshop_logs, :created_by_id)
      rename_column :workshop_logs, :created_by_id, :user_id
    end
    add_index :workshop_logs, :user_id unless index_exists?(:workshop_logs, :user_id)

    # Restore legacy columns
    add_column :workshop_logs, :challenges, :text, size: :long unless column_exists?(:workshop_logs, :challenges)
    add_column :workshop_logs, :comments, :text, size: :long unless column_exists?(:workshop_logs, :comments)
    add_column :workshop_logs, :differences, :text, size: :long unless column_exists?(:workshop_logs, :differences)
    add_column :workshop_logs, :is_embodied_art_workshop, :boolean, default: false unless column_exists?(:workshop_logs, :is_embodied_art_workshop)
    add_column :workshop_logs, :lead_similar, :boolean unless column_exists?(:workshop_logs, :lead_similar)
    add_column :workshop_logs, :num_participants_first_time, :integer, default: 0 unless column_exists?(:workshop_logs, :num_participants_first_time)
    add_column :workshop_logs, :num_participants_on_going, :integer, default: 0 unless column_exists?(:workshop_logs, :num_participants_on_going)
    add_column :workshop_logs, :questions, :text, size: :long unless column_exists?(:workshop_logs, :questions)
    add_column :workshop_logs, :reaction, :text, size: :long unless column_exists?(:workshop_logs, :reaction)
    add_column :workshop_logs, :similarities, :text, size: :long unless column_exists?(:workshop_logs, :similarities)
    add_column :workshop_logs, :successes, :text, size: :long unless column_exists?(:workshop_logs, :successes)
    add_column :workshop_logs, :suggestions, :text, size: :long unless column_exists?(:workshop_logs, :suggestions)

    # Restore legacy foreign keys
    add_foreign_key :workshop_logs, :users unless foreign_key_exists?(:workshop_logs, :users)
  end
end
