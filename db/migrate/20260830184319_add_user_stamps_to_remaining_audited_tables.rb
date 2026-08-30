class AddUserStampsToRemainingAuditedTables < ActiveRecord::Migration[8.1]
  # Tables whose edit pages render the shared audit footer but had no stamp columns,
  # so the footer read attribution from Ahoy. With these columns UserStampable records
  # who created/last-edited each row, and the footer reads the model instead of Ahoy.
  # Stamped forward-only (no backfill); pre-existing rows show "—" until next edited.
  TABLES = %i[
    payments forms sectors faqs categories category_types
    memberships membership_invoices organization_statuses video_recordings windows_types
    organizations affiliations scholarships event_registrations features
  ].freeze

  def up
    TABLES.each do |table|
      add_column table, :created_by_id, :integer, null: true unless column_exists?(table, :created_by_id)
      add_column table, :updated_by_id, :integer, null: true unless column_exists?(table, :updated_by_id)
      add_index table, :created_by_id unless index_exists?(table, :created_by_id)
      add_index table, :updated_by_id unless index_exists?(table, :updated_by_id)
      add_foreign_key table, :users, column: :created_by_id unless foreign_key_exists?(table, :users, column: :created_by_id)
      add_foreign_key table, :users, column: :updated_by_id unless foreign_key_exists?(table, :users, column: :updated_by_id)
    end
  end

  def down
    TABLES.each do |table|
      remove_foreign_key table, :users, column: :created_by_id if foreign_key_exists?(table, :users, column: :created_by_id)
      remove_foreign_key table, :users, column: :updated_by_id if foreign_key_exists?(table, :users, column: :updated_by_id)
      remove_index table, :created_by_id if index_exists?(table, :created_by_id)
      remove_index table, :updated_by_id if index_exists?(table, :updated_by_id)
      remove_column table, :created_by_id if column_exists?(table, :created_by_id)
      remove_column table, :updated_by_id if column_exists?(table, :updated_by_id)
    end
  end
end
