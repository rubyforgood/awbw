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

    # Rename user_id to created_by_id
    rename_column :workshop_logs, :user_id, :created_by_id
    remove_index :workshop_logs, :created_by_id, if_exists: true

    # Add new columns
    add_column :workshop_logs, :windows_type_id, :integer
    add_column :workshop_logs, :external_workshop_title, :string
    add_column :workshop_logs, :workshop_name, :string
    add_column :workshop_logs, :has_attachment, :boolean, default: false, null: false
    add_column :workshop_logs, :other_description, :string
    add_column :workshop_logs, :children_first_time, :integer, default: 0
    add_column :workshop_logs, :children_ongoing, :integer, default: 0
    add_column :workshop_logs, :teens_first_time, :integer, default: 0
    add_column :workshop_logs, :teens_ongoing, :integer, default: 0
    add_column :workshop_logs, :adults_first_time, :integer, default: 0
    add_column :workshop_logs, :adults_ongoing, :integer, default: 0
    add_column :workshop_logs, :form_file_file_name, :string
    add_column :workshop_logs, :form_file_content_type, :string
    add_column :workshop_logs, :form_file_file_size, :integer
    add_column :workshop_logs, :form_file_updated_at, :datetime, precision: nil

    # Make existing columns NOT NULL where needed (after data migration will populate them)
    # organization_id is already present; created_by_id was renamed from user_id
    # We'll enforce NOT NULL after the data migration populates the table

    # Add indexes
    add_index :workshop_logs, :created_by_id
    add_index :workshop_logs, :date
    add_index :workshop_logs, [ :organization_id, :date ], name: "index_workshop_logs_on_org_and_date"
    add_index :workshop_logs, :windows_type_id

    # Add foreign keys (workshops FK already exists from legacy table)
    add_foreign_key :workshop_logs, :users, column: :created_by_id
    add_foreign_key :workshop_logs, :windows_types
  end

  def down
    # Remove new foreign keys (workshops FK stays — it's the same before and after)
    remove_foreign_key :workshop_logs, column: :created_by_id
    remove_foreign_key :workshop_logs, :windows_types

    # Remove new indexes
    remove_index :workshop_logs, :created_by_id, if_exists: true
    remove_index :workshop_logs, :date, if_exists: true
    remove_index :workshop_logs, name: "index_workshop_logs_on_org_and_date", if_exists: true
    remove_index :workshop_logs, :windows_type_id, if_exists: true

    # Remove new columns
    remove_column :workshop_logs, :windows_type_id
    remove_column :workshop_logs, :external_workshop_title
    remove_column :workshop_logs, :workshop_name
    remove_column :workshop_logs, :has_attachment
    remove_column :workshop_logs, :other_description
    remove_column :workshop_logs, :children_first_time
    remove_column :workshop_logs, :children_ongoing
    remove_column :workshop_logs, :teens_first_time
    remove_column :workshop_logs, :teens_ongoing
    remove_column :workshop_logs, :adults_first_time
    remove_column :workshop_logs, :adults_ongoing
    remove_column :workshop_logs, :form_file_file_name
    remove_column :workshop_logs, :form_file_content_type
    remove_column :workshop_logs, :form_file_file_size
    remove_column :workshop_logs, :form_file_updated_at

    # Rename back
    rename_column :workshop_logs, :created_by_id, :user_id
    add_index :workshop_logs, :user_id

    # Restore legacy columns
    add_column :workshop_logs, :challenges, :text, size: :long
    add_column :workshop_logs, :comments, :text, size: :long
    add_column :workshop_logs, :differences, :text, size: :long
    add_column :workshop_logs, :is_embodied_art_workshop, :boolean, default: false
    add_column :workshop_logs, :lead_similar, :boolean
    add_column :workshop_logs, :num_participants_first_time, :integer, default: 0
    add_column :workshop_logs, :num_participants_on_going, :integer, default: 0
    add_column :workshop_logs, :questions, :text, size: :long
    add_column :workshop_logs, :reaction, :text, size: :long
    add_column :workshop_logs, :similarities, :text, size: :long
    add_column :workshop_logs, :successes, :text, size: :long
    add_column :workshop_logs, :suggestions, :text, size: :long

    # Restore legacy foreign keys
    add_foreign_key :workshop_logs, :users
  end
end
